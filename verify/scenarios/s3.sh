#!/usr/bin/env bash
# S3 - Invalid SITENAME fails fast (US2 sc4; SC-010; FR-007)
# Each invalid name: exit 1 within 30 s, readable error naming the value, nothing left running.
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/common.sh"

P=$(v_port s3)
NAMES=('bad-name!!' '1leadingdigit' 'way_too_long_site_name_here')

v_begin "S3-$SCEN-$DISTRO"

i=0
for name in "${NAMES[@]}"; do
    i=$((i + 1))
    cname="omd-s3-$i"
    start=$(date +%s)
    set +e
    $RUNTIME run --name "$cname" $(v_flags) $(v_suite_label) -d -e SITENAME="$name" "$IMAGE" >/dev/null 2>&1
    set -e
    # bounded wait: the container must EXIT (invalid name fails fast before systemd)
    t=0
    while (( t < 45 )); do
        running=$($RUNTIME inspect -f '{{.State.Running}}' "$cname" 2>/dev/null || echo false)
        [ "$running" = "false" ] && break
        sleep 1; t=$((t + 1))
    done
    elapsed=$(( $(date +%s) - start ))
    code=$($RUNTIME inspect -f '{{.State.ExitCode}}' "$cname" 2>/dev/null || echo unknown)
    v_check "invalid name '$name' exited code 1 within 30 s (elapsed=${elapsed}s code=$code)" \
        'set +e; [ '"$elapsed"' -le 30 ] && [ '"$code"' = 1 ]'
    # bounded wait: the journald log driver flushes the fail-fast container's
    # log non-deterministically (EMPIRICAL) - poll until the value is visible
    # the entry persists the FATAL reason to /var/log/omd-labs/entry-fatal
    # (the log driver loses fast-exit stderr - EMPIRICAL); v_fatal reads it
    # deterministically, log fallback for pre-entry images
    v_check "fatal reason names the invalid value '$name'" \
        'v_fatal $cname '"$name"''
    v_teardown "$cname"
done

# S10c (missing privileges) is asserted here as part of the invocation contract:
# a start WITHOUT --privileged must not hang - bounded non-zero exit, readable error.
cn="omd-s3-nopriv"
start=$(date +%s)
set +e
$RUNTIME run --name "$cn" $(v_suite_label) -d -e SITENAME=make1 "$IMAGE" >/dev/null 2>&1
set -e
t=0
while (( t < 60 )); do
    running=$($RUNTIME inspect -f '{{.State.Running}}' "$cn" 2>/dev/null || echo false)
    [ "$running" = "false" ] && break
    sleep 1; t=$((t + 1))
done
elapsed=$(( $(date +%s) - start ))
code=$($RUNTIME inspect -f '{{.State.ExitCode}}' "$cn" 2>/dev/null || echo unknown)
# (M8, codex 99) require the inspection to have SUCCEEDED and the code to be
# numeric: the old check accepted code=unknown (a failed inspect maps running
# to false) because it only tested != 0 and != 137, so a failed inspection
# passed as a "proven" bounded exit. insok=1 only when the inspect produced
# a real numeric exit code (not the "unknown" fallback).
insok=0
case "$code" in *[!0-9]*) insok=0;; *) insok=1;; esac
v_check "S10c: no-privileges start exited non-zero within bound, no hang (elapsed=${elapsed}s code=$code; inspect observed)" \
    'set +e; [ '"$elapsed"' -le 60 ] && [ '"$insok"' = 1 ] && [ '"$code"' != 0 ] && [ '"$code"' != 137 ]'
# the FATAL line always names the remedy ("Run with --privileged ...");
# bounded wait for the journald flush
v_check "S10c: readable error names the missing prerequisite (privileged/cgroup)" \
    'v_fatal "$cn" privileged'
v_teardown "$cn"

v_note "SITENAME='' / absent behave per S1 (covered by S1/S21 runs)"
v_end
