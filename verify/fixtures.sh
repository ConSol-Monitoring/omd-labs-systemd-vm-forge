#!/usr/bin/env bash
# verify/fixtures.sh - fixture builders for the 001-systemd-vm-startup
# verification suite (T003). Each builder is idempotent: safe to re-run.
#
# Sourced by scenario scripts; requires common.sh already sourced and
# `set -euo pipefail` in force.
#
# FIXDIR default: /tmp/omd-verify (all fixture dirs live here; teardown
# removes them)
#
# OWNERSHIP MODEL (EMPIRICAL 2026-11-10): the suite runs as the host USER
# (uid 1000). Numeric chown to other uids and rm of site-owned leftovers
# are not possible from the host (no root; rootless podman's "root"
# container maps into the user's subuid range - STABLE across all
# containers of the user). All ownership changes and teardowns therefore
# go through the root probe container (v_vol_probe, common.sh). The
# fixture numbers are the CONTAINER-VIEW numbers - exactly what the
# entry's D6 logic reads, because every container (probes + entry)
# mounts the volume into the same user-namespace mapping.
set -euo pipefail
FIXDIR="${FIXDIR:-/tmp/omd-verify}"

# container-view numeric identity used by the fixtures (D6 row 1 uses 1000
# in the image; fixtures use a distinct free identity 1234/1234 so the
# registration restore path (recorded identity honored) is exercised)
FIX_UID=${FIX_UID:-1234}
FIX_GID=${FIX_GID:-1234}

# the target image's REAL `omd` group gid - probed from the image (container
# root view), NEVER hardcoded. EMPIRICAL 2026-11-10: rocky = 996, debian =
# 106. A hardcoded 0 made the g1 ambiguity guard (entry:345) un-fireable and
# masked the real behavior (debate 59 F2). The home-dir group invariant is
# "home group = omd group, primary gid = site name" (a DIFFERENT gid than the
# site's primary), so the fixture's top dir is chowned to the real omd gid.
fx_omd_gid() { # fx_omd_gid -> the image's omd group gid
    $RUNTIME run --rm --entrypoint sh "$IMAGE" -c 'getent group omd | cut -d: -f3'
}

# fx_image_id [image] -> the container-image ID (default: $IMAGE). debate 61
# N2: the golden cache key must be tied to the image, not just the .golden-ok
# flag - a rebuilt tag with the same name must invalidate the cached tree.
fx_image_id() {
    $RUNTIME image inspect -f '{{.Id}}' "${1:-$IMAGE}" 2>/dev/null | head -n1
}

# wipe a dir's content ROOT-side (the host user cannot remove site-owned
# leftovers) and ensure the (host-owned) dir exists - the top dir itself
# stays host-owned, so a later plain rmdir works
# NOTE (EMPIRICAL 2026-11-10): the entry chowns the volume TOP dir to the
# site user - a stale top dir from a previous run is host-undeletable (EACCES),
# and `cp -a`/`touch` into it fail. Remove the dir ITSELF root-side, then
# recreate it host-owned.
fx_root_reset() { # fx_root_reset <dir>
    local d=$1
    [ -d "$d" ] && v_vol_probe "$(dirname "$d")" "rm -rf /w/$(basename "$d")" >/dev/null || true
    mkdir -p "$d"
}

# generic empty dir
fx_empty_dir() { # fx_empty_dir <name>
    local d="$FIXDIR/$1"
    fx_root_reset "$d"
    echo "$d"
}

# not-writable dir (S7a)
fx_not_writable_dir() { # fx_not_writable_dir <name>
    local d="$FIXDIR/$1"
    fx_root_reset "$d"
    chmod 755 "$d"
    echo x >"$d/f"
    chmod 555 "$d"
    echo "$d"
}

# ssh keypair on the host (S3b); prints the .pub path
fx_ssh_keypair() {
    [ -f /tmp/omd-test-key ] || ssh-keygen -t ed25519 -f /tmp/omd-test-key -N '' -q
    echo /tmp/omd-test-key.pub
}

# malformed key file (S3b-b); prints the path
fx_bad_key() {
    printf 'this is not a key\n' >"$FIXDIR/badkey"
    echo "$FIXDIR/badkey"
}

