#!/usr/bin/env bash
# S4 - Persistence: stop/start cycles + fresh replacement (US3; SC-005/SC-007; FR-009/FR-014)
# Volume-content checks run through the ROOT probe helpers (v_vol_*): after
# the first start the entry chowns the volume top dir to site:omd 0750 and
# the host user gets EACCES - EMPIRICAL 2026-11-10.
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/common.sh"
. "$VER_DIR/fixtures.sh"

P=$(v_port s4)
SITE=s4site
VOLDIR="$FIXDIR/s4-site"
v_vol_wipe "$VOLDIR" || true
mkdir -p "$VOLDIR"

v_begin "S4-$SCEN-$DISTRO"

v_run omd-s4 "$IMAGE" "$P" "" -e SITENAME=$SITE $(v_vol "$VOLDIR" /omd/sites/$SITE z)
v_check "first start reaches ready (gate + /$SITE/)" \
    'set +e; rt=$(v_wait_ready omd-s4 '"$P"' /'"$SITE"'/); rc=$?; echo "ready-time=${rt}s"; exit $rc'

# sentinel AFTER first start initialized the dir (root probe: the host user
# cannot touch the site-chowned volume top dir anymore)
v_vol_write "$VOLDIR" sentinel.txt "sentinel-$(date +%s)"
sent_before=$(v_vol_read "$VOLDIR" sentinel.txt)
own_before=$($RUNTIME exec omd-s4 stat -c '%u %g' /omd/sites/$SITE/etc 2>/dev/null || true)

for n in 1 2 3 4 5; do
    t0=$(date +%s)
    v_stop omd-s4 >/dev/null
    stop_elapsed=$(( $(date +%s) - t0 ))
    code=$(v_exited_code omd-s4)
    v_check "cycle $n: stop -t 30 clean (130/0, not 137) in ${stop_elapsed}s (code=$code)" \
        'set +e; [ '"$stop_elapsed"' -le 30 ] && case '"$code"' in 130|0) ;; *) exit 1;; esac'
    $RUNTIME start omd-s4
    v_check "cycle $n: resumed ready + /$SITE/ 302/200" \
        'set +e; rt=$(v_wait_ready omd-s4 '"$P"' /'"$SITE"'/); rc=$?; echo "ready-time=${rt}s"; exit $rc'
done
# own_after while the container is still running (exec needs a running state)
own_after=$($RUNTIME exec omd-s4 stat -c '%u %g' /omd/sites/$SITE/etc 2>/dev/null || true)

# no orphaned processes / stale locks after a stop.
# A daemon that the ordered shutdown did NOT stop keeps the halt from
# completing -> the container would die at the -t 30 bound (exit 137) or
# exit non-clean; the per-cycle clean-stop assertions (130/0) are the
# guarantee the site daemons were stopped. A stopped container's PID
# namespace is gone, so a post-stop ps is meaningless - the assertion is
# the container having exited fully (Running=false) with the CLEAN code,
# and the stale-locks check below is the real no-orphan signal.
v_stop omd-s4 >/dev/null
v_check "after stop: container exited fully with the CLEAN code (ordered shutdown completed, no fatal; clean 130/0 asserted per cycle)" \
    'set +e; t=0; while (( t < 15 )); do running=$('"$RUNTIME"' inspect -f "{{.State.Running}}" omd-s4 2>/dev/null || echo false); [ "$running" = false ] && break; sleep 1; t=$((t + 1)); done; code=$('"$RUNTIME"' inspect -f "{{.State.ExitCode}}" omd-s4 2>/dev/null); echo "exit-code=${code}"; case "$code" in 130|0) exit 0;; *) echo "non-clean exit after stop (fatal during shutdown?)"; exit 1;; esac'
v_check "no stale locks in /omd/sites/$SITE/tmp/run/ (root probe)" \
    'v_vol_no_locks '"$VOLDIR"' tmp/run'

# data + credentials intact (root probe reads)
sent_after=$(v_vol_read "$VOLDIR" sentinel.txt)
v_check "sentinel data intact after 5 cycles ('$sent_before')" \
    '[ "'"$sent_after"'" = "'"$sent_before"'" ]'
v_check "numeric ownership unchanged (before: '$own_before', after: '$own_after')" \
    '[ -n "'"$own_after"'" ] && [ "'"$own_after"'" = "'"$own_before"'" ]'

# fresh replacement container reusing the volume
v_teardown omd-s4
v_run omd-s4b "$IMAGE" "$P" "" -e SITENAME=$SITE $(v_vol "$VOLDIR" /omd/sites/$SITE z)
v_check "fresh replacement container resumes automatically (SC-005)" \
    'set +e; rt=$(v_wait_ready omd-s4b '"$P"' /'"$SITE"'/); rc=$?; echo "ready-time=${rt}s"; exit $rc'
v_check "replacement: sentinel + config intact (root probe)" \
    '[ -n "'"$sent_after"'" ] && v_vol_read '"$VOLDIR"' sentinel.txt | grep -qx "'"$sent_after"'" && v_vol_read '"$VOLDIR"' etc/omd/site.conf >/dev/null'

v_teardown omd-s4b
v_note "stop-under-load variant = T4 gate (T033)"
v_end
