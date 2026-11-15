#!/usr/bin/env bash
# S11a - Base (OMD-less chassis) no-site boot (Stage 2, 99-consensus B6).
# The base image boots WITHOUT OMD: systemd-as-PID1, the ready gate, the edge
# + sshd + cron owned by the chassis, and both labs.consol.de repos configured.
# Asserts the no-OMD chassis contract: readiness, unit states, the EXACT
# no-site edge code, `omd` ABSENT, `ss` present (the named-cause anti-trap for
# the silent 120 s deadline), the omd.service alias, and BOTH channels. Clean
# stop. RED mode (RED=1): a shorter gate bound for fast red baselines.
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/common.sh"
[ -n "${RED:-}" ] && export READY_DEADLINE=90

BASE_IMAGE=$(v_base_image "$DISTRO" "$TAG")
P=$(v_port s11a)
SSH_P=$((P + 1))
E=$EDGE_UNIT
# exact no-site edge code per distro (rocky: self-signed 443 vhost, no index
# doc -> 403; debian: snakeoil default-ssl -> 200, mirroring the OMD image)
case "$DISTRO" in rocky) EXPECT=403;; debian) EXPECT=200;; *) EXPECT=000;; esac

v_begin "S11a-$SCEN-$DISTRO"
v_note "base image: $BASE_IMAGE (edge unit $E, expect no-site HTTP $EXPECT)"

v_run omd-s11a "$BASE_IMAGE" "$P" "$SSH_P"

v_check "base readiness within bound (gate active + 443 answers)" \
    '(set +e; rt=$(v_wait_ready omd-s11a '"$P"' "/"); rc=$?; echo "ready-time=${rt}s rc=$rc"; exit $rc)'

v_check "omd-ready + $E + $SSH_UNIT all active" \
    'r=$('"$RUNTIME"' exec omd-s11a systemctl is-active omd-ready) || exit 1; e=$('"$RUNTIME"' exec omd-s11a systemctl is-active '"$E"') || exit 1; s=$('"$RUNTIME"' exec omd-s11a systemctl is-active '"$SSH_UNIT"') || exit 1; echo "ready=$r edge=$e ssh=$s"; [ "$r" = active ] && [ "$e" = active ] && [ "$s" = active ]'

v_check "edge answers the EXACT no-site code ($EXPECT) on 443" \
    '_c=$(curl -sk -o /dev/null -w "%{http_code}" --max-time 5 "https://127.0.0.1:'"$P"'/"); echo "code=$_c"; [ "$_c" = '"$EXPECT"' ]'

v_check "ss (the ready-gate probe tool) is PRESENT - a named cause, not a silent 120 s deadline" \
    '"$RUNTIME" exec omd-s11a sh -c "command -v ss >/dev/null || { echo ss-missing; exit 1; }" && echo "ss at: $("$RUNTIME" exec omd-s11a sh -c "command -v ss")"'

v_check "the omd binary is ABSENT (OMD-less chassis)" \
    '"$RUNTIME" exec omd-s11a sh -c "test ! -x /usr/bin/omd" && echo "omd absent (ok)"'

v_check "sshd reachable from host on $SSH_P" \
    'v_ssh_alive "$SSH_P"'

v_check "omd.service resolves to the omd-site alias" \
    '_a=$('"$RUNTIME"' exec omd-s11a sh -c "readlink -f /etc/systemd/system/omd.service 2>/dev/null || echo none"); echo "alias -> $_a"; case "$_a" in */omd-site.service) ;; *) exit 1;; esac'

v_check "both labs.consol.de channels configured (stable + testing)" \
    'if [ "$DISTRO" = rocky ]; then '"$RUNTIME"' exec omd-s11a sh -c "dnf -q repolist --enabled | grep -q labs_consol_stable && dnf -q repolist --enabled | grep -q labs_consol_testing"; else '"$RUNTIME"' exec omd-s11a sh -c "test -f /etc/apt/sources.list.d/labs-consol-stable.list && test -f /etc/apt/sources.list.d/labs-consol-testing.list"; fi'

# clean stop contract (contrast verify/baseline.md)
rc=$(v_stop omd-s11a)
code=$(v_exited_code omd-s11a)
v_check "clean stop -t 30 ends 130/0, not 137 (exit code: $code, stop rc: $rc)" \
    'case '"$code"' in 130|0) ;; *) exit 1;; esac'

v_teardown omd-s11a
v_note "teardown done"
v_end
