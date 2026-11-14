#!/usr/bin/env bash
# S10 - Invocation & stop contract (FR-014/FR-020; SC-011; D2)
# (a) documented stop: clean halt well inside 30 s, exit 130/0 (not 137),
#     next start (incl. after stop) needs no manual recovery;
# (b) Make targets on the build host: start / stop / startvol per the
#     contracts/invocation.md "Make targets" v2 table (runtime SITENAME,
#     documented invocation flags, matching mount path); shell/bash/bashvol GONE;
# (c) missing prerequisites: run WITHOUT --privileged => no hang, bounded
#     non-zero exit, readable error naming the missing prerequisite.
# Docker variants of (a)/(c) are the T1 gate (T031).
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/common.sh"
. "$VER_DIR/fixtures.sh"

P=$(v_port s10)                       # 18449
MF=Makefile.omd-labs-$DISTRO
REPO_ROOT=$(cd "$VER_DIR/.." && pwd)
# the make startvol volume lives in FIXDIR (root-side wipe/cleanup: after a
# run the entry chowns the volume top dir to site:omd 0750 and the host
# user gets EACCES - EMPIRICAL 2026-11-10)
MAKE_VOL="$FIXDIR/s10-make-vol"
# defensive: a crashed previous distro's run may have leaked the make
# target's container (same fixed name on both distros)
$RUNTIME stop -t 5 omd-labs-make1 >/dev/null 2>&1 || true
$RUNTIME rm -f omd-labs-make1 >/dev/null 2>&1 || true
v_vol_wipe "$MAKE_VOL" || true
mkdir -p "$MAKE_VOL"

v_begin "S10-$SCEN-$DISTRO"

# --- (a) documented stop ------------------------------------------------------
v_run omd-s10a "$IMAGE" "$P" "" -e SITENAME=site10a
v_check "(a) readiness (gate + /site10a/)" \
    'set +e; rt=$(v_wait_ready omd-s10a '"$P"' /site10a/); rc=$?; echo "ready-time=${rt}s"; exit $rc'

t0=$(date +%s)
v_stop omd-s10a >/dev/null
stop_elapsed=$(( $(date +%s) - t0 ))
code=$(v_exited_code omd-s10a)
v_check "(a) stop -t 30: clean halt in ${stop_elapsed}s (well inside 30), exit $code (130/0, not 137)" \
    'set +e; [ '"$stop_elapsed"' -le 30 ] && case '"$code"' in 130|0) ;; *) exit 1;; esac'

$RUNTIME start omd-s10a
v_check "(a) next start needs no manual recovery (ready again)" \
    'set +e; rt=$(v_wait_ready omd-s10a '"$P"' /site10a/); rc=$?; echo "ready-time=${rt}s"; exit $rc'
v_teardown omd-s10a

# --- (b) Make targets on the build host (documented invocation) ---------------
cd "$REPO_ROOT"
v_note "make targets: $MF (IMAGE=$IMAGE, LOCAL_HTTPS_PORT=$P, runtime SITENAME)"

v_check "(b) make start SITENAME=make1 works end-to-end (documented invocation)" \
    'make -f '"$MF"' start SITENAME=make1 LOCAL_HTTPS_PORT='"$P"' IMAGE='"$IMAGE"' RUNTIME='"$RUNTIME"' >/dev/null'
v_check "(b) make start: container omd-labs-make1 ready (gate + /make1/)" \
    'set +e; rt=$(v_wait_ready omd-labs-make1 '"$P"' /make1/); rc=$?; echo "ready-time=${rt}s"; exit $rc'
v_check "(b) make stop: clean halt (documented -t 30)" \
    'make -f '"$MF"' stop SITENAME=make1 RUNTIME='"$RUNTIME"' >/dev/null'
set +e
mcode=$(v_exited_code omd-labs-make1 2>/dev/null)
set -e
v_check "(b) make stop exit code $mcode (130/0, not 137)" \
    'set +e; case '"$mcode"' in 130|0) ;; *) exit 1;; esac'