# sentinel file (persistence scenarios); prints the path
fx_sentinel() {
    echo "sentinel-$(date +%s)" >"$FIXDIR/sentinel.txt"
    echo "$FIXDIR/sentinel.txt"
}

# settings-file fixture with # comments (S5); prints the path
fx_settings_file() {
    printf '# gearman enabled; loopback bind from the file\nMOD_GEARMAN=on\nGEARMAND_PORT=127.0.0.1:4730\n' >"$FIXDIR/site-settings.conf"
    echo "$FIXDIR/site-settings.conf"
}

# ---------------------------------------------------------------------------
# GOLDEN site (debate 60 F4): a REAL, version-accurate site home dir created
# by the image's own `omd create`, once per (distro, SITE NAME). The site
# name must match the fixture's site because OMD bakes the site name into
# the tree (apache vhost, site.conf, web credentials); a name mismatch would
# break the apache/ready state of the fixture container.
#
# Why a real tree is REQUIRED (vs the old fake `version ->
# /omd/versions/default` symlink): the entry's omd calls run as root and
# OMD's version-switch (omd.py:5572-5581 -> exec_other_omd :5348-5367) drops
# to the site user and re-execs on ANY version mismatch. A fake symlink
# yields site_version = "default" (omd.py:600-604) != installed => non-root
# re-exec => `only_root` bail (omd.py:5526-5527). A real tree's RELATIVE
# version link (../../versions/<installed>) yields the installed version =>
# no switch => omd enable succeeds as root (proven green by s2's
# replacement-container resume).
#
# The entry's own bootstrap writes .omd-labs-init-complete / -identity into
# the golden's site dir - fx_copy_tree STRIPS those (the fixtures re-add the
# marker(s) they actually want to test). Completion flag .golden-ok is
# written root-side AFTER the clean stop (the host user cannot write the
# site-owned top dir 0750, but a root probe can).
#
# One-shot container on port 18461 (shared with s6e/s7 - runs strictly
# sequential; the golden container is stopped+removed before any scenario).
# fx_golden <distro> <site> -> prints the golden dir path (idempotent)
fx_golden() { # fx_golden <distro> <site>
    local distro=$1 site=$2 gd="$FIXDIR/golden-$1-$2" imgid
    imgid=$(fx_image_id)
    # root-side idempotency: the host user (uid 1000) is NOT a member of the
    # site-owned golden top dir (0750, group omd) - a host [ -f ] would always
    # EACCES even when the golden is valid (all volume checks are
    # root-probe-side per the OWNERSHIP MODEL above). DEBATE 61 N2: the cache
    # key is (image id, site) - the flag file carries both; a rebuilt image
    # (new id) or a different site name INVALIDATES the cached golden.
    if [ -d "$gd" ] && [ -n "$imgid" ] && v_vol_probe "$gd" "test -e /w/.golden-ok && grep -qx 'image=$imgid' /w/.golden-ok && grep -qx 'site=$site' /w/.golden-ok" >/dev/null 2>&1; then
        echo "$gd"
        return 0
    fi
    fx_root_reset "$gd"
    local gname="golden-omdcreate-$site"
    $RUNTIME rm -f "$gname" >/dev/null 2>&1 || true
    # $(v_flags) is REQUIRED here: the golden boots the FULL entry (systemd
    # as PID 1) and the entry's /sys/fs/cgroup writability check refuses an
    # unprivileged start (EMPIRICAL 2026-11-17: S12 first run). The probe-only
    # runs (v_vol_probe, fx_copy_tree, fx_omd_gid) legitimately omit the
    # flags - they never boot systemd.
    $RUNTIME run -d --name "$gname" $(v_flags) $(v_suite_label) \
        -e SITENAME="$site" \
        -v "$gd:/omd/sites/$site:z" -p 18461:443 "$IMAGE" >/dev/null
    # cleanup on ANY exit (kill+rm - a `podman stop` on a systemd-mid-boot
    # container can hang the same way the exec poll below would)
    trap 'fx_golden_cleanup "$gname"' RETURN
    # BOUNDED readiness poll (EMPIRICAL 2026-11-10): `podman exec ...
    # systemctl is-active` on a still-booting systemd container BLOCKS until
    # systemd answers - an unbounded exec froze the whole poll (observed:
    # the first exec during creation never returned, the loop could never
    # iterate, the container was never stopped). `timeout 15` makes each
    # probe bounded; liveness via `inspect` (never blocks).
    local t=0 st
    while (( t < 180 )); do
        if ! $RUNTIME inspect -f '{{.State.Running}}' "$gname" 2>/dev/null | grep -q true; then
            echo "fx_golden: golden container exited before ready" >&2
            $RUNTIME logs "$gname" 2>&1 | tail -10 >&2
            fx_golden_cleanup "$gname"
            return 1
        fi
        st=$(timeout 15 $RUNTIME exec "$gname" systemctl is-active omd-ready 2>/dev/null || true)
        [ "$st" = "active" ] && break
        sleep 5; t=$((t + 5))
    done
    if [ "$st" != "active" ]; then
        echo "fx_golden: golden site not ready within 180s" >&2
        $RUNTIME logs "$gname" 2>&1 | tail -10 >&2
        fx_golden_cleanup "$gname"
        return 1
    fi
    # clean stop (exit 130/0), then mark COMPLETE root-side. DEBATE 61 N2:
    # the flag is written ONLY after a clean stop - an unclean stop
    # invalidates the golden (the tree may be mid-write) and forces a
    # rebuild on the next call
    timeout 60 $RUNTIME stop -t 30 "$gname" >/dev/null 2>&1 || true
    local gcode
    gcode=$($RUNTIME inspect -f '{{.State.ExitCode}}' "$gname" 2>/dev/null || echo unknown)
    if [ "$gcode" != "0" ] && [ "$gcode" != "130" ]; then
        echo "fx_golden: golden stop was UNCLEAN (code=$gcode) - invalidating (next call rebuilds)" >&2
        $RUNTIME logs "$gname" 2>&1 | tail -10 >&2
        fx_golden_cleanup "$gname"
        return 1
    fi
    # the golden is valid only if the site is REALLY complete: version link
    # present (test -L: in the probe container the RELATIVE link dangles -
    # there is no /omd - so -e would always fail) + a CONFIG_ site.conf
    # (not the fixture's cfg=1 stand-in)
    if v_vol_probe "$gd" "test -L /w/version && grep -q CONFIG_ /w/etc/omd/site.conf" >/dev/null; then
        local gmdgid
        gmdgid=$(fx_omd_gid)
        # DEBATE 61 N2: the flag carries the cache key (image id, site) -
        # the idempotency check above compares both
        v_vol_probe "$gd" "printf 'image=%s\nsite=%s\n' '$imgid' '$site' > /w/.golden-ok && chown 1000:$gmdgid /w/.golden-ok" >/dev/null || true
        fx_golden_cleanup "$gname"
        echo "$gd"
        return 0
    fi
    echo "fx_golden: golden site creation failed (version link / site.conf absent, stop code=$gcode)" >&2
    $RUNTIME logs "$gname" 2>&1 | tail -10 >&2
    fx_golden_cleanup "$gname"
    return 1
}

