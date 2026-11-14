#!/usr/bin/env bash
# S6 - Customization failure + persisted/adopted notice + interrupted-init +
#      legacy adoption (US5 sc3/sc4; FR-009/FR-011/FR-012)
# Sub-items: a, b (invalid key/value + the retry half: a retry with
# corrected input must RECOVER (row 3a, re-apply the corrected settings),
# never ADOPT (T027 BLOCKER fix, codex 81); incl. the (c) multi-setting
# partial-application failure case), d (interrupted-creation matrix),
# f (pre-marker incomplete), g (identity fixtures g1-g3 + T026 N1: g4/g5
#   occupied uid/gid on resume AND adopt, g6 stale in-progress marker on a
#   persisted volume, g7 malformed identity, g8 stale-marker + foreign-gid
#   collision, g9 GID-only foreign collision, g10 inverse collision
#   (site-named group at a different gid)), e (legacy adoption core, REAL
#   old-image volume via fx_real_legacy_volume - T023), e-inputs (T2c input
#   half - FR-012 notice + no-apply, distinct legacy volume).
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/common.sh"

SUBITEM=${1:-all}
. "$VER_DIR/fixtures.sh"

P=$(v_port s6)          # 18459 for a/b/c
PD=$(v_port s6d)        # 18460
PE=$(v_port s6e)        # 18461

v_begin "S6-$SCEN-$DISTRO-$SUBITEM"