# the make targets use a FIXED container name (omd-labs-make1); `make stop`
# stops but does NOT remove it - remove it so the startvol phase (same
# name) can start its own container. NOTE (contract, T031): the documented
# make workflow reuses one name per site - running `make start` twice
# without `podman rm -f omd-labs-make1` collides; the README documents the
# removal step.
$RUNTIME rm -f omd-labs-make1 >/dev/null 2>&1 || true
v_vol_wipe "$MAKE_VOL"
v_check "(b) make startvol VOLUME=$MAKE_VOL SITENAME=make1 (mount path /omd/sites/make1)" \
    'make -f '"$MF"' startvol VOLUME='"$MAKE_VOL"' SITENAME=make1 LOCAL_HTTPS_PORT='"$P"' IMAGE='"$IMAGE"' RUNTIME='"$RUNTIME"' >/dev/null'
v_check "(b) startvol: site make1 ready (gate + /make1/)" \
    'set +e; rt=$(v_wait_ready omd-labs-make1 '"$P"' /make1/); rc=$?; echo "ready-time=${rt}s"; exit $rc'
v_check "(b) startvol: host volume populated (etc/var/local + init-complete marker, root probe)" \
    'v_vol_ls '"$MAKE_VOL"' etc var local .omd-labs-init-complete'
v_check "(b) make stop startvol container: clean" \
    'make -f '"$MF"' stop SITENAME=make1 RUNTIME='"$RUNTIME"' >/dev/null'

# retired targets: `make -n <gone>` prints "No rule to make target" on
# STDERR (EMPIRICAL 2026-11-10: 2>/dev/null yields EMPTY output -> the
# case never matches) and exits 2. Capture with 2>&1 (literal, so the
# redirect survives the v_check eval intact - the OLD 2>\&1 form left an
# unexpanded \& that made the eval redirect stdout to a file named "&1").
for t in shell bash bashvol; do
    v_check "(b) retired target '$t' is gone from $MF" \
        'out=$(make -f '"$MF"' -n '"$t"' 2>&1); case "$out" in *No\ rule\ to\ make\ target*) exit 0;; *) echo "unexpected output: $out"; exit 1;; esac'
done

# --- (c) missing prerequisites (FR-020/SC-011) --------------------------------
c_out=$(mktemp)
cn=omd-s10c
set +e
$RUNTIME run --name "$cn" $(v_suite_label) -d -e SITENAME=make1 "$IMAGE" >"$c_out" 2>&1
run_rc=$?
set -e
if [ "$run_rc" -eq 0 ]; then
    # container started: it must EXIT within the bound (no hang)
    t=0
    while (( t < 60 )); do
        running=$($RUNTIME inspect -f '{{.State.Running}}' "$cn" 2>/dev/null || echo false)
        [ "$running" = "false" ] && break
        sleep 1; t=$((t + 1))
    done
    code=$($RUNTIME inspect -f '{{.State.ExitCode}}' "$cn" 2>/dev/null || echo unknown)
    # (M8, codex 99) require a SUCCESSFUL inspection (numeric exit code): the
    # old check accepted code=unknown (failed inspect maps running to false)
    # because it only tested != 0 and != 137, so a failed inspection passed
    # as a "proven" bounded exit.
    insok=0
    case "$code" in *[!0-9]*) insok=0;; *) insok=1;; esac
    v_check "(c) without --privileged: bounded non-zero exit, no hang (code=$code; inspect observed)" \
        'set +e; [ '"$insok"' = 1 ] && [ '"$code"' != 0 ] && [ '"$code"' != 137 ]'
else
    v_note "(c) the runtime itself refused to start (run rc=$run_rc) - bounded, no hang"
    v_check "(c) runtime refusal recorded (rc=$run_rc)" \
        'set +e; [ '"$run_rc"' -ne 0 ]'
fi
# the FATAL line names the remedy ("Run with --privileged ..."); the
# journald log driver flushes fail-fast containers non-deterministically,
# so poll (bounded) for the content
v_check "(c) readable error names the missing prerequisite (privileged mode / cgroup v2)" \
    'grep -qiE "priv|cgroup|capabilit" "$c_out" 2>/dev/null || v_fatal "$cn" privileged'
v_teardown "$cn"
rm -f "$c_out"
v_vol_wipe "$MAKE_VOL" || true

v_note "docker parity of (a)/(c) = T031 (T1 gate); stop-under-load = T033 (T4 gate)"
v_end