# fx_golden_cleanup <name> - kill+remove the golden container (best effort)
fx_golden_cleanup() {
    $RUNTIME kill "$1" >/dev/null 2>&1 || true
    $RUNTIME rm -f "$1" >/dev/null 2>&1 || true
}

# derive a REAL site tree (from the per-site golden) into <dir>, chowned to
# the given (container-view) uid/gid: subfolders uid:gid, top dir
# uid:omd-gid 0750. The entry's own bootstrap markers written into the
# golden (init-complete / site-identity) are STRIPPED - the fixture then
# adds exactly the marker state it wants to test. args: <site> <uid> <gid>
# <dir>
fx_real_site_tree() {
    local site=$1 uid=$2 gid=$3 d=$4 gd
    fx_root_reset "$d"
    gd=$(fx_golden "$DISTRO" "$site")
    fx_copy_tree "$gd" "$d" "$uid" "$gid"
}

# two-mount root-side copy (debate 60 F4): src (golden, site-owned top dir)
# -> dst (fresh host-owned dir from fx_root_reset); strip the golden flag
# AND the entry's bootstrap markers (the fixture re-adds the markers it
# wants to test), then chown to the fixture identity. v_vol_probe mounts ONE
# dir only, so this runs a direct runtime container with TWO -v flags
# (/g src, /w dst). root can read the site-owned golden top (0750).
# args: <src-hostdir> <dst-hostdir> <uid> <gid>
fx_copy_tree() {
    local src=$1 dst=$2 uid=$3 gid=$4 omdgid lab
    omdgid=$(fx_omd_gid)
    lab=${SELABEL#:}
    $RUNTIME run --rm -v "$src:/g${lab:+:$lab}" -v "$dst:/w${lab:+:$lab}" "$IMAGE" \
        sh -c "cp -a /g/. /w/ && rm -f /w/.golden-ok /w/.omd-labs-init-complete /w/.omd-labs-init-inprogress /w/.omd-labs-site-identity && chown -R $uid:$gid /w && chown $uid:$omdgid /w && chmod 0750 /w" >/dev/null
}

# ---------------------------------------------------------------------------
# MINIMAL FAKE tree (pre-marker legacy stand-in) for fixtures that fatals
# BEFORE reaching any omd call, so the fake `version -> /omd/versions/default`
# symlink (site_version would be "default") is never consulted by OMD:
#   - f (row 3c): odm_tree_complete returns 1 (site.conf absent) -> fatal
#     before any omd call
#   - g1 (B2 ambiguous): adopted -> infer_legacy_identity -> the omd-gid
#     guard fatals before any omd call / mutation
# (debate 60 F5: keep the minimal shape here; g2/g3 + the d-real variants use
# fx_real_site_tree). OMD invariants (user_verify, omd.py:480-508): non-root
# numeric owner, version symlink, etc/omd/site.conf. Home dir group = omd
# group (fx_omd_gid), subfolders group = site primary gid (the D6 B2
# distinction). args: <uid> <gid> <path> (NO markers - callers add them)
# ---------------------------------------------------------------------------
_fx_site_tree() {
    local uid=$1 gid=$2 d=$3 tmp omdgid
    fx_root_reset "$d"
    omdgid=$(fx_omd_gid)
    tmp=$(mktemp -d)
    mkdir -p "$tmp/etc/omd" "$tmp/var/log" "$tmp/local" "$tmp/tmp/run"
    echo "cfg=1" >"$tmp/etc/omd/site.conf"
    ln -s /omd/versions/default "$tmp/version"
    cp -a "$tmp/." "$d/"
    rm -rf "$tmp"
    # root-side chown: numbers are the CONTAINER view - the same mapping the
    # entry runs in
    v_vol_probe "$d" "chown -R $uid:$gid /w && chown $uid:$omdgid /w && chmod 0750 /w" >/dev/null
}

# S6d: interrupted-creation fixtures (D6 row 3a, per-state) - each dir
# carries the in-progress marker + a specific partial state (quickstart S6d).
# DEBATE 60 F1 REWORK: the in-progress marker is added LAST, after every
# reset/copy (the old code touched the marker first and then the tree
# builder's fx_root_reset removed it - the fixtures silently became
# adoption cases, not recovery cases).
#
# Realism (entry create_site ordering): groupadd+useradd -> identity file
# -> apache group -> fstab line -> chown top -> omd create --reuse ->
# commit. So every variant "at or after the account step" carries the
# RECORDED identity file (uid=1234 gid=1234, owned 1234:1234): the recovery
# then reads the recorded identity instead of inferring.
#
# Expected outcomes (encoded per variant; the s6.sh loop asserts exactly
# these): site_mount dispatches on markers FIRST (COMPLETE then INPROG,
# before the row-3b/3c classification), so every variant enters row 3a
# recover_interrupted.
#   account-plus-tree  REAL tree (golden) + version link + identity +
#     marker -> recovery `omd enable` branch (version present = creation
#     had completed) => READY
#   version-link       REAL tree + version link + identity + marker
#     (the create-finished state minus the commit) -> `omd enable` branch
#     => READY
#   tree-only          MINIMAL fake tree (site.conf, NO version link) +
#     identity + marker -> recovery `omd create --reuse` branch (the
#     version symlink is the creation evidence - C7/user_verify only tests
#     its ABSENCE) => READY (or a documented fatal, asserted to the
#     observed outcome with evidence)
#   account-only       identity + marker, EMPTY tree (interrupted right
#     after the account step) -> `omd create --reuse` branch => READY or
#     documented fatal
#   apache-conf        identity + marker + a partial apache-conf artifact
#     (no version link) -> `omd create --reuse` branch => READY or
#     documented fatal
#   fstab             identity + marker, EMPTY tree (the fstab line lives
#     in /etc, not on the volume) -> `omd create --reuse` branch => READY
#     or documented fatal
#   uid-gid-occupied   REAL tree + identity file + marker + an IN-IMAGE
#     account occupying uid 1234 (test-only sub-image, s6.sh) -> recovery
#     step (i) uid-occupied fatal => exit 1, fatal reason "occupied by a
#     different account", no mutation
#
# The MINIMAL fake tree is a deliberately partial stand-in (site.conf=cfg=1,
# NO version symlink - a fake /omd/versions/default link would make
# site_version "default" and misfire OMD's version switch, omd.py:600-604).
# It is only safe where NO omd version check is reached before the asserted
# outcome: the create --reuse branch tests the version symlink's ABSENCE.
_fx_identity() { # _fx_identity <d> - the recorded identity file
    v_vol_probe "$1" "printf 'uid=$FIX_UID gid=$FIX_GID\n' > /w/.omd-labs-site-identity && chown $FIX_UID:$FIX_GID /w/.omd-labs-site-identity" >/dev/null
}

_fx_partial_tree() { # _fx_partial_tree <uid> <gid> <d> [withversion]
    local uid=$1 gid=$2 d=$3 withversion=${4:-no} omdgid
    fx_root_reset "$d"
    omdgid=$(fx_omd_gid)
    # one root-side script on the dir itself: build the tree + chown +
    # marker LAST
    v_vol_probe "$d" "
        mkdir -p /w/etc/omd /w/var/log /w/local /w/tmp/run
        echo 'cfg=1' > /w/etc/omd/site.conf
        if [ '$withversion' = yes ]; then ln -s /omd/versions/default /w/version; fi
        chown -R $uid:$gid /w
        chown $uid:$omdgid /w
        chmod 0750 /w
        touch /w/.omd-labs-init-inprogress
    " >/dev/null
}

fx_d6_interrupted() { # fx_d6_interrupted <site> <variant>
    local site=$1 variant=$2
    local d="$FIXDIR/s6d-$site-$variant"
    case $variant in
        account-plus-tree)
            # REAL tree (per-site golden) + identity + marker LAST (debate
            # 60 F1)
            fx_real_site_tree "$site" "$FIX_UID" "$FIX_GID" "$d"
            _fx_identity "$d"
            v_vol_probe "$d" "touch /w/.omd-labs-init-inprogress" >/dev/null
            ;;
        version-link)
            # REAL tree + version link (create-finished shape) + identity +
            # marker LAST
            fx_real_site_tree "$site" "$FIX_UID" "$FIX_GID" "$d"
            _fx_identity "$d"
            v_vol_probe "$d" "touch /w/.omd-labs-init-inprogress" >/dev/null
            ;;
        tree-only)
            # MINIMAL fake tree WITHOUT the version link (genuinely
            # version-absent: recovery takes the create --reuse branch) +
            # identity + marker LAST
            _fx_partial_tree "$FIX_UID" "$FIX_GID" "$d" no
            _fx_identity "$d"
            v_vol_probe "$d" "touch /w/.omd-labs-init-inprogress" >/dev/null
            ;;
        account-only)
            # identity + marker LAST, EMPTY tree (interrupted right after
            # the account step - the tree is restored by the recovery itself)
            fx_root_reset "$d"
            _fx_identity "$d"
            v_vol_probe "$d" "touch /w/.omd-labs-init-inprogress" >/dev/null
            ;;
        apache-conf)
            # identity + partial apache-conf artifact (no version link) +
            # marker LAST
            fx_root_reset "$d"
            v_vol_probe "$d" "mkdir -p /w/etc/apache && echo conf > /w/etc/apache/site.conf && chown -R $FIX_UID:$FIX_GID /w" >/dev/null
            _fx_identity "$d"
            v_vol_probe "$d" "touch /w/.omd-labs-init-inprogress" >/dev/null
            ;;
        fstab)
            # identity + marker LAST, EMPTY tree (the fstab line lives in
            # /etc, not on the volume - the variant name is historical)
            fx_root_reset "$d"
            _fx_identity "$d"
            v_vol_probe "$d" "touch /w/.omd-labs-init-inprogress" >/dev/null
            ;;
        uid-gid-occupied)
            # REAL tree + recorded identity file + marker LAST; the
            # OCCUPIED ACCOUNT is created by the s6.sh test-only sub-image
            # (it must exist BEFORE the entry runs - a host-side useradd is
            # not possible, the account lives in the container's
            # /etc/passwd, not on the volume). (debate 60 F3)
            fx_real_site_tree "$site" "$FIX_UID" "$FIX_GID" "$d"
            _fx_identity "$d"
            v_vol_probe "$d" "touch /w/.omd-labs-init-inprogress" >/dev/null
            ;;
        *) return 1 ;;
    esac
    echo "$d"
}