if [ "$SUBITEM" = "all" ] || [ "$SUBITEM" = "a" ] || [ "$SUBITEM" = "b" ]; then
    # fresh EMPTY site volumes for the a/b/c fail-fast runs (podman
    # requires the mount SOURCE to exist). T027: (1) the dirs were never
    # created here, so a/b aborted with podman rc 125 (statfs) on any
    # run; (2) a REUSED dir is not safe either - the containers run with
    # a :z label, so after a run the host dir is container-labeled and
    # carries site-owned subdirs (a uid absent on the host: the site IS
    # created before the customization fatal), and host-root rm -rf is
    # then DENIED (SELinux). Suite convention: a FRESH dir per run
    # (mktemp -d). T027 (codex 81 NOTE 3): the fresh dirs are swept at
    # teardown via a root container (best-effort - a probe failure must
    # not mask a real failure; nothing here ever `set -e`-aborts the
    # sub-item).
    d6a=$(mktemp -d "$FIXDIR/s6a.XXXXXX")
    d6b=$(mktemp -d "$FIXDIR/s6b.XXXXXX")
    d6c=$(mktemp -d "$FIXDIR/s6c.XXXXXX")
    # NOTE 2: sweep the per-run site volumes (root-side, best-effort)
    # after every exit path of the sub-item - including v_check failures
    # (v_check does not abort the script) and a v_run/v_wait_ready rc
    # under set -e.
    trap '
      for dv in "$d6a" "$d6b" "$d6c"; do
        [ -n "${dv:-}" ] || continue
        $RUNTIME run --rm -v "$dv:/w:z" "$IMAGE" \
          sh -c "find /w -mindepth 1 -maxdepth 1 -exec rm -rf {} +" >/dev/null 2>&1 || true
      done
    ' EXIT
    # (a) invalid key
    astart=$(date +%s)
    v_run omd-s6a "$IMAGE" "$P" "" -e SITENAME=badcfg -e OMDCFG_NOT_A_KEY=on \
        -v "$d6a:/omd/sites/badcfg:z"
    t=0
    while (( t < 45 )); do
        running=$($RUNTIME inspect -f '{{.State.Running}}' omd-s6a 2>/dev/null || echo false)
        [ "$running" = "false" ] && break; sleep 1; t=$((t + 1))
    done
    acode=$($RUNTIME inspect -f '{{.State.ExitCode}}' omd-s6a 2>/dev/null || echo unknown)
    # NOTE 2: the advertised bound is exit 1 within 30 s - the POLL
    # allows up to 45 s, so the actual elapsed (start->dead, 1 s poll
    # granularity) is asserted <= 30 (the bound holds with margin:
    # EMPIRICAL fail-fast times are 0-4 s).
    aelapsed=$(( $(date +%s) - astart ))
    v_check "(a) invalid key OMDCFG_NOT_A_KEY ? exit 1 <=30 s (code=$acode, elapsed=${aelapsed}s)" \
        'set +e; [ '"$acode"' = 1 ] && [ '"$aelapsed"' -le 30 ]'
    # the entry persists the FATAL reason to /var/log/omd-labs/entry-fatal
    # (the log driver loses fast-exit stderr - EMPIRICAL); v_fatal reads it
    v_check "(a) fatal reason names the key; nothing half-configured left running" \
        'v_fatal omd-s6a NOT_A_KEY'
    v_teardown omd-s6a

    # (b) invalid value
    bstart=$(date +%s)
    v_run omd-s6b "$IMAGE" "$P" "" -e SITENAME=badval -e OMDCFG_MOD_GEARMAN=bogus \
        -v "$d6b:/omd/sites/badval:z"
    t=0
    while (( t < 45 )); do
        running=$($RUNTIME inspect -f '{{.State.Running}}' omd-s6b 2>/dev/null || echo false)
        [ "$running" = "false" ] && break; sleep 1; t=$((t + 1))
    done
    bcode=$($RUNTIME inspect -f '{{.State.ExitCode}}' omd-s6b 2>/dev/null || echo unknown)
    belapsed=$(( $(date +%s) - bstart ))
    v_check "(b) invalid value MOD_GEARMAN=bogus ? exit 1 <=30 s (code=$bcode, elapsed=${belapsed}s)" \
        'set +e; [ '"$bcode"' = 1 ] && [ '"$belapsed"' -le 30 ]'
    # entry-fatal file (deterministic) with log fallback via v_fatal
    v_check "(b) fatal reason names key+value" \
        'v_fatal omd-s6b GEARMAN'
    # (T027 BLOCKER fix, codex 81) the failed first creation must RETAIN
    # its in-progress provenance (marker + identity) - the retry then
    # classifies row 3a RECOVERY (idempotent completion + re-apply of the
    # CORRECTED settings + completion-marker commit), never row 3b ADOPT
    # (which would start the partial site as complete, ignore the
    # corrected input, and commit it as persisted).
    v_check "(b) failed first creation retained its in-progress provenance (root probe)" \
        'v_vol_ls '"$d6b"' .omd-labs-init-inprogress .omd-labs-site-identity'
    # (b) RETRY with corrected input (T027 acceptance: "a retry with
    # corrected input succeeds"): it must RECOVER and the CORRECTED value
    # must actually be stored.
    v_run omd-s6b-re "$IMAGE" "$P" "" -e SITENAME=badval -e OMDCFG_MOD_GEARMAN=on \
        -v "$d6b:/omd/sites/badval:z"
    v_check "(b) retry with corrected input succeeds: site ready (recovered, corrected settings re-applied)" \
        'set +e; rt=$(v_wait_ready omd-s6b-re '"$P"' /badval/); rc=$?; echo "ready-time=${rt}s"; exit $rc'
    # grep -c (NOT -q): -q closes the pipe early -> SIGPIPE to the echo
    # writer is a RACE (EMPIRICAL: rc 141 on debian, pass on rocky)
    v_check "(b) retry log: the recovery banners (re-registered after creation completed)" \
        'set +e; l=$($RUNTIME logs omd-s6b-re 2>/dev/null | head -300); n1=$(echo "$l" | grep -c "recovering interrupted first creation of badval"); n2=$(echo "$l" | grep -c "recovery complete - resumed existing site badval"); [ "$n1" -ge 1 ] && [ "$n2" -ge 1 ]'
    v_check "(b) retry log: the corrected input WAS applied (customization applied: MOD_GEARMAN=on)" \
        'set +e; l=$($RUNTIME logs omd-s6b-re 2>/dev/null | head -300); n=$(echo "$l" | grep -c "customization applied: MOD_GEARMAN=on"); [ "$n" -ge 1 ]'
    # THE assertion the BLOCKER broke (pre-fix the adopt stored off): the
    # CORRECTED value is what is stored (omd show prints the stored value
    # on one clean line - grep -qx is exact).
    v_check "(b) retry stored MOD_GEARMAN = on (the corrected value - not the pre-fail off)" \
        "$RUNTIME exec omd-s6b-re runuser -u badval -- omd config show MOD_GEARMAN | grep -qx on"
    # the retry must NOT have taken the adopt branch (a non-empty capture
    # is required for the negative to be meaningful - N2 convention)
    v_check "(b) retry log carries NO adoption banner (recovery, not adopt - capture non-empty)" \
        'set +e; l=$($RUNTIME logs omd-s6b-re 2>/dev/null | head -300); [ -n "$l" ] || { echo EMPTY-LOG; exit 1; }; n=$(echo "$l" | grep -c "adopted existing site badval"); [ "$n" -eq 0 ]'
    v_teardown omd-s6b-re
    # (teardown the failed b BEFORE the a retry - both use port $P; the
    # retry containers must not fight the failed one over the host port)
    v_teardown omd-s6b
    # (a) RETRY with corrected input (same volume shape - the provenance
    # marker present -> row 3a RECOVERY, NOT adopt). The corrected input
    # is a VALID key/value pair; recovery re-applies it before commit.
    v_check "(a) failed first creation retained its in-progress provenance (root probe)" \
        'v_vol_ls '"$d6a"' .omd-labs-init-inprogress .omd-labs-site-identity'
    v_run omd-s6a-re "$IMAGE" "$P" "" -e SITENAME=badcfg -e OMDCFG_MOD_GEARMAN=on \
        -v "$d6a:/omd/sites/badcfg:z"
    v_check "(a) retry with corrected input succeeds: site ready (recovered, corrected settings re-applied)" \
        'set +e; rt=$(v_wait_ready omd-s6a-re '"$P"' /badcfg/); rc=$?; echo "ready-time=${rt}s"; exit $rc'
    v_check "(a) retry log: recovery banners + the corrected input was applied" \
        'set +e; l=$($RUNTIME logs omd-s6a-re 2>/dev/null | head -300); n1=$(echo "$l" | grep -c "recovering interrupted first creation of badcfg"); n2=$(echo "$l" | grep -c "customization applied: MOD_GEARMAN=on"); [ "$n1" -ge 1 ] && [ "$n2" -ge 1 ]'
    v_check "(a) retry stored MOD_GEARMAN = on (the corrected value)" \
        "$RUNTIME exec omd-s6a-re runuser -u badcfg -- omd config show MOD_GEARMAN | grep -qx on"
    v_check "(a) retry log carries NO adoption banner (recovery, not adopt - capture non-empty)" \
        'set +e; l=$($RUNTIME logs omd-s6a-re 2>/dev/null | head -300); [ -n "$l" ] || { echo EMPTY-LOG; exit 1; }; n=$(echo "$l" | grep -c "adopted existing site badcfg"); [ "$n" -eq 0 ]'
    v_teardown omd-s6a-re
    # (c) multi-setting PARTIAL-APPLICATION failure (codex 81: "with
    # multiple settings, earlier valid settings can have applied before
    # the later failure"). Run 1 applies TWO effective keys: MOD_GEARMAN
    # (valid - an enumerated on/off choice, stored) and GEARMAND=bogus
    # (refused by omd config set at PRE-INIT - enumerated choice, so the
    # apply loop fatals before the completion marker is committed).
    # EMPIRICAL ground truth (both probe runs): the earlier valid key IS
    # stored, the failing one is NOT, and the in-progress + identity
    # provenance is retained (the BLOCKER fix) - so the retry classifies
    # row 3a RECOVERY and re-applies the corrected pair. NOTE: a
    # GEARMAND_PORT=bogus shape would be the WRONG case - that hook
    # stores any [a-zA-Z0-9.-,:]* value, so the failure would only surface
    # at RUNTIME (naemon bind) with a committed-complete volume, and the
    # retry would classify resume (row 2) and not re-apply.
    cstart=$(date +%s)
    v_run omd-s6c "$IMAGE" "$P" "" -e SITENAME=badpart -e OMDCFG_MOD_GEARMAN=on -e OMDCFG_GEARMAND=bogus \
        -v "$d6c:/omd/sites/badpart:z"
    t=0
    while (( t < 45 )); do
        running=$($RUNTIME inspect -f '{{.State.Running}}' omd-s6c 2>/dev/null || echo false)
        [ "$running" = "false" ] && break; sleep 1; t=$((t + 1))
    done
    ccode=$($RUNTIME inspect -f '{{.State.ExitCode}}' omd-s6c 2>/dev/null || echo unknown)
    celapsed=$(( $(date +%s) - cstart ))
    v_check "(c) partial failure: exit 1 <=30 s (code=$ccode, elapsed=${celapsed}s)" \
        'set +e; [ '"$ccode"' = 1 ] && [ '"$celapsed"' -le 30 ]'
    v_check "(c) partial failure: fatal names the failing key" \
        'v_fatal omd-s6c GEARMAND'
    v_check "(c) partial failure retained the in-progress provenance (root probe)" \
        'v_vol_ls '"$d6c"' .omd-labs-init-inprogress .omd-labs-site-identity'
    # the EARLIER valid setting was stored before the later one failed
    # (partial application is real - the retry must not assume nothing
    # happened): stored MOD_GEARMAN = on, and the FAILING one is NOT bogus
    # (root probes of the stored site.conf - the capture must be non-empty)
    v_check "(c) earlier valid setting WAS applied before the later failure (stored MOD_GEARMAN on)" \
        "set +e; out=\$(v_vol_read $d6c etc/omd/site.conf 2>/dev/null | grep -E '^CONFIG_MOD_GEARMAN='); [ -n \"\$out\" ] || { echo EMPTY-CAPTURE; exit 1; }; echo \"\$out\" | grep -qx \"CONFIG_MOD_GEARMAN='on'\""
    v_check "(c) the failing setting was NOT stored (GEARMAND not 'bogus')" \
        "set +e; out=\$(v_vol_read $d6c etc/omd/site.conf 2>/dev/null | grep -E '^CONFIG_GEARMAND='); [ -n \"\$out\" ] || { echo EMPTY-CAPTURE; exit 1; }; echo \"\$out\" | grep -q \"CONFIG_GEARMAND='bogus'\" && exit 1 || exit 0"
    v_teardown omd-s6c
    v_run omd-s6c-re "$IMAGE" "$P" "" -e SITENAME=badpart -e OMDCFG_MOD_GEARMAN=on -e OMDCFG_GEARMAND=on \
        -v "$d6c:/omd/sites/badpart:z"
    v_check "(c) retry with the corrected pair: site ready (recovered)" \
        'set +e; rt=$(v_wait_ready omd-s6c-re '"$P"' /badpart/); rc=$?; echo "ready-time=${rt}s"; exit $rc'
    # both corrected keys in the applied summary (per-key - the topological
    # order between these two keys is not asserted)
    v_check "(c) retry log: recovery + both settings applied" \
        'set +e; l=$($RUNTIME logs omd-s6c-re 2>/dev/null | head -300); n1=$(echo "$l" | grep -c "recovering interrupted first creation of badpart"); n2=$(echo "$l" | grep -c "customization applied:"); n3=$(echo "$l" | grep -c "MOD_GEARMAN=on"); n4=$(echo "$l" | grep -c "GEARMAND=on"); [ "$n1" -ge 1 ] && [ "$n2" -ge 1 ] && [ "$n3" -ge 1 ] && [ "$n4" -ge 1 ]'
    v_check "(c) retry stored MOD_GEARMAN = on" \
        "$RUNTIME exec omd-s6c-re runuser -u badpart -- omd config show MOD_GEARMAN | grep -qx on"
    v_check "(c) retry stored GEARMAND = on (the corrected value)" \
        "$RUNTIME exec omd-s6c-re runuser -u badpart -- omd config show GEARMAND | grep -qx on"
    v_check "(c) retry: the corrected component is up - 4730 listener (capture non-empty first - N2)" \
        "set +e; out=\$($RUNTIME exec omd-s6c-re sh -c 'ss -ltn' 2>/dev/null); [ -n \"\$out\" ] || { echo EMPTY-SS-CAPTURE; exit 1; }; case \$out in *:4730*) exit 0;; esac; exit 1"
    v_check "(c) retry log carries NO adoption banner (recovery, not adopt - capture non-empty)" \
        'set +e; l=$($RUNTIME logs omd-s6c-re 2>/dev/null | head -300); [ -n "$l" ] || { echo EMPTY-LOG; exit 1; }; n=$(echo "$l" | grep -c "adopted existing site badpart"); [ "$n" -eq 0 ]'
    v_teardown omd-s6c-re
