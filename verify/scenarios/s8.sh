#!/usr/bin/env bash
# S8 - Build-time unit state audit (D8; FR-002/FR-003; N1)
# site case: is-enabled matrix + no other-site daemons;
# no-site case (N1): omd-site stays ENABLED, starts as no-op (active),
# normal stop + restart cycle works without a site.
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/common.sh"
. "$VER_DIR/fixtures.sh"

P=$(v_port s8)
E=$EDGE_UNIT
C=$CRON_UNIT

# codex 90 MAJOR 1 (s8 rework): the old "byte-identical" assertion hashed
# ONLY regular-file CONTENT - a chown/chmod, a new empty dir, or a symlink
# retarget would have passed "unchanged". vol_manifest covers the mount
# root itself + every entry's type, numeric uid/gid (lstat numbers for
# symlinks), mode, symlink target and regular-file content sha256.
# SELinux security-xattrs are deliberately EXCLUDED: the :z mount label
# opts into the runtime relabel, which is the INTENDED behavior (codex 90:
# "account for intentional runtime SELinux relabeling").
vol_manifest() { # vol_manifest <dir> -> sha256 of the sorted entry manifest
    local d=$1
    ( cd "$d" &&
      {
        printf 'd|.|%s|%s|%s||\n' "$(stat -c %u .)" "$(stat -c %g .)" "$(stat -c %a .)"
        find . -mindepth 1 | LC_ALL=C sort | while IFS= read -r p; do
            q=${p#./}
            if [ -L "$p" ]; then
                printf 'L|%s|%s|%s|%s|%s|\n' "$q" "$(stat -c %u "$p")" "$(stat -c %g "$p")" "$(stat -c %a "$p")" "$(readlink "$p")"
            elif [ -d "$p" ]; then
                printf 'd|%s|%s|%s|%s||\n' "$q" "$(stat -c %u "$p")" "$(stat -c %g "$p")" "$(stat -c %a "$p")"
            elif [ -f "$p" ]; then
                h=$(sha256sum "$p" 2>&1) || { echo "vol_manifest: cannot read content of $p (unreadable files would degrade the hash silently)" >&2; exit 1; }
                printf 'f|%s|%s|%s|%s||%s\n' "$q" "$(stat -c %u "$p")" "$(stat -c %g "$p")" "$(stat -c %a "$p")" "$(echo "$h" | cut -d' ' -f1)"
            else
                printf 'o|%s|%s|%s|%s||\n' "$q" "$(stat -c %u "$p")" "$(stat -c %g "$p")" "$(stat -c %a "$p")"
            fi
        done
      } | sha256sum | cut -d' ' -f1 )
}

# codex 90 MAJOR 2: absence proofs must require a SUCCESSFUL observation -
# the old bodies let any failed runtime exec/id/ps count as "absence" and
# pass. ps_user_guard <container> [allowed-user]: enumerates the container's
# process users; rc 1 = violation (a uid>=1000 user other than the allowed
# one), rc 2 = process enumeration failed (observation impossible),
# rc 3 = an unresolvable user name (fail unresolved observations).
# rc 0 = absence established by a SUCCESSFUL enumeration.
ps_user_guard() {
    $RUNTIME exec -e GUARD_ALLOWED="${2:-}" "$1" \
        sh -c 'out=$(ps -eo user= 2>/dev/null) || exit 2; for u in $(echo "$out" | sort -u); do [ -n "$u" ] || continue; uid=$(id -u "$u" 2>/dev/null) || exit 3; case "$uid" in [1-9][0-9][0-9][0-9]*) [ "$u" != "${GUARD_ALLOWED:-}" ] && exit 1;; esac; done; exit 0'
}

v_begin "S8-$SCEN-$DISTRO"

# --- site case (audit needs no persistence - no mount) ---
v_run omd-s8 "$IMAGE" "$P" "" -e SITENAME=auditsite
v_check "readiness (gate + /auditsite/)" \
    'set +e; rt=$(v_wait_ready omd-s8 '"$P"' /auditsite/); rc=$?; echo "ready-time=${rt}s"; exit $rc'

enabled_list=$($RUNTIME exec omd-s8 systemctl list-unit-files --state=enabled --no-legend 2>/dev/null | tr '\n' '; ' || true)
v_note "enabled unit files (evidence): $enabled_list"

# is-enabled captures: alias units exit 0 (print "alias"); masked/disabled
# units exit NON-zero (masked=1, disabled=1) - without `|| true` the
# fallback appends "unknown" as a SECOND line and the value becomes
# multi-line (EMPIRICAL: pre-alias omd.service captured "masked" + unknown;
# the sshd capture died on a literal quoted unit name).
st_omd=$($RUNTIME exec omd-s8 systemctl is-enabled omd.service 2>/dev/null | head -n1 || true)
st_edge=$($RUNTIME exec omd-s8 systemctl is-enabled $E 2>/dev/null | head -n1 || true)
st_sshd=$($RUNTIME exec omd-s8 systemctl is-enabled $SSH_UNIT 2>/dev/null | head -n1 || true)
st_cron=$($RUNTIME exec omd-s8 systemctl is-enabled $C 2>/dev/null | head -n1 || true)
st_site=$($RUNTIME exec omd-s8 systemctl is-enabled omd-site 2>/dev/null | head -n1 || true)
st_ready=$($RUNTIME exec omd-s8 systemctl is-enabled omd-ready 2>/dev/null | head -n1 || true)
v_check "is-enabled (site case): omd.service=alias (got '$st_omd'), $E=enabled ('$st_edge'), $SSH_UNIT=enabled ('$st_sshd'), $C=enabled ('$st_cron'), omd-site=enabled ('$st_site'), omd-ready=enabled ('$st_ready')" \
    'set +e; [ '"$st_omd"' = alias ] && [ '"$st_edge"' = enabled ] && [ '"$st_sshd"' = enabled ] && [ '"$st_cron"' = enabled ] && [ '"$st_site"' = enabled ] && [ '"$st_ready"' = enabled ]'

# D8 supersession (debate/100-103): omd.service is an ALIAS of omd-site -
# positive identity checks (same canonical Id + fragment + both names), not
# the old "masked" assertion. is-enabled alone is not proof of the alias
# (codex 101 F4): assert the identity via `systemctl show`.
# NOTE: `systemctl show -p` prints "Property=value" (prefix kept) and Names
# contains a SPACE - so strip the prefix with cut and test Names as a
# substring (multi-word values break [ "$x" = y ] comparisons).
alias_id=$($RUNTIME exec omd-s8 sh -c 'systemctl show omd.service -p Id 2>/dev/null' | head -n1 | cut -d= -f2- || true)
alias_frag=$($RUNTIME exec omd-s8 sh -c 'systemctl show omd.service -p FragmentPath 2>/dev/null' | head -n1 | cut -d= -f2- || true)
alias_names=$($RUNTIME exec omd-s8 sh -c 'systemctl show omd.service -p Names 2>/dev/null' | head -n1 | cut -d= -f2- || true)
alias_load=$($RUNTIME exec omd-s8 sh -c 'systemctl show omd.service -p LoadState 2>/dev/null' | head -n1 | cut -d= -f2- || true)
alias_symlink=$($RUNTIME exec omd-s8 sh -c 'readlink -f /etc/systemd/system/omd.service 2>/dev/null' || true)
v_note "omd.service alias (evidence): Id=$alias_id FragmentPath=$alias_frag Names=[$alias_names] LoadState=$alias_load symlink=$alias_symlink"
v_check "omd.service alias identity (site case): Id=omd-site.service, FragmentPath=/usr/lib/systemd/system/omd-site.service, Names contains both names, /etc alias resolves to the canonical unit" \
    'set +e; [ '"$alias_id"' = omd-site.service ] && [ '"$alias_frag"' = /usr/lib/systemd/system/omd-site.service ] && case "'"$alias_names"'" in *"omd-site.service"*) ;; *) exit 1;; esac && case "'"$alias_names"'" in *"omd.service"*) ;; *) exit 1;; esac && [ '"$alias_symlink"' = /usr/lib/systemd/system/omd-site.service ]'

# the vendor all-sites unit file is kept (package-owned) but shadowed by the
# /etc alias at load time - the unit must be LOADED (not masked) and resolve
# to the canonical omd-site fragment.
v_check "omd.service not masked/vendor-shadowed (site case): LoadState=loaded (got '$alias_load')" \
    'set +e; [ '"$alias_load"' = loaded ]'

# getty@tty1 disabled (units/README-units.md: plain disable, no mask).
# is-enabled of a disabled unit exits non-zero (pipefail-unsafe inline),
# so capture first, then assert on the captured first line.
getty_st=$($RUNTIME exec omd-s8 sh -c 'systemctl is-enabled getty@tty1 2>/dev/null' | head -n1 || true)
v_check "getty@tty1 disabled (container console model, got '$getty_st')" \
    'set +e; case "'"$getty_st"'" in disabled|masked) exit 0;; *) exit 1;; esac'

v_check "site case: /omd/sites contains only the selected site" \
    "[ \"\$(\$RUNTIME exec omd-s8 ls /omd/sites 2>/dev/null | tr '\\n' ' ')\" = 'auditsite ' ]"

# codex 90 MAJOR 2 (rework): the old body passed whenever the ps/id
# OBSERVATION failed (empty loop -> exit 0). ps_user_guard (above) requires
# a successful enumeration; rc 1 = violation, rc 2 = ps failed,
# rc 3 = unresolvable user. The final command is the rc test (v_check
# counts only the final command's status, common.sh:344-350).
v_check "site case: no process runs as an unexpected site user (only auditsite uid>=1000)" \
    'set +e; ps_user_guard omd-s8 auditsite; rc=$?; [ $rc -eq 0 ]'

v_teardown omd-s8

# --- no-site MOUNT variant (T021/US3-sc5, D6 row 5): a populated host dir
# mounted at a site path WITHOUT SITENAME is left byte-identical and
# untouched (no account, no markers, no writes) ---
VOL="$FIXDIR/s8-vol"
rm -rf "$VOL"; mkdir -p "$VOL/data"
echo "keep-1" >"$VOL/data/f1"; echo "keep-2" >"$VOL/f2"
# seeded symlink + second file: give the negative control (codex 90 MAJOR 1)
# a symlink to retarget and a file to chown/chmod
ln -s data/f1 "$VOL/link-to-f1"; echo "link-target" >"$VOL/target-of-link"
ck_before=$(vol_manifest "$VOL")
v_run omd-s8-vol "$IMAGE" "$P" "" $(v_vol "$VOL" /omd/sites/volsite z)
v_check "no-site mount: ready (base path, no site)" \
    'set +e; rt=$(v_wait_ready omd-s8-vol '"$P"' /); rc=$?; echo "ready-time=${rt}s"; exit $rc'
# codex 90 MAJOR 2 (rework): absence requires a SUCCESSFUL observation -
# the old bodies passed whenever the id/ls EXEC itself failed (an
# inaccessible mount or dead container would have looked like "no
# account"). codex 92 MAJOR 1: the FIRST rework still let EVERY nonzero
# id/exec rc pass - a failing runtime looks identical to "no such user".
# Final form: a SUCCESSFUL passwd enumeration (getent passwd rc 0) +
# volsite absent from the captured entries; the id diagnostic (empty iff
# the observation itself failed) is carried as evidence. A failing
# runtime -> getent rc != 0 -> FAIL (the negative control below proves
# the failure mode cannot satisfy this check).
v_check "no-site mount: no account created for the mounted dir (volsite absent from a successful passwd enumeration)" \
    'set +e; p=$('"$RUNTIME"' exec omd-s8-vol getent passwd 2>&1); prc=$?; [ $prc -eq 0 ] || { echo "exec FAILED - cannot prove absence (passwd enumeration rc=$prc): $p"; exit 1; }; hit=$(echo "$p" | grep -c "^volsite:"); [ "$hit" -eq 0 ] || { echo "UNEXPECTED: volsite account EXISTS: $(echo "$p" | grep "^volsite:")"; exit 1; }; r=$('"$RUNTIME"' exec omd-s8-vol id volsite 2>&1); idrc=$?; [ -n "$r" ] || { echo "id observation FAILED (empty capture) - absence unproven"; exit 1; }; echo "passwd enumeration ok (rc=0), volsite absent; id evidence (rc=$idrc): $r"'
# NEGATIVE CONTROL (codex 92 MAJOR 1): the no-account body with a
# DELIBERATELY failing runtime must FAIL - a failed observation can never
# satisfy the absence assertion (the pre-fix shape returned 0 here). The
# SAME assertion logic is evaluated with a nonexistent runtime inside an
# INNER SUBSHELL (so its `exit 1` cannot kill the check's own subshell -
# the t029c defect, where the bare rejection exit was read as the check
# failing); the captured rc is asserted NON-zero as the FINAL command
# (v_check counts only the final command's status, common.sh:344-350).
# If the broken runtime somehow PASSED every step (the vacuous case), the
# inner subshell exits 0 and the final test FAILS.
v_check "no-site mount: negative control - a failing runtime CANNOT satisfy the no-account check" \
    'set +e; out=$( ( p=$(nonexistent-runtime-xyz exec omd-s8-vol getent passwd 2>&1); prc=$?; [ $prc -eq 0 ] || { echo "rejection: getent rc=$prc"; exit 1; }; hit=$(echo "$p" | grep -c "^volsite:"); [ "$hit" -eq 0 ] || { echo "rejection: volsite present"; exit 1; }; r=$(nonexistent-runtime-xyz exec omd-s8-vol id volsite 2>&1); idrc=$?; [ -n "$r" ] || { echo "rejection: empty id capture"; exit 1; }; echo "UNREACHED: the broken runtime satisfied the no-account logic (vacuous)" ) 2>&1); rc=$?; [ $rc -ne 0 ] && echo "broken-runtime evaluation rejected (rc=$rc): $out"'
v_check "no-site mount: no marker written (no omd-labs file in the dir)" \
    'set +e; l=$('"$RUNTIME"' exec omd-s8-vol ls -a /omd/sites/volsite 2>&1); erc=$?; [ $erc -eq 0 ] || { echo "exec FAILED - cannot prove absence:"; echo "$l"; exit 1; }; m=$(echo "$l" | grep omd-labs); [ -n "$m" ] && { echo "marker present: $m"; exit 1; }; echo "ls succeeded, no omd-labs entry; dir: $l"'
t0=$(date +%s)
v_stop omd-s8-vol >/dev/null
stop_elapsed=$(( $(date +%s) - t0 ))
vcode=$(v_exited_code omd-s8-vol)
v_check "no-site mount: stop -t 30 clean in ${stop_elapsed}s (exit $vcode, 130/0 not 137 - guarded stop wrapper no-ops)" \
    'set +e; [ '"$stop_elapsed"' -le 30 ] && case '"$vcode"' in 130|0) ;; *) exit 1;; esac'
# codex 92 MAJOR 2: the post-stop manifest is captured and compared to the
# baseline BEFORE any control mutation - a startup write (including a
# symlink retarget) is established here, before the control can overwrite
# anything. A failed capture (empty hash) FAILS.
ck_post=$(vol_manifest "$VOL")
v_check "no-site mount: post-stop manifest equals the pre-run baseline (integrity established before any control mutation)" \
    '[ -n "'"$ck_post"'" ] && [ "'"$ck_post"'" = "'"$ck_before"'" ]'
# NEGATIVE CONTROL (codex 90 MAJOR 1, reworked per codex 92 MAJOR 2): the
# manifest comparison must FAIL on the mutations the old hash-only
# comparison could not see - ownership (container-view numeric, via the
# root probe: the host user cannot chown to another uid), mode, a new
# empty dir, and a symlink retarget. The container is STOPPED, so the
# volume is free to mutate. PER codex 92: every vol_manifest call inside
# the set +e body has its rc checked (a failed capture cannot count as a
# detected mutation), and the control restores the ACTUAL pre-control
# state captured just before (original numeric ownership, mode, symlink
# target) - NOT hard-coded fixture values, so a startup regression in the
# symlink target is neither erased nor confused with a control artifact.
# The restored manifest must equal ck_post (the actual pre-control state).
# The final command is the combined test (v_check counts only the final
# command's status, common.sh:344-350).
v_check "no-site mount: negative control - ownership, mode, new dir, and symlink-target mutations are DETECTED" \
    'set +e; ok=0; orig=$(v_vol_probe "$VOL" "stat -c %u:%g /w/f2"); [ -n "$orig" ] || { echo "cannot capture original ownership via the root probe"; exit 1; }; orig_mode=$(stat -c %a "$VOL/f2"); lnk_orig=$(readlink "$VOL/link-to-f1"); [ -n "$lnk_orig" ] || { echo "cannot capture the pre-control symlink target"; exit 1; }; if [ "$lnk_orig" = "data/f1" ]; then lnk_alt="target-of-link"; else lnk_alt="data/f1"; fi; mcap() { local m rc; m=$(vol_manifest "$VOL"); rc=$?; [ "$rc" -eq 0 ] || { echo "vol_manifest capture FAILED (rc=$rc; codex 94: a partial digest with nonzero status must not be used)"; return 1; }; [ -n "$m" ] || { echo "vol_manifest capture EMPTY (rc=0 but no digest)"; return 1; }; echo "$m"; }; v_vol_probe "$VOL" "chown 9999:9999 /w/f2" >/dev/null || { echo "setup: chown failed"; exit 1; }; m1=$(mcap) || exit 1; [ "$m1" != "$ck_post" ] || { echo "NOT detected: chown f2"; ok=1; }; v_vol_probe "$VOL" "chown $orig /w/f2" >/dev/null || { echo "revert: chown failed"; exit 1; }; chmod 600 "$VOL/f2" || { echo "setup: chmod failed"; exit 1; }; m2=$(mcap) || exit 1; [ "$m2" != "$ck_post" ] || { echo "NOT detected: chmod f2"; ok=1; }; chmod "$orig_mode" "$VOL/f2" || { echo "revert: chmod failed"; exit 1; }; mkdir "$VOL/newdir" || { echo "setup: mkdir failed"; exit 1; }; m3=$(mcap) || exit 1; [ "$m3" != "$ck_post" ] || { echo "NOT detected: new dir"; ok=1; }; rmdir "$VOL/newdir" || { echo "revert: rmdir failed"; exit 1; }; ln -sf "$lnk_alt" "$VOL/link-to-f1" || { echo "setup: ln failed"; exit 1; }; m4=$(mcap) || exit 1; [ "$m4" != "$ck_post" ] || { echo "NOT detected: symlink retarget"; ok=1; }; ln -sf "$lnk_orig" "$VOL/link-to-f1" || { echo "revert: ln failed"; exit 1; }; m5=$(mcap) || exit 1; [ "$m5" = "$ck_post" ] || { echo "restore incomplete (restored != actual pre-control state)"; ok=1; }; [ $ok -eq 0 ] && echo "all 4 mutation classes detected; volume restored to its ACTUAL pre-control state (orig $orig/$orig_mode, link -> $lnk_orig, retargeted via $lnk_alt)"'
# NEGATIVE CONTROL (codex 94): a FAILED vol_manifest capture - a partial
# digest with NONZERO status - must not count as a "detected mutation".
# The stub replaces vol_manifest inside the control body's subshell with
# one that emits a digest and returns 1; the inner control logic must then
# FAIL (exit non-zero via mcap's guard), and the final command asserts that
# failure (captured rc, same shape as the failing-runtime control).
v_check "no-site mount: negative control - a nonzero-status vol_manifest capture CANNOT count as a detected mutation" \
    'set +e; out=$( ( vol_manifest() { echo "deadbeef00000000000000000000000000000000000000000000000000000000"; return 1; }; ok=0; orig=$(v_vol_probe "$VOL" "stat -c %u:%g /w/f2"); [ -n "$orig" ] || exit 1; orig_mode=$(stat -c %a "$VOL/f2"); lnk_orig=$(readlink "$VOL/link-to-f1"); [ -n "$lnk_orig" ] || exit 1; if [ "$lnk_orig" = "data/f1" ]; then lnk_alt="target-of-link"; else lnk_alt="data/f1"; fi; mcap() { local m rc; m=$(vol_manifest "$VOL"); rc=$?; [ "$rc" -eq 0 ] || { echo "rejection: capture rc=$rc"; return 1; }; [ -n "$m" ] || { echo "rejection: empty capture"; return 1; }; echo "$m"; }; m1=$(mcap) || { echo "rejection: mcap refused the failed capture (required)"; exit 1; }; echo "UNREACHED: the failed capture was accepted (vacuous)"; ) 2>&1); rc=$?; [ $rc -ne 0 ] && echo "failed-capture evaluation rejected (rc=$rc): $out"'
$RUNTIME start omd-s8-vol
v_check "no-site mount: restart ready again (full cycle)" \
    'set +e; rt=$(v_wait_ready omd-s8-vol '"$P"' /); rc=$?; echo "ready-time=${rt}s"; exit $rc'
# codex 90 MAJOR 1 (rework): content-hash-only comparison is replaced by
# the checked MANIFEST (mount-root + entry types + numeric uid/gid + modes
# + symlink targets + file contents; SELinux xattrs excluded as the
# intended :z relabel).
ck_after=$(vol_manifest "$VOL")
v_check "no-site mount: volume manifest identical before/after (types, ownership, modes, symlink targets, contents)" \
    '[ -n "'"$ck_after"'" ] && [ "'"$ck_after"'" = "'"$ck_before"'" ]'
v_teardown omd-s8-vol

# --- no-site case (N1 - the unit must stay ENABLED, not disabled offline) ---
v_run omd-s8-none "$IMAGE" "$P" ""
# LATENT RACE (EMPIRICAL: st_site_ns='unknown' twice while the other two
# captures succeeded): the first exec may land before systemd answers -
# wait for the readiness gate before capturing (base path, no site).
v_wait_ready omd-s8-none "$P" / || true
st_site_ns=$($RUNTIME exec omd-s8-none systemctl is-enabled omd-site 2>/dev/null | head -n1 || echo unknown)
st_ready_ns=$($RUNTIME exec omd-s8-none systemctl is-enabled omd-ready 2>/dev/null | head -n1 || echo unknown)
st_active_ns=$($RUNTIME exec omd-s8-none systemctl is-active omd-site 2>/dev/null | head -n1 || echo unknown)
v_check "N1: no-site: omd-site enabled ('$st_site_ns'), omd-ready enabled ('$st_ready_ns'), omd-site active as no-op ('$st_active_ns')" \
    'set +e; [ '"$st_site_ns"' = enabled ] && [ '"$st_ready_ns"' = enabled ] && [ '"$st_active_ns"' = active ]'

# codex 90 MAJOR 2 (rework): same guard as the site case - the old body
# passed when the ps/id observation FAILED (empty loop -> exit 0).
v_check "N1: no-site: no site daemons run (no uid>=1000 process user)" \
    'set +e; ps_user_guard omd-s8-none ""; rc=$?; [ $rc -eq 0 ]'

t0=$(date +%s)
v_stop omd-s8-none >/dev/null
stop_elapsed=$(( $(date +%s) - t0 ))
code=$(v_exited_code omd-s8-none)
v_check "N1: no-site stop -t 30 clean in ${stop_elapsed}s (exit $code, 130/0 not 137 - guarded stop wrapper)" \
    'set +e; [ '"$stop_elapsed"' -le 30 ] && case '"$code"' in 130|0) ;; *) exit 1;; esac'

$RUNTIME start omd-s8-none
# codex-87 (g) class: the old body ended `[ "$st" = active ] && exit $rc;
# exit $rc` - the active-state test was DISCARDED (both branches exit
# $rc), so a no-site restart with omd-site INACTIVE would have passed
# purely on readiness. Now the final command is the combined test
# (readiness rc AND omd-site active) - v_check counts only the final
# command's status (common.sh:344-350).
v_check "N1: no-site restart: still enabled, still a no-op, ready again (full cycle)" \
    'set +e; rt=$(v_wait_ready omd-s8-none '"$P"' /); rc=$?; st=$('"$RUNTIME"' exec omd-s8-none systemctl is-active omd-site 2>/dev/null || echo unknown); echo "ready-time=${rt}s omd-site-active=$st"; [ $rc -eq 0 ] && [ "$st" = active ]'

v_teardown omd-s8-none
v_note "enabled-set audit target: units/README-units.md (T012/T029 assert against it)"
v_end