# S6e (T023): REAL legacy volume - created by the OLD (baseline-red) image's
# OWN tooling, so it carries exactly what a real old-image volume carries:
# a complete OMD tree (relative version link, CONFIG_ site.conf), the
# stored web credential (etc/htpasswd, apache Basic-Auth user omdadmin)
# with a KNOWN password (FX_LEGACY_PW - the scenario asserts the stored
# credential still logs in after adoption), an ALTERED site.conf value
# (CONFIG_ADMIN_MAIL - the scenario asserts `omd config show` returns the
# STORED value), correct numeric ownership (top uid:omdgid 0750,
# subfolders uid:gid 0755), and NO .omd-labs-* markers (the old image
# never writes them - that is what makes the volume adoptable, row 3b).
#
# DEBATE 64 B1/B2 REWORK: the fixture uid and primary gid are DISTINCT
# (FX_LEGACY_UID/FX_LEGACY_GID, default 2001/2002 - the old 1001/1001 made
# a wrong-field ownership check pass by coincidence), and the fixture
# seeds SENTINELS in the persistent paths (etc/omd, var/lib, local) so the
# scenario can prove "sentinel/monitoring data untouched". The .meta file
# is the SINGLE SOURCE OF TRUTH for the scenario's assertions: it records
# the baseline image id, the requested pw/mail values and the uid/gid, and
# the reuse validation compares ALL of them (a retagged baseline or a
# changed override REBUILDS the volume - no stale data, no misleading
# failure).
#
# The old image bakes the `demo` site at BUILD time (user, /opt/omd/sites/
# demo, fstab tmpfs line); an arbitrary site name needs the same preconditions
# created at RUN time (EMPIRICAL 2026-11-10 - omd create --reuse failed
# without the apache user in the site group AND the fstab tmpfs line):
#   groupadd + useradd <site> (secondary group omd) + usermod -aG <site>
#   <apache user> + /opt/omd/sites/<site> + the fstab tmpfs entry (NAME
#   form uid=<site>, - omd fstab_verify rejects numeric uids), then
#   omd create --reuse <site> + omd reset etc/ (as <site>) +
#   set_admin_password (KNOWN) + site.conf alter + sentinel seeding.
#
# Idempotency (root-side probe + .meta validation, as documented above):
# the tree is site-owned (host EACCES) and a rebuild is needed whenever the
# baseline image id, the requested pw/mail, or the marker/sentinel state
# disagrees with .meta.
# fx_real_legacy_volume <distro> <site> -> prints the volume dir
fx_real_legacy_volume() { # fx_real_legacy_volume <distro> <site>
    local distro=$1 site=$2
    local d="$FIXDIR/s6e-legacy-$distro-$site"
    local oldimg="local/omd-labs-$distro:baseline-red"
    local oldimgid pw mail u g
    pw=${FX_LEGACY_PW:-T023legacyPW}
    mail=${FX_LEGACY_MAIL:-t023-legacy@omd.example}
    u=${FX_LEGACY_UID:-2001}
    g=${FX_LEGACY_GID:-2002}
    oldimgid=$(fx_image_id "$oldimg")
    local meta="$d.meta"
    # reuse validation (debate 64 NOTE): baseline image id + requested
    # values + marker-free volume WITH the sentinels all must agree
    if [ -f "$meta" ] \
        && [ "$(sed -n 's/^image=//p' "$meta")" = "$oldimgid" ] \
        && [ "$(sed -n 's/^pw=//p' "$meta")" = "$pw" ] \
        && [ "$(sed -n 's/^mail=//p' "$meta")" = "$mail" ] \
        && v_vol_probe "$d" "test -L /w/version && grep -q CONFIG_ADMIN_MAIL /w/etc/omd/site.conf && grep -q omdadmin /w/etc/htpasswd && { for f in /w/etc/omd/sentinel.conf /w/var/lib/sentinel.dat /w/local/sentinel.txt; do grep -q 'SENTINEL_T023=$distro' \"\$f\" || exit 1; done; } && ! ls /w/.omd-labs-* 2>/dev/null" >/dev/null 2>&1; then
        echo "$d"
        return 0
    fi
    fx_root_reset "$d"
    $RUNTIME run --rm -v "$d:/omd/sites/$site:z" "$oldimg" bash -c "
        export SITENAME=$site
        AU=apache; [ \"\$(. /etc/os-release 2>/dev/null; echo \${ID:-})\" = debian ] && AU=www-data
        getent group $site >/dev/null || groupadd -g $g $site
        id $site >/dev/null 2>&1 || useradd -u $u -g $site -G omd -d /omd/sites/$site -M -s /bin/bash $site
        usermod -aG $site \$AU
        mkdir -p /opt/omd/sites/$site
        chown $site:omd /opt/omd/sites/$site
        # EMPIRICAL 2026-11-10: omd fstab_verify REQUIRES the NAME form
        # uid=<site>, (omd.py fstab_verify: the line must carry "uid=%s," %
        # sitename + the mountpoint) - a numeric uid=<num>, is REJECTED
        grep -q \"/opt/omd/sites/$site/tmp\" /etc/fstab || echo \"tmpfs  /opt/omd/sites/$site/tmp tmpfs noauto,user,mode=755,uid=$site,gid=$site 0 0\" >> /etc/fstab
        omd create --reuse $site || exit 1
        su - $site -c \"omd reset etc/\" || exit 1
        su - $site -c \"set_admin_password $pw\" || exit 1
        su - $site -c \"sed -i \\\"s|^CONFIG_ADMIN_MAIL=.*|CONFIG_ADMIN_MAIL='$mail'|\\\" /omd/sites/$site/etc/omd/site.conf\" || exit 1
        # seeded sentinels (debate 64 B2): the scenario asserts their
        # content + uid/gid/mode are UNTOUCHED by the adoption
        su - $site -c \"mkdir -p /omd/sites/$site/var/lib && printf 'SENTINEL_T023=$distro config\\n' > /omd/sites/$site/etc/omd/sentinel.conf && printf 'SENTINEL_T023=$distro monitoring\\n' > /omd/sites/$site/var/lib/sentinel.dat && printf 'SENTINEL_T023=$distro localdata\\n' > /omd/sites/$site/local/sentinel.txt\" || exit 1
    " >/dev/null
    # validate + record the identity + requested values + baseline image
    # id (the .meta is the scenario's single source of truth)
    local metaout
    metaout=$(v_vol_probe "$d" "u=\$(stat -c %u /w); g=\$(stat -c %g /w/etc); [ \"\$u\" = $u ] || exit 1; [ \"\$g\" = $g ] || exit 1; for f in /w/etc/omd/sentinel.conf /w/var/lib/sentinel.dat /w/local/sentinel.txt; do grep -q 'SENTINEL_T023=$distro' \"\$f\" || exit 1; done; grep -q CONFIG_ADMIN_MAIL /w/etc/omd/site.conf || exit 1; grep -q omdadmin /w/etc/htpasswd || exit 1; [ -L /w/version ] || exit 1; echo ok")
    [ -n "$metaout" ] || { echo "fx_real_legacy_volume: creation failed (no valid tree) for $site" >&2; return 1; }
    {
        echo "image=$oldimgid"
        echo "site=$site"
        echo "pw=$pw"
        echo "mail=$mail"
        echo "uid=$u"
        echo "gid=$g"
    } >"$meta"
    echo "$d"
}

# S6e: LEGACY volume (D6 row 3b) - complete OMD tree, NO markers
fx_legacy_volume() { # fx_legacy_volume <site> [uid] [gid]
    local site=$1 uid=${2:-$FIX_UID} gid=${3:-$FIX_GID}
    local d="$FIXDIR/s6e-$site"
    fx_root_reset "$d"
    _fx_site_tree "$uid" "$gid" "$d"
    echo "$d"
}

# S6f: pre-marker INCOMPLETE tree (D6 row 3c) - legacy invariants minus
# site.conf (root-side delete: the tree is site-owned after _fx_site_tree)
fx_premarker_incomplete() { # fx_premarker_incomplete <site>
    local site=$1 d
    d=$(fx_legacy_volume "$site")
    v_vol_probe "$d" "rm -f /w/etc/omd/site.conf" >/dev/null
    echo "$d"
}

# S6g identity fixtures (round-2 B2):
# g1: legacy volume whose SITE-OWNED subfolders are group-owned by the
#     omd-group gid - the inference guard must refuse (ambiguous primary
#     gid), byte-identical. Keeps the MINIMAL fake tree (debate 60 F5): the
#     ambiguity guard fatals (entry infer_legacy_identity) BEFORE any omd
#     call, so the fake version symlink is never consulted.
# g2: completed volume + init-complete marker, identity file ABSENT -
#     resume via inference (uid from home owner, gid from a site-owned
#     subfolder group) + re-record of .omd-labs-site-identity. REAL tree
#     (the resume path runs `omd enable` - version must be accurate).
# g3: completed volume + marker + identity file - the RECORDED uid/gid
#     must be honored (id <site> matches). REAL tree (same reason as g2).
fx_identity_ambiguous() { # fx_identity_ambiguous <site>
    local site=$1 d omdgid
    d=$(fx_legacy_volume "$site")
    omdgid=$(fx_omd_gid)
    v_vol_probe "$d" "chgrp -R $omdgid /w/etc /w/var /w/local" >/dev/null
    echo "$d"
}

fx_identity_lost() { # fx_identity_lost <site>
    local site=$1
    local d="$FIXDIR/s6g2-$site"
    # REAL (per-site golden) tree: the resume path runs `omd enable`
    # (restore_registration), which needs a version-accurate tree
    # (debate 60 F4)
    fx_real_site_tree "$site" "$FIX_UID" "$FIX_GID" "$d"
    # marker as the entry writes it (site:omd), root-side
    v_vol_probe "$d" "touch /w/.omd-labs-init-complete && chown $FIX_UID:$(fx_omd_gid) /w/.omd-labs-init-complete" >/dev/null
    echo "$d"
}

fx_identity_recorded() { # fx_identity_recorded <site> <uid> <gid>
    local site=$1 uid=$2 gid=$3 d
    d=$(fx_identity_lost "$site")
    v_vol_probe "$d" "echo 'uid=$uid gid=$gid' > /w/.omd-labs-site-identity && chown $uid:$gid /w/.omd-labs-site-identity" >/dev/null
    echo "$d"
}

# S6g7 (T026, codex 75 B1): MALFORMED recorded identity - the single line of
# .omd-labs-site-identity does not carry a numeric uid (corruption / hand
# edit / a hostile volume). The entry must fatal "malformed" BEFORE any
# write (the restore path re-writes the identity file - a fail-fast must not
# have touched the volume). REAL tree (the resume path runs omd enable).
fx_identity_malformed() { # fx_identity_malformed <site>
    local site=$1 d
    d=$(fx_identity_lost "$site")
    v_vol_probe "$d" "printf 'uid=abc gid=$FIX_GID\n' > /w/.omd-labs-site-identity && chown $FIX_UID:$FIX_GID /w/.omd-labs-site-identity" >/dev/null
    echo "$d"
}

# S6g8 (T026, codex 75 N1): STALE in-progress marker on a persisted volume
# (init-complete present + in-progress present, identity LOST) - the entry
# must resume (inference + re-record) and REMOVE the stale marker only after
# validation. The collision half (marker RETAINED on fail-fast) is the g5
# pattern with the marker - exercised by the standalone matrix F3b.
fx_persisted_stale_marker() { # fx_persisted_stale_marker <site>
    local site=$1 d
    d=$(fx_identity_lost "$site")
    v_vol_probe "$d" "touch /w/.omd-labs-init-inprogress" >/dev/null
    echo "$d"
}

fx_teardown_all() {
    # root-side wipe (site-owned leftovers defeat a host rm -rf)
    v_vol_probe "$FIXDIR" "find /w -mindepth 1 -maxdepth 1 -exec rm -rf {} +" >/dev/null 2>&1 || true
    rm -rf "$FIXDIR" 2>/dev/null || true
    rm -f /tmp/omd-test-key /tmp/omd-test-key.pub /tmp/omd-badkey 2>/dev/null || true
}