fi

if [ "$SUBITEM" = "all" ] || [ "$SUBITEM" = "d" ]; then
    # (d) interrupted-creation recovery matrix (T2b - D6 row 3a)
    # DEBATE 60 F1/F3 REWORK: the fixtures carry the in-progress marker
    # LAST + the recorded identity + REAL (per-site golden) trees for the
    # variants that reach an omd call; the per-variant EXPECTED outcome is
    # encoded below (no blanket "any exit 1 acceptable"); the
    # irreconcilable variant asserts the precise fatal reason + a
    # no-mutation snapshot (content sha256 AND uid/gid/mode/type metadata).
    SITE=intsite
    # no-mutation snapshot of the WHOLE volume (root probe): metadata
    # (uid:gid:mode:filetype:path) of every entry + sha256 of every file,
    # combined into one hash - catches file changes AND ownership/mode
    # changes (the old check labeled "no mutation" enforced neither)
    vol_snap() { # vol_snap <dir> -> single hash
        # DEBATE 61 N3: include the MOUNT ROOT metadata (stat /w - the old
        # -mindepth 1 let a top-dir chown/chmod escape) AND symlink targets
        # (stat %F/%n prints the link path, not the target - a retarget can
        # escape too)
        v_vol_probe "$1" '{ stat -c "%u:%g:%a:%F" /w; find /w -mindepth 1 -exec stat -c "%u:%g:%a:%F:%n" {} + 2>/dev/null; find /w -type l -exec sh -c "for f; do printf \"%s -> %s\n\" \"\$f\" \"\$(readlink \"\$f\")\"; done" _ {} + 2>/dev/null; find /w -type f -exec sha256sum {} + 2>/dev/null; } | sort' \
            | sha256sum | cut -d' ' -f1
    }
    d_expect() { # d_expect <variant> -> ready | fatal
        # design expectations; the ground-truth experiment (verify-first)
        # confirmed/adjusted these per variant - see verify/results.md
        case $1 in
            account-plus-tree|version-link|tree-only|account-only|apache-conf|fstab)
                echo ready ;;
            uid-gid-occupied) echo fatal ;;
            *) echo ready ;;
        esac
    }
    for variant in account-plus-tree version-link tree-only account-only apache-conf fstab; do
        d=$(fx_d6_interrupted "$SITE" "$variant")
        cname="omd-s6d-$variant"
        # precondition (debate 60 F1): the fixture GENUINELY carries the
        # in-progress marker before the run (the old fixtures lost it)
        v_check "(d/$variant) fixture precondition: in-progress marker present pre-run" \
            'v_vol_probe "$d" "test -e /w/.omd-labs-init-inprogress"'
        v_check "(d/$variant) fixture precondition: complete marker absent pre-run" \
            'v_vol_probe "$d" "test ! -e /w/.omd-labs-init-complete"'
        snap_before=$(vol_snap "$d")
        v_run "$cname" "$IMAGE" "$PD" "" -e SITENAME=$SITE $(v_vol "$d" /omd/sites/$SITE z)
        t=0; ready=no
        while (( t < 180 )); do
            running=$($RUNTIME inspect -f '{{.State.Running}}' "$cname" 2>/dev/null || echo false)
            [ "$running" = "false" ] && break
            st=$($RUNTIME exec "$cname" systemctl is-active omd-ready 2>/dev/null || echo unknown)
            [ "$st" = "active" ] && ready=yes && break
            sleep 3; t=$((t + 3))
        done
        code=$($RUNTIME inspect -f '{{.State.ExitCode}}' "$cname" 2>/dev/null || echo running)
        expect=$(d_expect "$variant")
        if [ "$expect" = "ready" ]; then
            v_check "(d/$variant) reconcilable ? recovery completes, site ready (code=$code)" \
                '[ "$ready" = "yes" ]'
            v_check "(d/$variant) omd status rc 0 (site registered + started)" \
                'set +e; '"$RUNTIME"' exec '"$cname"' omd status '"$SITE"''
            v_check "(d/$variant) complete marker written after recovery (root probe)" \
                'v_vol_ls "$d" .omd-labs-init-complete'
            v_check "(d/$variant) in-progress marker removed (root probe)" \
                'v_vol_probe "$d" "test ! -e /w/.omd-labs-init-inprogress"'
        else
            v_check "(d/$variant) irreconcilable ? actionable exit 1 (code=$code)" \
                '[ "$code" = "1" ]'
            v_check "(d/$variant) fatal reason: uid occupied by a different account" \
                'v_fatal "$cname" "occupied by a different account"'
            snap_after=$(vol_snap "$d")
            v_check "(d/$variant) no mutation (content + metadata snapshot identical)" \
                '[ -n "$snap_after" ] && [ "$snap_after" = "$snap_before" ]'
        fi
        v_note "(d/$variant) outcome: expect=$expect ready=$ready code=$code"
        v_teardown "$cname"
    done
    # uid-gid-occupied: irreconcilable BY CONSTRUCTION (debate 60 F3) - the
    # TEST-ONLY sub-image holds a GENUINELY occupying account (uid 1234,
    # group occgrp) and the volume carries the recorded identity
    # 1234/1234 -> the recovery's account step (i) must fatal BEFORE any
    # mutation, naming the occupying account.
    d=$(fx_d6_interrupted "$SITE" uid-gid-occupied)
    DF="$FIXDIR/Dockerfile-s6d-occ"
    {
        echo "FROM $IMAGE"
        echo "RUN groupadd -g 1234 occgrp && useradd -u 1234 -g occgrp -M -s /sbin/nologin occupier"
    } >"$DF"
    $RUNTIME build -f "$DF" -t local/omd-s6d-occ -q . >/dev/null
    snap_before=$(vol_snap "$d")
    cname=omd-s6d-occ
    v_run "$cname" local/omd-s6d-occ "$PD" "" -e SITENAME=$SITE $(v_vol "$d" /omd/sites/$SITE z)
    t=0
    while (( t < 90 )); do
        running=$($RUNTIME inspect -f '{{.State.Running}}' "$cname" 2>/dev/null || echo false)
        [ "$running" = "false" ] && break; sleep 2; t=$((t + 2))
    done
    code=$($RUNTIME inspect -f '{{.State.ExitCode}}' "$cname" 2>/dev/null || echo running)
    v_check "(d/uid-gid-occupied) irreconcilable ? actionable exit 1 (code=$code)" \
        '[ "$code" = "1" ]'
    v_check "(d/uid-gid-occupied) fatal reason names the occupying account" \
        'v_fatal "$cname" "occupied by a different account"'
    snap_after=$(vol_snap "$d")
    v_check "(d/uid-gid-occupied) no mutation (content + metadata snapshot identical)" \
        '[ -n "$snap_after" ] && [ "$snap_after" = "$snap_before" ]'
    v_note "(d/uid-gid-occupied) outcome: expect=fatal ready=n/a code=$code"
    v_teardown "$cname"

    # (d-injected) failure between reconciliation and the marker commit
    # (T2b ordering invariant - T017; DEBATE 60 F1 REWORK): TEST-ONLY
    # sub-build that injects `sentinel touch + exit 1` directly BEFORE the
    # recovery path's single init-complete commit point (the entry comment
    # anchor "re-enters recovery)" is unique). The variant is chosen so the
    # recovery RECONCILIATION succeeds and the injected line is the only
    # failure; the check PROVES the sentinel was reached (cp from the
    # stopped container), so "reached the injected line" is asserted, not
    # assumed.
    d=$(fx_d6_interrupted "$SITE" tree-only)
    DF="$FIXDIR/Dockerfile-s6d-inj"
    {
        echo "FROM $IMAGE"
        echo "RUN sed -i '/re-enters recovery)/a mkdir -p /var/log/omd-labs 2>/dev/null; touch /var/log/omd-labs/.d-inj-sentinel 2>/dev/null; exit 1   # TEST-ONLY injected failure before the recovery init-complete commit' /usr/local/bin/omd-labs-entry"
    } >"$DF"
    $RUNTIME build -f "$DF" -t local/omd-s6d-inj -q . >/dev/null
    cname=omd-s6d-inj
    v_run "$cname" local/omd-s6d-inj "$PD" "" -e SITENAME=$SITE $(v_vol "$d" /omd/sites/$SITE z)
    t=0
    while (( t < 180 )); do
        running=$($RUNTIME inspect -f '{{.State.Running}}' "$cname" 2>/dev/null || echo false)
        [ "$running" = "false" ] && break; sleep 2; t=$((t + 2))
    done
    code=$($RUNTIME inspect -f '{{.State.ExitCode}}' "$cname" 2>/dev/null || echo running)
    v_check "(d-injected) failure at the recovery commit point ? exit 1 (code=$code)" \
        '[ "$code" = "1" ]'
    rm -f "$FIXDIR/d-inj-sentinel"
    v_check "(d-injected) the injected line was REACHED (sentinel present, cp from stopped container)" \
        'set +e; '"$RUNTIME"' cp '"$cname"':/var/log/omd-labs/.d-inj-sentinel '"$FIXDIR"'/d-inj-sentinel && [ -e '"$FIXDIR"'/d-inj-sentinel ]'
    v_check "(d-injected) in-progress marker REMAINS after the failure (root probe)" \
        'v_vol_probe "$d" "test -e /w/.omd-labs-init-inprogress"'
    v_check "(d-injected) complete marker ABSENT (recovery never committed, root probe)" \
        'v_vol_probe "$d" "test ! -e /w/.omd-labs-init-complete"'
    v_teardown "$cname"
    # next boot: the NORMAL image re-enters recovery and completes
    v_run omd-s6d-inj2 "$IMAGE" "$PD" "" -e SITENAME=$SITE $(v_vol "$d" /omd/sites/$SITE z)
    v_check "(d-injected) next boot re-enters recovery, completes ready (root image)" \
        'set +e; rt=$(v_wait_ready omd-s6d-inj2 '"$PD"' /'"$SITE"'/); rc=$?; echo "ready-time=${rt}s"; exit $rc'
    v_check "(d-injected) recovery committed: complete marker + in-progress gone (root probe)" \
        'v_vol_ls "$d" .omd-labs-init-complete && v_vol_probe "$d" "test ! -e /w/.omd-labs-init-inprogress"'
    v_teardown omd-s6d-inj2
