#!/usr/bin/env bash
# S11a-failfast - Base (OMD-less chassis) + SITENAME => fail-fast (Stage 2,
# 99-consensus B1/B6). The base has no OMD package, so requesting a site must
# FATAL in <5 s (named cause in /var/log/omd-labs/entry-fatal), exit 1, and
# leave NO partial /omd/sites/<name> behind (the check runs before any site
# filesystem mutation). RED mode not applicable (the point is a FAST failure).
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/common.sh"

BASE_IMAGE=$(v_base_image "$DISTRO" "$TAG")
P=$(v_port s11ff)
SSH_P=$((P + 1))

v_begin "S11a-ff-$SCEN-$DISTRO"
v_note "base image: $BASE_IMAGE, starting with SITENAME=demo (must fail fast)"

v_run omd-s11ff "$BASE_IMAGE" "$P" "$SSH_P" -e SITENAME=demo

# bound the wait: the container MUST exit on its own, fast. Poll liveness up
# to 45 s; if it is still running that is itself a FAIL (the fail-fast
# contract is <5 s, but a slow exit is at least not a silent hang-to-deadline
# of the no-site gate).
t0=$SECONDS
while v_running omd-s11ff && (( SECONDS - t0 < 45 )); do sleep 1; done
exited=0
v_running omd-s11ff || exited=1
elapsed=$(( SECONDS - t0 ))

v_check "container exited (fail-fast, not a running site attempt)" \
    '[ '"$exited"' = 1 ] && echo "exited after ${elapsed}s" || { echo "still running after ${elapsed}s"; exit 1; }'

v_check "exit code is 1 (EXIT_FATAL), not the 120 s deadline (2)" \
    'code=$(v_exited_code omd-s11ff); echo "exit=$code"; [ "$code" = "1" ]'

v_check "elapsed < 5 s (fail-fast budget)" \
    '[ '"$elapsed"' -lt 5 ] && echo "elapsed=${elapsed}s" || { echo "elapsed=${elapsed}s (>=5s)"; exit 1; }'

v_check "named cause in /var/log/omd-labs/entry-fatal (OMD not installed)" \
    'v_fatal omd-s11ff "OMD is not installed"'

v_check "NO partial /omd/sites/demo left behind (the pre-fix defect)" \
    'partial=$('"$RUNTIME"' cp omd-s11ff:/omd/sites /tmp/omd-s11ff-sites 2>/dev/null; find /tmp/omd-s11ff-sites -mindepth 1 2>/dev/null | wc -l | tr -d " "); rm -rf /tmp/omd-s11ff-sites; echo "partial entries: $partial"; [ "$partial" = "0" ]'

v_teardown omd-s11ff
v_note "teardown done"
v_end
