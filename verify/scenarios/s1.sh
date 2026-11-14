#!/usr/bin/env bash
# S1 - No-site base boot + readiness baseline (US1, US4; SC-001/SC-003/SC-004; FR-006)
# quickstart.md S1, encoded verbatim in assertions. RED mode (RED=1): bounded
# polling so pre-change images record a fast red baseline (T004).
#
# NOTE on assertion style: `set -e` inside v_check's eval string is NOT
# reliable (bash disables errexit in conditional contexts, so a failing
# command mid-sequence can be masked) - every check below uses explicit
# `|| exit 1` / explicit success codes instead.
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/common.sh"
[ -n "${RED:-}" ] && export READY_DEADLINE=45

P=$(v_port s1 $SLOT)
SSH_P=$((P + 1))
E=$EDGE_UNIT   # distro edge unit (httpd / apache2)

v_begin "S1-$SCEN-$DISTRO"

v_run omd-s1 "$IMAGE" "$P" "$SSH_P"
v_note "container: omd-s1 (https $P, ssh $SSH_P, edge unit $E)"

v_check "readiness within bound (gate active + 443 answers)" \
    '(set +e; rt=$(v_wait_ready omd-s1 '"$P"' "/"); rc=$?; echo "ready-time=${rt}s rc=$rc"; exit $rc)'

v_check "no OMD site exists (SC-003: /omd/sites empty)" \
    'cnt=$('"$RUNTIME"' exec omd-s1 sh -c "ls -A /omd/sites/ 2>/dev/null | wc -l") || exit 1; [ "$cnt" = 0 ] || { echo "sites: $cnt"; exit 1; }'

v_check "omd-ready + $E + sshd all active" \
    'r=$('"$RUNTIME"' exec omd-s1 systemctl is-active omd-ready) || exit 1; e=$('"$RUNTIME"' exec omd-s1 systemctl is-active '"$E"') || exit 1; s=$('"$RUNTIME"' exec omd-s1 systemctl is-active '"$SSH_UNIT"') || exit 1; echo "ready=$r edge=$e ssh=$s"; [ "$r" = active ] && [ "$e" = active ] && [ "$s" = active ]'

v_check "listeners on 443 + 80 + 22 (in-container; FR-002: edge on 443 AND 80)" \
    '"$RUNTIME" exec omd-s1 sh -c "ss -ltn | grep -qE \":443 \" && ss -ltn | grep -qE \":80 \" && ss -ltn | grep -qE \":22 \""'

v_check "sshd reachable from host on $SSH_P" \
    'v_ssh_alive "$SSH_P"'

v_check "informational banner in container log (FR-015: no site)" \
    '_lg=$('"$RUNTIME"' logs omd-s1 2>/dev/null); case "$_lg" in *"no site - base services only"*) ;; *) exit 1;; esac'

v_check "stop $E -> 443 down -> start -> back (SC-006)" \
    '"$RUNTIME" exec omd-s1 systemctl stop "$E" || exit 1; d=0; while [ $d -lt 15 ] && v_http_alive "$P"; do sleep 1; d=$((d+1)); done; v_http_alive "$P" && { echo "443 still open after stop (15s wait)"; exit 1; }; "$RUNTIME" exec omd-s1 systemctl start "$E" || exit 1; s=0; while [ $s -lt 30 ] && ! v_http_alive "$P"; do sleep 1; s=$((s+1)); done; v_http_alive "$P"'

v_check "stop sshd -> 22 down -> start -> back (SC-006)" \
    '"$RUNTIME" exec omd-s1 systemctl stop "$SSH_UNIT" || exit 1; d=0; while [ $d -lt 15 ] && v_ssh_alive "$SSH_P"; do sleep 1; d=$((d+1)); done; v_ssh_alive "$SSH_P" && { echo "22 still open after stop (15s wait)"; exit 1; }; "$RUNTIME" exec omd-s1 systemctl start "$SSH_UNIT" || exit 1; s=0; while [ $s -lt 30 ] && ! v_ssh_alive "$SSH_P"; do sleep 1; s=$((s+1)); done; v_ssh_alive "$SSH_P"'

v_check "journalctl -u $E returns logs (FR-016)" \
    '_lg=$('"$RUNTIME"' exec omd-s1 journalctl -u '"$E"' --no-pager -o short-iso 2>&1); case "$_lg" in [0-9][0-9][0-9][0-9]-*) ;; *) exit 1;; esac'

v_check "container log shows startup sequence (FR-015)" \
    '_lg=$('"$RUNTIME"' logs omd-s1 2>/dev/null); case "$_lg" in *Started*|*started*|*omd*|*systemd*) ;; *) exit 1;; esac'

v_note "ready-time recorded above; median-of-5 formal baseline = T034 (FR-018)"

# clean stop contract (contrast verify/baseline.md)
rc=$(v_stop omd-s1)
code=$(v_exited_code omd-s1)
v_check "clean stop -t 30 ends 130/0, not 137 (exit code: $code, stop rc: $rc)" \
    'case '"$code"' in 130|0) ;; *) exit 1;; esac'

v_teardown omd-s1
v_note "teardown done"
v_end