fi

if [ "$SUBITEM" = "all" ] || [ "$SUBITEM" = "f" ]; then
    # (f) pre-marker INCOMPLETE tree (D6 row 3c)
    d=$(fx_premarker_incomplete incompsite)
    cname=omd-s6f
    v_run "$cname" "$IMAGE" "$PD" "" -e SITENAME=incompsite $(v_vol "$d" /omd/sites/incompsite z)
    t=0
    while (( t < 60 )); do
        running=$($RUNTIME inspect -f '{{.State.Running}}' "$cname" 2>/dev/null || echo false)
        [ "$running" = "false" ] && break; sleep 1; t=$((t + 1))
    done
    fcode=$($RUNTIME inspect -f '{{.State.ExitCode}}' "$cname" 2>/dev/null || echo unknown)
    v_check "(f) incomplete pre-marker tree ? actionable exit 1, never adopted/started (code=$fcode)" \
        'set +e; [ '"$fcode"' = 1 ]'
    v_check "(f) data untouched (site.conf still absent, tree unmodified - root probe)" \
        'v_vol_probe $d "test ! -e /w/etc/omd/site.conf && test ! -e /w/.omd-labs-init-complete"'
    v_teardown "$cname"
fi

if [ "$SUBITEM" = "all" ] || [ "$SUBITEM" = "g" ]; then
    # (g) identity fixtures (round-2 B2)
    # no-mutation snapshot (content sha256 AND metadata - debate 60 F3)
    g_snap() { # g_snap <dir> -> single hash
        # DEBATE 61 N3: same tightening as vol_snap (root metadata + link
        # targets)
        v_vol_probe "$1" '{ stat -c "%u:%g:%a:%F" /w; find /w -mindepth 1 -exec stat -c "%u:%g:%a:%F:%n" {} + 2>/dev/null; find /w -type l -exec sh -c "for f; do printf \"%s -> %s\n\" \"\$f\" \"\$(readlink \"\$f\")\"; done" _ {} + 2>/dev/null; find /w -type f -exec sha256sum {} + 2>/dev/null; } | sort' \
            | sha256sum | cut -d' ' -f1
    }

    # g1: ambiguous (subfolders group = the image's REAL omd gid) ?
    # refusal (exit 1, actionable reason) + volume UNCHANGED (content AND
    # metadata). The guard fatals before any omd call or mutation, so the
    # minimal fake tree is sufficient here (debate 60 F5).
    d=$(fx_identity_ambiguous ambig)
    snap_before=$(g_snap "$d")
    cname=omd-s6g1
    v_run "$cname" "$IMAGE" "$PD" "" -e SITENAME=ambig $(v_vol "$d" /omd/sites/ambig z)
    t=0
    while (( t < 60 )); do
        running=$($RUNTIME inspect -f '{{.State.Running}}' "$cname" 2>/dev/null || echo false)
        [ "$running" = "false" ] && break; sleep 1; t=$((t + 1))
    done
    g1code=$($RUNTIME inspect -f '{{.State.ExitCode}}' "$cname" 2>/dev/null || echo unknown)
    snap_after=$(g_snap "$d")
    v_check "(g1) ambiguous identity ? actionable exit 1 (code=$g1code)" \
        '[ "$g1code" = "1" ]'
    v_check "(g1) fatal reason names the ambiguity" \
        'v_fatal "$cname" "AMBIGUOUS"'
    v_check "(g1) volume unchanged: content + ownership/mode metadata identical" \
        '[ -n "$snap_after" ] && [ "$snap_after" = "$snap_before" ]'
    v_teardown "$cname"

    # g2: identity file LOST on a completed-volume resume ? inference +
    # re-record. REAL tree (the resume path runs omd enable - the version
    # link must be accurate, debate 60 F4).
    d=$(fx_identity_lost lostid)
    cname=omd-s6g2
    v_run "$cname" "$IMAGE" "$PD" "" -e SITENAME=lostid $(v_vol "$d" /omd/sites/lostid z)
    v_check "(g2) lost identity file ? resume via inference, site starts ready" \
        'set +e; rt=$(v_wait_ready '"$cname"' '"$PD"' /lostid/); rc=$?; echo "ready-time=${rt}s"; exit $rc'
    v_check "(g2) .omd-labs-site-identity RE-RECORDED with the inferred $FIX_UID/$FIX_GID" \
        '"$RUNTIME" cp '"$cname"':/omd/sites/lostid/.omd-labs-site-identity - 2>/dev/null | grep -q "^uid='"$FIX_UID"' gid='"$FIX_GID"'"
    v_teardown "$cname"

    # g3: recorded identity HONORED. REAL tree (same reason as g2).
    # (debate 60 F5: the old check left an UNBALANCED quote in the splice
    # and a pattern that could not match `id`'s output - two plain greps
    # on uid=<N>( and gid=<N>( instead)
    d=$(fx_identity_recorded recid "$FIX_UID" "$FIX_GID")
    cname=omd-s6g3
    v_run "$cname" "$IMAGE" "$PD" "" -e SITENAME=recid $(v_vol "$d" /omd/sites/recid z)
    v_check "(g3) recorded identity honored: site starts ready" \
        'set +e; rt=$(v_wait_ready '"$cname"' '"$PD"' /recid/); rc=$?; echo "ready-time=${rt}s"; exit $rc'
    v_check "(g3) fresh-container account carries uid=$FIX_UID (id recid)" \
        '"$RUNTIME" exec '"$cname"' id recid | grep -qE "uid='"$FIX_UID"'\\("'
    v_check "(g3) fresh-container account carries primary gid=$FIX_GID (id recid)" \
        '"$RUNTIME" exec '"$cname"' id recid | grep -qE "gid='"$FIX_GID"'\\("'
    v_teardown "$cname"

    # g4 (T026 N1, codex 61): uid/gid OCCUPIED by a different account on the
    # resume path (recorded identity) ? ALL validation (uid occupied, then
    # group name) precedes ANY write - the entry's restore_registration
    # writes .omd-labs-site-identity only after validation, so a fail-fast
    # leaves the volume byte-identical. The TEST-ONLY sub-image holds a
    # GENUINELY occupying uid+group (the same pattern as the d-section's
    # uid-gid-occupied sub-image). Ground truth: /tmp/t026-f2.sh F2a.
    d=$(fx_identity_recorded occres "$FIX_UID" "$FIX_GID")
    snap_before=$(g_snap "$d")
    DF="$FIXDIR/Dockerfile-s6g-occ"
    {
        echo "FROM $IMAGE"
        echo "RUN groupadd -g $FIX_GID occgrp && useradd -u $FIX_UID -g occgrp -M -s /sbin/nologin occupier"
    } >"$DF"
    $RUNTIME build -f "$DF" -t local/omd-s6g-occ -q . >/dev/null
    cname=omd-s6g4
    v_run "$cname" local/omd-s6g-occ "$PD" "" -e SITENAME=occres $(v_vol "$d" /omd/sites/occres z)
    t=0
    while (( t < 60 )); do
        running=$($RUNTIME inspect -f '{{.State.Running}}' "$cname" 2>/dev/null || echo false)
        [ "$running" = "false" ] && break; sleep 1; t=$((t + 1))
    done
    g4code=$($RUNTIME inspect -f '{{.State.ExitCode}}' "$cname" 2>/dev/null || echo unknown)
    snap_after=$(g_snap "$d")
    v_check "(g4) occupied uid on resume ? exit 1 (code=$g4code)" \
        '[ "$g4code" = "1" ]'
    v_check "(g4) fatal names the collision (occupied uid / foreign group - F2 validation before any write)" \
        'set +e; v_fatal '"$cname"' "occupied by a different account" || v_fatal '"$cname"' "belongs to group"'
    v_check "(g4) no-mutation: volume byte-identical (identity NOT re-written, no group change - F2 ordering)" \
        '[ -n "$snap_after" ] && [ "$snap_after" = "$snap_before" ]'
    v_teardown "$cname"

    # g5 (T026 N1, codex 61): same occupied-uid/gid collision on the ADOPT
    # path (identity LOST ? inferred from the volume). Ground truth:
    # /tmp/t026-f2.sh F2b. The adopt writes .omd-labs-init-complete AFTER
    # restore_registration - on a fail-fast the marker must be ABSENT.
    d=$(fx_legacy_volume occadp)
    v_vol_probe "$d" "chown -R $FIX_UID:$FIX_GID /w/etc /w/var /w/local" >/dev/null
    snap_before=$(g_snap "$d")
    cname=omd-s6g5
    v_run "$cname" local/omd-s6g-occ "$PD" "" -e SITENAME=occadp $(v_vol "$d" /omd/sites/occadp z)
    t=0
    while (( t < 60 )); do
        running=$($RUNTIME inspect -f '{{.State.Running}}' "$cname" 2>/dev/null || echo false)
        [ "$running" = "false" ] && break; sleep 1; t=$((t + 1))
    done
    g5code=$($RUNTIME inspect -f '{{.State.ExitCode}}' "$cname" 2>/dev/null || echo unknown)
    snap_after=$(g_snap "$d")
    v_check "(g5) occupied uid/gid on adopt ? exit 1 (code=$g5code)" \
        '[ "$g5code" = "1" ]'
    v_check "(g5) fatal names the collision (occupied uid / foreign group - F2 validation before any write)" \
        'set +e; v_fatal '"$cname"' "occupied by a different account" || v_fatal '"$cname"' "belongs to group"'
    v_check "(g5) no-mutation: volume byte-identical (no identity file, no group)" \
        '[ -n "$snap_after" ] && [ "$snap_after" = "$snap_before" ]'
    v_check "(g5) adopt-complete marker ABSENT (adopt wrote nothing before the fatal)" \
        'v_vol_probe "$d" "test ! -e /w/.omd-labs-init-complete"'
    v_teardown "$cname"

    # g6 (T026 N1, codex 61): STALE in-progress marker on a persisted
    # volume (completed + marker present, identity lost) ? clean resume:
    # the stale marker is removed ONLY after validation passed (ground
    # truth: /tmp/t026-f2.sh F3a). The success-case half; the collision
    # half (marker RETAINED on fail-fast) is the g4/g5 pattern with a
    # marker - covered by the matrix, not re-asserted here to keep the
    # suite fast.
    d=$(fx_identity_lost stalemrk)
    v_vol_probe "$d" "touch /w/.omd-labs-init-inprogress" >/dev/null
    v_check "(g6) fixture precondition: stale in-progress marker present on a completed volume (root probe)" \
        'v_vol_probe "$d" "test -e /w/.omd-labs-init-inprogress && test -e /w/.omd-labs-init-complete"'
    cname=omd-s6g6
    v_run "$cname" "$IMAGE" "$PD" "" -e SITENAME=stalemrk $(v_vol "$d" /omd/sites/stalemrk z)
    v_check "(g6) persisted volume with stale marker ? resume ready (inference + re-record)" \
        'set +e; rt=$(v_wait_ready '"$cname"' '"$PD"' /stalemrk/); rc=$?; echo "ready-time=${rt}s"; exit $rc'
    v_check "(g6) stale in-progress marker REMOVED after validation (root probe)" \
        'v_vol_probe "$d" "test ! -e /w/.omd-labs-init-inprogress"'
    v_check "(g6) log carries the deterministic removal notice" \
        'v_wait_log '"$cname"' "stale in-progress marker"'
    v_check "(g6) identity re-recorded (root probe)" \
        'v_vol_probe "$d" "grep -qx \"uid='"$FIX_UID"' gid='"$FIX_GID"'\" /w/.omd-labs-site-identity"'
    v_teardown "$cname"

    # g7 (T026, codex 75 B1): MALFORMED recorded identity (uid=abc) ? the
    # entry must fatal BEFORE any write - the restore path re-writes the
    # identity file, so a no-mutation snapshot is the contract. The
    # malformed value must NOT reach the account tools (useradd -u abc).
    d=$(fx_identity_malformed badid)
    snap_before=$(g_snap "$d")
    cname=omd-s6g7
    v_run "$cname" "$IMAGE" "$PD" "" -e SITENAME=badid $(v_vol "$d" /omd/sites/badid z)
    t=0
    while (( t < 60 )); do
        running=$($RUNTIME inspect -f '{{.State.Running}}' "$cname" 2>/dev/null || echo false)
        [ "$running" = "false" ] && break; sleep 1; t=$((t + 1))
    done
    g7code=$($RUNTIME inspect -f '{{.State.ExitCode}}' "$cname" 2>/dev/null || echo unknown)
    snap_after=$(g_snap "$d")
    v_check "(g7) malformed recorded identity ? exit 1 (code=$g7code)" \
        '[ "$g7code" = "1" ]'
    v_check "(g7) fatal names the malformed identity (no account-tool rejection)" \
        'v_fatal "$cname" "malformed recorded identity"'
    v_check "(g7) no-mutation: volume byte-identical (identity NOT re-written - F2 ordering)" \
        '[ -n "$snap_after" ] && [ "$snap_after" = "$snap_before" ]'
    v_teardown "$cname"

    # g8 (T026, codex 75 N1): the STALE-MARKER COLLISION half - the success
    # half is g6; here the SAME persisted volume (stale in-progress marker
    # + lost identity) meets a FOREIGN group at the inferred gid: the
    # fail-fast must RETAIN the marker (it is removed only after validation)
    # and leave the volume byte-identical. Standalone ground truth: F3b.
    d=$(fx_persisted_stale_marker staled)
    # the inference must yield the FIX identity's gid (home owner uid +
    # subfolder group) - re-own the subfolders to the FIX gid; a FOREIGN
    # group at that gid (the occ sub-image's occgrp at $FIX_GID) must then
    # trigger the group-name fatal, NOT the ambiguity guard (which needs
    # the subfolder group = the OMD gid)
    v_vol_probe "$d" "chown -R $FIX_UID:$FIX_GID /w/etc /w/var /w/local" >/dev/null
    snap_before=$(g_snap "$d")
    cname=omd-s6g8
    v_run "$cname" local/omd-s6g-occ "$PD" "" -e SITENAME=staled $(v_vol "$d" /omd/sites/staled z)
    t=0
    while (( t < 60 )); do
        running=$($RUNTIME inspect -f '{{.State.Running}}' "$cname" 2>/dev/null || echo false)
        [ "$running" = "false" ] && break; sleep 1; t=$((t + 1))
    done
    g8code=$($RUNTIME inspect -f '{{.State.ExitCode}}' "$cname" 2>/dev/null || echo unknown)
    snap_after=$(g_snap "$d")
    v_check "(g8) stale marker + foreign gid ? exit 1 (code=$g8code)" \
        '[ "$g8code" = "1" ]'
    v_check "(g8) fatal names the collision (occupied uid / foreign group)" \
        'set +e; v_fatal '"$cname"' "occupied by a different account" || v_fatal '"$cname"' "belongs to group"'
    v_check "(g8) in-progress marker RETAINED (removed only AFTER validation - no-mutation)" \
        'v_vol_probe "$d" "test -e /w/.omd-labs-init-inprogress"'
    v_check "(g8) no-mutation: volume byte-identical" \
        '[ -n "$snap_after" ] && [ "$snap_after" = "$snap_before" ]'
    v_teardown "$cname"

    # g9 (T026, codex 75 N1): PURE GID-only foreign collision on the resume
    # path - the requested gid is taken by a FOREIGN group NAME while the
    # uid is FREE (no occupying account, no site-named group). The
    # group-name fatal must fire and leave the volume byte-identical.
    # TEST-ONLY sub-image carries the foreign group WITHOUT an occupying
    # user (the g4 occ image would trip the uid-occupied fatal first).
    # Standalone ground truth: /tmp/t026-f2.sh F2a.
    d=$(fx_identity_recorded gonly "$FIX_UID" "$FIX_GID")
    snap_before=$(g_snap "$d")
    DF="$FIXDIR/Dockerfile-s6g-occg"
    {
        echo "FROM $IMAGE"
        echo "RUN groupadd -g $FIX_GID occgrp"
    } >"$DF"
    $RUNTIME build -f "$DF" -t local/omd-s6g-occg -q . >/dev/null
    cname=omd-s6g9
    v_run "$cname" local/omd-s6g-occg "$PD" "" -e SITENAME=gonly $(v_vol "$d" /omd/sites/gonly z)
    t=0
    while (( t < 60 )); do
        running=$($RUNTIME inspect -f '{{.State.Running}}' "$cname" 2>/dev/null || echo false)
        [ "$running" = "false" ] && break; sleep 1; t=$((t + 1))
    done
    g9code=$($RUNTIME inspect -f '{{.State.ExitCode}}' "$cname" 2>/dev/null || echo unknown)
    snap_after=$(g_snap "$d")
    v_check "(g9) GID-only foreign collision on resume ? exit 1 (code=$g9code)" \
        '[ "$g9code" = "1" ]'
    v_check "(g9) fatal names the foreign group (belongs to group 'occgrp')" \
        'v_fatal '"$cname"' "belongs to group"'
    v_check "(g9) no-mutation: volume byte-identical (F2 ordering)" \
        '[ -n "$snap_after" ] && [ "$snap_after" = "$snap_before" ]'
    v_teardown "$cname"

    # g10 (T026, codex 75 N1): INVERSE collision on the resume path - a
    # group NAMED after the site exists at a DIFFERENT gid while the
    # requested gid is FREE. useradd -g would bind to the existing
    # group's gid (silent identity change); the entry must refuse BEFORE
    # any write (the identity re-write happens after validation). TEST-ONLY
    # sub-image: group named g10id at gid 1230 (the site name is g10id -
    # the group name must match it). Standalone ground truth: /tmp/t026-cx.sh
    # C3a.
    d=$(fx_identity_recorded g10id "$FIX_UID" "$FIX_GID")
    snap_before=$(g_snap "$d")
    DF="$FIXDIR/Dockerfile-s6g-invs"
    {
        echo "FROM $IMAGE"
        echo "RUN groupadd -g 1230 g10id"
    } >"$DF"
    $RUNTIME build -f "$DF" -t local/omd-s6g-invs -q . >/dev/null
    cname=omd-s6g10
    v_run "$cname" local/omd-s6g-invs "$PD" "" -e SITENAME=g10id $(v_vol "$d" /omd/sites/g10id z)
    t=0
    while (( t < 60 )); do
        running=$($RUNTIME inspect -f '{{.State.Running}}' "$cname" 2>/dev/null || echo false)
        [ "$running" = "false" ] && break; sleep 1; t=$((t + 1))
    done
    g10code=$($RUNTIME inspect -f '{{.State.ExitCode}}' "$cname" 2>/dev/null || echo unknown)
    snap_after=$(g_snap "$d")
    v_check "(g10) inverse collision (site-named group at wrong gid) ? exit 1 (code=$g10code)" \
        '[ "$g10code" = "1" ]'
    v_check "(g10) fatal names the inverse collision (exists at gid 1230)" \
        'v_fatal '"$cname"' "already exists at gid 1230"'
    v_check "(g10) no-mutation: volume byte-identical (identity NOT re-written - F2 ordering)" \
        '[ -n "$snap_after" ] && [ "$snap_after" = "$snap_before" ]'
    v_check "(g10) the ORIGINAL identity line is intact (not overwritten by the failed restore)" \
        'v_vol_probe '"$d"' "grep -qx \"uid='"$FIX_UID"' gid='"$FIX_GID"'\" /w/.omd-labs-site-identity"'
    v_teardown "$cname"
fi

if [ "$SUBITEM" = "all" ] || [ "$SUBITEM" = "e" ]; then
    # (e) LEGACY VOLUME adoption core (T023, T2c input-free half; the
    # with-inputs half - FR-012 notice + no-apply + no gearmand - = the
    # 'e-inputs' sub-item below, T026/T027). REAL old-image volume:
    # fx_real_legacy_volume builds it
    # with the baseline-red image's own tooling (omd create --reuse + omd
    # reset + set_admin_password with a KNOWN pw + altered CONFIG_ADMIN_MAIL)
    # => complete OMD tree, stored web credential, NO .omd-labs-* markers.
    # DEBATE 64 (carried to the T026 entry window): the entry prints
    # "adoptING existing site" while the contract says "adoptED"
    # (scripts/omd-labs-entry:358) - one-word entry defect, asserted on the
    # name-unique tail until then.
    # DEBATE 64 NOTE: the .meta file is the SINGLE SOURCE OF TRUTH for every
    # assertion below (pw, mail, uid, gid are DERIVED, never hardcoded - a
    # changed override or a retagged baseline invalidates the fixture).
    SITE=mysite
    d=$(fx_real_legacy_volume "$DISTRO" "$SITE")
    # the fixture's identity (container view) - the NEW image's
    # restore_registration must honor exactly this (adopt + lost-identity
    # inference path). DEBATE 64 B1: uid and gid are DISTINCT (2001/2002) -
    # the old 1001/1001 made a wrong-field ownership check pass by coincidence.
    fx_uid=$(sed -n 's/^uid=//p' "$d.meta")
    fx_gid=$(sed -n 's/^gid=//p' "$d.meta")
    fx_pw=$(sed -n 's/^pw=//p' "$d.meta")
    fx_mail=$(sed -n 's/^mail=//p' "$d.meta")
    v_note "(e) real old-image volume: $d (identity uid=$fx_uid gid=$fx_gid; pw/mail from .meta)"
    # DEBATE 64 B1: numeric ownership is compared BEFORE vs AFTER (not
    # against static literals), the GID field where GID matters. /w top =
    # site uid : image omd gid (0750); the persistent subfolders = site uid
    # : site primary gid (0755). The .omd-labs-* marker files added by the
    # adopt are top-level entries and are NOT in this list - the adopt's own
    # artifacts.
    om_omdgid=$(v_vol_probe "$d" "getent group omd | cut -d: -f3")
    om_before=$(v_vol_probe "$d" '{ for p in /w /w/etc /w/var /w/local /w/tmp /w/etc/omd /w/var/lib; do stat -c "%n %u %g %a" "$p" 2>/dev/null; done; }')
    # DEBATE 64 B2: sentinel metadata captured BEFORE (the site user's umask
    # is 002 - assert before/after equality, never a guessed mode)
    sn_before=$(v_vol_probe "$d" '{ for f in /w/etc/omd/sentinel.conf /w/var/lib/sentinel.dat /w/local/sentinel.txt; do stat -c "%n %u %g %a" "$f" 2>/dev/null; done; }')
    # root-side checksums BEFORE (the tree is site-owned, host EACCES)
    ck_conf_before=$(v_vol_probe "$d" "sha256sum /w/etc/omd/site.conf" | cut -d' ' -f1)
    ck_ht_before=$(v_vol_probe "$d" "sha256sum /w/etc/htpasswd" | cut -d' ' -f1)
    v_check "(e) precondition: volume is marker-free (genuinely adoptable, root probe)" \
        'v_vol_probe "$d" "! ls /w/.omd-labs-* 2>/dev/null"'
    v_check "(e) precondition: version link + stored site.conf + htpasswd present (root probe)" \
        'v_vol_probe "$d" "test -L /w/version && test -f /w/etc/omd/site.conf && test -f /w/etc/htpasswd"'
    v_check "(e) precondition: fixture identity uid and gid are DISTINCT (ownership assertions meaningful)" \
        '[ "'"$fx_uid"'" != "'"$fx_gid"'" ]'
    v_check "(e) precondition: sentinels seeded in persistent paths with distinct content (root probe)" \
        'v_vol_probe "$d" "grep -qx \"SENTINEL_T023='"$DISTRO"' config\" /w/etc/omd/sentinel.conf && grep -qx \"SENTINEL_T023='"$DISTRO"' monitoring\" /w/var/lib/sentinel.dat && grep -qx \"SENTINEL_T023='"$DISTRO"' localdata\" /w/local/sentinel.txt"'
    cname=omd-s6e
    v_run "$cname" "$IMAGE" "$PE" "" -e SITENAME=$SITE $(v_vol "$d" /omd/sites/$SITE z)
    v_check "(e) legacy volume adopted - site starts ready (gate + /$SITE/)" \
        'set +e; rt=$(v_wait_ready '"$cname"' '"$PE"' /'"$SITE"'/); rc=$?; echo "ready-time=${rt}s"; exit $rc'
    # DEBATE 64 (T026 fix): the entry now prints the contract banner
    # "adoptED existing site" (was "adoptING" - one-word entry defect)
    v_check "(e) prominent 'adopted existing site mysite (no init marker - legacy/pre-marker volume)' log line" \
        'v_wait_log '"$cname"' "adopted existing site '"$SITE"' (no init marker - legacy/pre-marker volume)"'
    v_check "(e) stored configuration authoritative: omd config show returns the ALTERED stored value" \
        '"$RUNTIME" exec '"$cname"' su - '"$SITE"' -c "omd config show" 2>/dev/null | grep -qx "ADMIN_MAIL: '"$fx_mail"'"'
    v_check "(e) omd status rc 0 (site registered + started, adopt path)" \
        'set +e; '"$RUNTIME"' exec '"$cname"' omd status '"$SITE"''
    ck_conf_after=$(v_vol_probe "$d" "sha256sum /w/etc/omd/site.conf" | cut -d' ' -f1)
    om_after=$(v_vol_probe "$d" '{ for p in /w /w/etc /w/var /w/local /w/tmp /w/etc/omd /w/var/lib; do stat -c "%n %u %g %a" "$p" 2>/dev/null; done; }')
    sn_after=$(v_vol_probe "$d" '{ for f in /w/etc/omd/sentinel.conf /w/var/lib/sentinel.dat /w/local/sentinel.txt; do stat -c "%n %u %g %a" "$f" 2>/dev/null; done; }')
    v_check "(e) stored site.conf UNMODIFIED (sha256 unchanged, root probe)" \
        '[ -n "'"$ck_conf_after"'" ] && [ "'"$ck_conf_after"'" = "'"$ck_conf_before"'" ]'
    v_check "(e) stored web credential FILE unmodified (htpasswd sha256 unchanged, root probe)" \
        '[ "$(v_vol_probe "$d" "sha256sum /w/etc/htpasswd" | cut -d" " -f1)" = "'"$ck_ht_before"'" ]'
    v_check "(e) the stored web credential created before STILL LOGS IN (thruk 200 with stored cred from .meta, 302 anon)" \
        'set +e; wc=$(curl -sk -u omdadmin:'"$fx_pw"' -o /dev/null -w "%{http_code}" --max-time 8 "https://127.0.0.1:'"$PE"'/'"$SITE"'/thruk/"); ac=$(curl -sk -o /dev/null -w "%{http_code}" --max-time 8 "https://127.0.0.1:'"$PE"'/'"$SITE"'/thruk/"); echo "with-cred=$wc anon=$ac"; [ "$wc" = 200 ] && [ "$ac" = 302 ]'
    v_check "(e) init-complete marker now present (leaves the no-marker class, root probe)" \
        'v_vol_ls '"$d"' .omd-labs-init-complete'
    v_check "(e) identity re-recorded with the INFERRED uid/gid from the volume (root probe)" \
        'v_vol_probe "$d" "grep -qx \"uid='"$fx_uid"' gid='"$fx_gid"'\" /w/.omd-labs-site-identity"'
    v_check "(e) numeric ownership UNTOUCHED before/after (UID AND GID of top + persistent subfolders; the adopt's own top-level .omd-labs-* artifacts excluded, root probe)" \
        '[ -n "'"$om_after"'" ] && [ "'"$om_after"'" = "'"$om_before"'" ]'
    v_check "(e) top dir carries the image omd gid (uid=$fx_uid group=omd, 0750) after adoption (root probe)" \
        'v_vol_probe "$d" "test \"\$(stat -c \"%u %g %a\" /w)\" = \"'"$fx_uid"' '"$om_omdgid"' 750\""'
    # DEBATE 64 B2: sentinel/monitoring data preservation - the seeded
    # sentinels must keep their EXACT content AND their uid/gid/mode metadata
    # (the adopt must never touch site data)
    v_check "(e) sentinel content UNTOUCHED (etc/omd, var/lib, local - exact lines, root probe)" \
        'v_vol_probe "$d" "grep -qx \"SENTINEL_T023='"$DISTRO"' config\" /w/etc/omd/sentinel.conf && grep -qx \"SENTINEL_T023='"$DISTRO"' monitoring\" /w/var/lib/sentinel.dat && grep -qx \"SENTINEL_T023='"$DISTRO"' localdata\" /w/local/sentinel.txt"'
    v_check "(e) sentinel metadata UNTOUCHED (uid/gid/mode identical before/after - umask-dependent, no guessed mode, root probe)" \
        '[ -n "'"$sn_after"'" ] && [ "'"$sn_after"'" = "'"$sn_before"'" ]'
    v_teardown "$cname"
fi

# (e-inputs) T2c input half of legacy adoption (T026/T027 - FR-012): a
# marker-free LEGACY volume is adopted with customization INPUTS supplied.
# The inputs are VALID (key + value pass validation) but NOT APPLIED: the
# stored configuration is authoritative. A SECOND independent legacy volume
# (distinct site name - the fixture is keyed per site). Ground truth:
# /tmp/t026-matrix.sh M6 (persisted) - same contract, adopt path.
if [ "$SUBITEM" = "all" ] || [ "$SUBITEM" = "e-inputs" ]; then
    SITE=mysite2
    d=$(fx_real_legacy_volume "$DISTRO" "$SITE")
    fx_pw=$(sed -n 's/^pw=//p' "$d.meta")
    ck_conf_before=$(v_vol_probe "$d" "sha256sum /w/etc/omd/site.conf" | cut -d' ' -f1)
    cname=omd-s6e-in
    v_run "$cname" "$IMAGE" "$PE" "" -e SITENAME=$SITE \
        -e OMDCFG_MOD_GEARMAN=on \
        $(v_vol "$d" /omd/sites/$SITE z)
    v_check "(e-inputs) legacy volume adopted WITH inputs - site starts ready" \
        'set +e; rt=$(v_wait_ready '"$cname"' '"$PE"' /'"$SITE"'/); rc=$?; echo "ready-time=${rt}s"; exit $rc'
    v_check "(e-inputs) 'adopted existing site' banner (contract string)" \
        'v_wait_log '"$cname"' "adopted existing site '"$SITE"' (no init marker - legacy/pre-marker volume)"'
    # FR-012: the deterministic notice, LOWERCASE "not applied" (the
    # contract string the suite asserts case-sensitively)
    v_check "(e-inputs) FR-012 notice logged: inputs supplied but NOT applied (stored config authoritative)" \
        'v_wait_log '"$cname"' "not applied"'
    # input was VALID but NOT APPLIED: the STORED values win
    v_check "(e-inputs) MOD_GEARMAN still the stored value off (input 'on' NOT applied)" \
        '"$RUNTIME" exec '"$cname"' runuser -u '"$SITE"' -- omd config show MOD_GEARMAN 2>/dev/null | grep -qx off'
    v_check "(e-inputs) PNP4NAGIOS still the stored value on (untouched by the adopt)" \
        '"$RUNTIME" exec '"$cname"' runuser -u '"$SITE"' -- omd config show PNP4NAGIOS 2>/dev/null | grep -qx on'
    # no gearmand: MOD_GEARMAN stored off => no 4730 listener even though
    # the (not applied) input was MOD_GEARMAN=on. N2 (codex 75): readiness
    # is asserted above (the v_wait_ready check) and the capture must be
    # NON-EMPTY first - an empty ss output would pass for the wrong reason.
    v_check "(e-inputs) no 4730 listener (stored MOD_GEARMAN off - input not applied; capture non-empty - N2)" \
        'set +e; out=$('"$RUNTIME"' exec '"$cname"' sh -c "ss -ltn" 2>/dev/null); [ -n "$out" ] || { echo "EMPTY ss capture - negative check void" >&2; exit 1; }; case $out in *:4730*) echo "$out" >&2; exit 1;; esac; exit 0'
    ck_conf_after=$(v_vol_probe "$d" "sha256sum /w/etc/omd/site.conf" | cut -d' ' -f1)
    v_check "(e-inputs) stored site.conf UNMODIFIED (sha256 unchanged, root probe)" \
        '[ -n "'"$ck_conf_after"'" ] && [ "'"$ck_conf_after"'" = "'"$ck_conf_before"'" ]'
    v_check "(e-inputs) the stored web credential created before STILL LOGS IN (thruk 200 with stored cred from .meta)" \
        'set +e; wc=$(curl -sk -u omdadmin:'"$fx_pw"' -o /dev/null -w "%{http_code}" --max-time 8 "https://127.0.0.1:'"$PE"'/'"$SITE"'/thruk/"); echo "with-cred=$wc"; [ "$wc" = 200 ]'
    v_check "(e-inputs) init-complete marker written by the adopt (root probe)" \
        'v_vol_probe '"$d"' "test -e /w/.omd-labs-init-complete"'
    v_check "(e-inputs) /run/omd-labs.env carries SITE_CUSTOM_APPLIED=0 (inputs validated, not applied)" \
        '"$RUNTIME" exec '"$cname"' grep -qx "SITE_CUSTOM_APPLIED=\"0\"" /run/omd-labs.env'
    v_teardown "$cname"
fi

v_end
