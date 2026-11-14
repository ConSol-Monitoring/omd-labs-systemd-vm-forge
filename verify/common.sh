#!/usr/bin/env bash
# verify/common.sh - shared layer of the 001-systemd-vm-startup verification suite.
#
# Sourced by verify/run.sh and verify/scenarios/*.sh. Sourcing scripts MUST start with:
#   set -euo pipefail
# before sourcing this file. This library itself sets no shell options.
#
# Conventions (contracts/invocation.md, quickstart.md Prerequisites):
#   - runtime: podman (default) or docker via RUNTIME=docker
#   - invocation: podman --systemd=always --privileged / docker --privileged
#   - stop: <rt> stop -t 30 / <rt> stop --stop-timeout 30
#   - host ports: 18451..18461, one unique port per scenario; scenario runs are
#     NEVER concurrent (the runner is a single sequential process)
#   - readiness polling: bounded by the COMPLETE documented end-to-end bound
#     (360 s - incl. the 150 s unit backstop), NOT the 120 s gate window;
#     success only on verified conditions (omd-ready active AND listeners/UI);
#     a timed-out loop is a FAIL
#   - SELinux-Enforcing hosts: volume mounts carry :z

VER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_FILE="${RESULTS_FILE:-$VER_DIR/results.md}"
RUNTIME="${RUNTIME:-podman}"
# suite concurrency lock (2026-11-13 recorded fix, 002 analyze round B2,
# codex): run.sh (re)creates this file at every start and holds the lock
# for the whole invocation; v_precleanup treats a held lock as "a
# verification run is active" and skips, and a free lock as proof that a
# leaked suite container's owning run is no longer active (stale).
OMD_VERIFY_LOCK="${OMD_VERIFY_LOCK:-/tmp/omd-verify-suite.lock}"
SELABEL=""
if command -v getenforce >/dev/null 2>&1 && [ "$(getenforce 2>/dev/null)" = "Enforcing" ]; then
    SELABEL=":z"
fi

# ---- exit-code contract constants (assert with these everywhere) ------------
readonly EXIT_CLEAN_PRIV=130    # privileged clean halt (CAP_SYS_REBOOT -> reboot())
readonly EXIT_CLEAN_ROOTLESS=0  # rootless / no CAP_SYS_REBOOT clean halt
readonly EXIT_FATAL=1           # fatal pre-ready failure
readonly EXIT_DEADLINE=2        # readiness deadline exceeded
readonly EXIT_KILL=137          # SIGKILL after stop timeout - the only stop-failure outcome

# ---- image / tag resolution (Makefile.common lines 14-16) --------------------
v_tag() {
    local branch
    branch=$(git rev-parse --abbrev-ref HEAD)
    [ "$branch" = "master" ] && echo nightly || echo "$branch"
}

v_image() { # v_image <distro> [tag]
    echo "local/omd-labs-$1:${2:-$(v_tag)}"
}

# ---- port allocation (one unique port per scenario, 18451..18461) ------------
v_port() { # v_port <scenario> [slot]
    local scen=$1 slot=${2:-0} p
    case $scen in
        s1)   p=$((18451 + slot));;    # slot 0 = rocky, slot 1 = debian
        s2)   p=18453;;
        s3)   p=18453;;                 # reused after S2 teardown (sequential)
        s3b)  p=$((18454 + slot));;    # a=18454 (key e2e + ssh 18455), b=18455, c=18456
        s4)   p=18457;;
        s5)   p=18458;;
        s6)   p=18459;;                 # a/b/c + d + f + g + e: sequential sub-items, one container at a time
        s6d)  p=18460;;                 # d sub-item (reuses s8's port - scenarios never run concurrently)
        s6e)  p=18461;;                 # e sub-item (reuses s7's port - scenarios never run concurrently)
        s7)   p=18461;;
        s8)   p=18460;;
        s10)  p=18449;;
        *) return 1;;
    esac
    (( p >= 18449 && p <= 18461 )) || { echo "v_port: $p out of range" >&2; return 1; }
    echo "$p"
}

# ---- container run / stop helpers (documented invocation) ---------------------
v_run() { # v_run <name> <image> <port> [sshhostport] [extra run-args...]
    # The 4th positional is the sshport slot and is ALWAYS shifted when
    # provided - even when empty (EMPIRICAL 2026-11-10: an empty sshport
    # left in "$@" becomes a container CMD arg "" -> crun "cannot find ``").
    # had_sshport must be taken BEFORE the local assignments consume args.
    # EXTRA ARGS (run flags like -e/-v) go BEFORE the image: the image has
    # no ENTRYPOINT, so any arg after it REPLACES the image CMD (EMPIRICAL:
    # crun "executable file `-e' not found").
    local had_sshport=0
    [ "$#" -ge 4 ] && had_sshport=1
    local name=$1 image=$2 port=$3 sshport=${4:-}
    shift 3
    [ "$had_sshport" = 1 ] && shift
    $RUNTIME run --name "$name" $(v_flags) $(v_suite_label) -d -p "${port}:443" ${sshport:+-p ${sshport}:22} "$@" "$image"
}

v_stop() { # v_stop <name> -> prints the stop exit code (0 = clean runtime stop)
    local name=$1 rc
    if [ "$RUNTIME" = "docker" ]; then
        $RUNTIME stop --stop-timeout 30 "$name" >/dev/null
    else
        $RUNTIME stop -t 30 "$name" >/dev/null
    fi
    rc=$?
    echo "$rc"
}

# container exit code (0 for a running container is NOT returned - the call
# fails; scenarios check liveness first via v_running)
v_exited_code() { # v_exited_code <name> -> prints the container's exit code
    $RUNTIME inspect -f '{{.State.ExitCode}}' "$1"
}

v_running() { # v_running <name> -> 0 iff running
    local st
    st=$($RUNTIME inspect -f '{{.State.Running}}' "$1" 2>/dev/null || echo false)
    [ "$st" = "true" ]
}

v_teardown() { # v_teardown <name> [name...] (best-effort)
    local n
    for n in "$@"; do
        $RUNTIME rm -f "$n" >/dev/null 2>&1 || true
    done
}

# runtime-specific privileged flags (documented invocation contract)
v_flags() {
    if [ "$RUNTIME" = "docker" ]; then
        echo "--privileged"
    else
        echo "--systemd=always --privileged"
    fi
}

# v_suite_label - the labels that mark a container as owned by the
# verification suite (2026-11-13 recorded fix, 002 analyze round B2,
# codex): a static marker + the epoch start time. A NAME PREFIX IS NOT
# OWNERSHIP - the runner's pre-cleanup (v_precleanup) only ever touches
# containers carrying the marker label; a user container named e.g.
# omd-sandbox (unlabeled) is never touched.
v_suite_label() {
    echo "--label omd-verify.suite=omd-verify --label omd-verify.suite-start=$(date +%s)"
}

# v_precleanup - remove leaked suite containers. MUST be called while the
# caller holds OMD_VERIFY_LOCK (run.sh does: the BLOCKING lock guarantees
# no other verification run is in progress at this moment, so anything
# still running that the current run did not start is provably a leak of a
# crashed run). The lock's mtime (this run's start) does the rest:
#   - only containers carrying the suite marker label (v_suite_label) are
#     candidates; unlabeled containers (user resources) are NEVER touched;
#   - a candidate is removed only when PROVABLY STALE: the lock was
#     (re)created after the container started, so its owner (another run)
#     is not active any more - the owner crashed;
#   - a candidate started after the lock (or in the SAME second - the tie
#     is resolved to the safe side) belongs to the current run and is
#     LEFT ALONE - the active run's containers are never touched.
v_precleanup() {
    local lock_secs line cid cname lab labstart
    lock_secs=$(stat -c %Y "$OMD_VERIFY_LOCK")
    local ps_out
    ps_out=$($RUNTIME ps --format '{{.ID}}|{{.Names}}|{{.Label "omd-verify.suite"}}|{{.Label "omd-verify.suite-start"}}' 2>/dev/null || true)
    [ -n "$ps_out" ] || return 0
    while IFS= read -r line; do
        IFS='|' read -r cid cname lab labstart <<< "$line"
        [ -n "$cid" ] || continue
        [ "$lab" = "omd-verify" ] || continue    # unlabeled / foreign marker: never touch
        [ -n "$labstart" ] || { echo "pre-cleanup: $cname has the suite marker without a start time - left alone (no staleness proof)"; continue; }
        if [ "$lock_secs" -le "$labstart" ]; then
            continue                             # current run's (active) container
        fi
        echo "pre-cleanup: removing stale suite container $cname (id $cid; start $labstart, run lock $lock_secs - owning run not active)"
        $RUNTIME stop -t 5 "$cid" >/dev/null 2>&1 || true
        $RUNTIME rm -f "$cid" >/dev/null 2>&1 || true
    done <<< "$ps_out"
}

# v_fatal <name> <pattern> - assert the entry's FATAL reason for a fail-fast
# container. The entry persists every fatal reason to
# /var/log/omd-labs/entry-fatal (overlay-backed, written before exit 1) BECAUSE
# the log driver LOST the stderr of containers that exit < 1 s (EMPIRICAL
# 2026-11-10: journald driver - the fail-fast FATAL line was never visible
# through `podman logs` within 25-45 s while the same container's stdout WAS
# visible in 2 s). `podman cp` reads the file from a STOPPED container
# deterministically (no flush race). Fallback: v_wait_log on the container log
# (covers pre-fatal-path runs, e.g. images without the entry).
# rc 0: pattern found (prints the matching line as evidence); rc 1: not found
# after both channels.
v_fatal() { # v_fatal <name> <pattern>
    local name=$1 pat=$2 tmp got=0 i
    # bounded cp retry: right after a fast exit the container may still be in
    # exit cleanup (EMPIRICAL: a single-shot cp failed on the first/fastest
    # exit while the same call succeeded on the next)
    tmp=$(mktemp -d)
    for i in 1 2 3 4 5 6 7 8 9 10; do
        if $RUNTIME cp "$name:/var/log/omd-labs/entry-fatal" "$tmp/entry-fatal" 2>/dev/null \
                && [ -s "$tmp/entry-fatal" ]; then
            got=1
            break
        fi
        sleep 1
    done
    if [ "$got" = 1 ]; then
        local m
        m=$(grep -F -- "$pat" "$tmp/entry-fatal" | head -n 3)
        rm -rf "$tmp"
        if [ -n "$m" ]; then
            printf '%s\n' "$m"
            return 0
        fi
        echo "v_fatal: entry-fatal present but pattern not found: $pat" >&2
        echo "--- file content:" >&2
        cat "$tmp/entry-fatal" >&2 2>/dev/null || true
        rm -rf "$tmp"
        return 1
    fi
    rm -rf "$tmp"
    # no file (e.g. image predates the entry): fall back to the container log
    v_wait_log "$name" "$pat"
}

# bounded wait-for-log-content (the journald log-driver flush race, EMPIRICAL
# 2026-11-10): this host's podman logs via the journald driver; the container
# log of a FAIL-FAST container (exits < 1 s) becomes readable through
# `podman logs` only AFTER the journal flushes - non-deterministically (seen:
# complete at t+5s, or stuck at the first 52 bytes for >15s). A single-shot
# read right after such a start races; this helper polls until the expected
# content is visible (fixed-string match) or the timeout (default 30 s) hits.
# rc 0: pattern visible (prints the matching line as evidence); rc 1: timeout.
v_wait_log() { # v_wait_log <name> <pattern> [timeout]
    local name=$1 pat=$2 timeout=${3:-30} t=0 lg
    while (( t < timeout )); do
        lg=$($RUNTIME logs "$name" 2>/dev/null || true)
        case "$lg" in
            *"$pat"*)
                printf '%s\n' "$lg" | tail -n 8
                return 0;;
        esac
        sleep 1; t=$(( t + 1 ))
    done
    echo "v_wait_log: pattern not visible within ${timeout}s: $pat" >&2
    echo "--- last log lines:" >&2
    $RUNTIME logs "$name" 2>/dev/null | tail -5 >&2 || true
    return 1
}

# host-side ALIVENESS probes - the podman/pasta pitfall (EMPIRICAL 2026-11-10):
# the host-side listener for a forwarded port is the pasta forwarder's socket -
# it ACCEPTS the TCP handshake even when the in-container port is CLOSED, so
# plain TCP probes (nc -z, /dev/tcp) ALWAYS report "open" (open and down are
# indistinguishable). Only application-level probes work:
#   - https: any TLS answer (2xx/3xx/4xx/5xx) = the edge is alive; 000 = down
#   - ssh:   an ssh client's BatchMode auth-refusal = sshd is answering
v_http_alive() { # v_http_alive <port> - rc 0 iff something answers TLS
    # NOTE: no `|| echo 000` fallback - curl PRINTS 000 via -w on a failed
    # connection and then exits non-zero; an appended fallback would make the
    # captured value "000000" (EMPIRICAL) and the != 000 test a false positive
    local c
    c=$(curl -sk -o /dev/null -w '%{http_code}' --max-time 4 "https://127.0.0.1:$1/" 2>/dev/null)
    case "$c" in
        ''|000) return 1;;     # no answer / TLS failure = down (EXACT match -
        *) return 0;;         # a `0*` pattern would match 000 itself)
    esac
}
v_ssh_alive() { # v_ssh_alive <port> - rc 0 iff sshd answers on the port
    local o
    o=$(ssh -o StrictHostKeyChecking=no -o BatchMode=yes -o ConnectTimeout=4 -p "$1" root@127.0.0.1 true 2>&1 || true)
    case "$o" in *"Permission denied"*) return 0;; esac
    return 1
}
# DEPRECATED (never reliable with podman/pasta port forwarding - see above):
v_port_probe() { # v_port_probe <port>
    nc -z -w 3 127.0.0.1 "$1" 2>/dev/null
}

# volume arg for -v (mount label for SELinux-Enforcing hosts)
# NOTE: SELABEL already carries its leading colon (":z"); callers pass the
# bare "z"/"ro"/"z,ro" opts explicitly, the default strips the colon so the
# mount form stays "host:cont:z" (EMPIRICAL: a doubled colon is rejected).
v_vol() { # v_vol <host> <cont> [opts e.g. z / ro / z,ro]
    local host=$1 cont=$2 opts=${3:-${SELABEL#:}}
    [ -n "$opts" ] && echo "-v $host:$cont:$opts" || echo "-v $host:$cont"
}

# ROOT volume probes (EMPIRICAL 2026-11-10): after the first site start the
# entry chowns the volume TOP dir to site:omd mode 0750 - the suite's HOST
# USER (uid 1000, not a member) gets EACCES on any host-side volume
# assertion. ALL volume-content checks must therefore run inside a
# short-lived root probe container (image root = container root; the :z
# label lets the probe read the suite-labeled volume). Host-side host-dir
# management (wipe/cleanup) also goes through this helper because
# site-chowned leftovers cannot be removed by the host user.
# SELABEL already carries the leading colon (":z" or ""); the helpers mount
# with the normalized form so neither a missing nor a doubled colon can
# happen (EMPIRICAL: "host:/w::z" = incorrect volume format).
# v_vol_probe <hostdir> <sh-cmd> -> rc of the sh -c command
v_vol_probe() { # v_vol_probe <host> <cmd>
    local host=$1 cmd=$2 lab=${SELABEL#:}
    $RUNTIME run --rm -v "$host:/w${lab:+:$lab}" "$IMAGE" sh -c "$cmd"
}
# v_vol_ls <hostdir> <relpath...> -> rc 0 iff every relpath exists in the
# volume (top-level entries: the suite mounts <hostdir> at /w)
# NOTE: -e follows symlinks - the site's `version` entry is a RELATIVE
# symlink (../../versions/<v>) that dangles inside the probe container
# (no /omd there), so accept -L (the link itself) as well.
v_vol_ls() { # v_vol_ls <host> <rel...>
    local host=$1; shift
    local f
    for f in "$@"; do
        v_vol_probe "$host" "[ -e /w/$f ] || [ -L /w/$f ] || { echo \"missing: $f\"; exit 1; }" || return 1
    done
    return 0
}
# v_vol_read <hostdir> <relpath> -> prints the file's content (root-side)
v_vol_read() { # v_vol_read <host> <rel>
    local host=$1 rel=$2
    v_vol_probe "$host" "cat /w/$rel"
}
# v_vol_write <hostdir> <relpath> <content> -> writes the file (root-side)
v_vol_write() { # v_vol_write <host> <rel> <content>
    local host=$1 rel=$2 content=$3
    local esc=${content//\'/\'\\\'\'}
    v_vol_probe "$host" "printf '%s' '$esc' > /w/$rel"
}
# v_vol_wipe <hostdir> -> removes ALL content (root-side; site-chowned
# leftovers defeat a host-side rm -rf)
v_vol_wipe() { # v_vol_wipe <host>
    v_vol_probe "$1" "find /w -mindepth 1 -maxdepth 1 -exec rm -rf {} +"
}
# v_vol_no_locks <hostdir> <reldir> -> rc 0 iff no *.lock files under the
# (possibly absent) reldir - root-side, the host user has no access
v_vol_no_locks() { # v_vol_no_locks <host> <rel>
    local host=$1 rel=$2 lab=${SELABEL#:} n
    n=$($RUNTIME run --rm -v "$host:/w${lab:+:$lab}" "$IMAGE" sh -c "find /w/$rel -name '*.lock' 2>/dev/null | wc -l")
    [ "$n" -eq 0 ]
}

# ---- bounded readiness poller (360 s - the COMPLETE bound, not 120 s) ---------
# v_wait_ready <name> <port> [path]
# success (rc 0) only when: container still running AND
#   `systemctl is-active omd-ready` = active AND
#   https://127.0.0.1:<port><path> answers. HTTP semantics per path:
#   - base path "/": ANY non-000 code (the no-site edge answers 403 - the
#     Apache base response without site vhosts; any answer proves the edge
#     is listening and reachable; the gate already asserted the listeners);
#   - site path "/<site>": 2xx/3xx only (the site UI / its login redirect).
# rc 1: the container exited (print its code); rc 2: deadline exceeded.
# prints the ready-time in seconds on success.
v_wait_ready() {
    local name=$1 port=$2 path=${3:-/}
    local deadline=${READY_DEADLINE:-360} t0=$SECONDS st code
    while (( SECONDS - t0 < deadline )); do
        if ! v_running "$name"; then
            echo "READY-FATAL: container exited (code $(v_exited_code "$name"))" >&2
            return 1
        fi
        st=$($RUNTIME exec "$name" systemctl is-active omd-ready 2>/dev/null || echo unknown)
        if [ "$st" = "active" ]; then
            # no `|| echo 000` fallback: curl prints 000 itself on failure
            # (see v_http_alive's note) - the captured value is exactly
            # 000 (down) or a real code (alive)
            code=$(curl -sk -o /dev/null -w '%{http_code}' --max-time 5 "https://127.0.0.1:${port}${path}" 2>/dev/null)
            case "$code" in
                ''|0*) sleep 1; continue;;   # no answer / no answer yet - keep polling
            esac
            # base path "/": any real answer (403 = the Apache base response
            # without site vhosts); site path "/<site>": 2xx/3xx only
            if [ "$path" = "/" ]; then
                echo $((SECONDS - t0)); return 0
            fi
            case $code in
                2*|3*)
                    echo $((SECONDS - t0))
                    return 0
                    ;;
            esac
        fi
        sleep 1
    done
    echo "READY-DEADLINE: not ready within ${deadline}s" >&2
    return 2
}

# ---- result recording (each scenario writes its own uniquely named section) ---
# v_begin <section>  - open a section; v_check appends; v_end flushes to results.md
v_begin() {
    SECTION="${1}-$(date +%Y%m%dT%H%M%S)-$$"
    SECTION_TMP=$(mktemp)
    RESULT_OK=1
    {
        echo "## $1"
        echo "- when: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "- runtime: $RUNTIME"
        echo ""
    } >>"$RESULTS_FILE"
}

v_check() { # v_check <description> <command>
    # the command is evaluated in the CALLING shell (scenario script), so all
    # vars from common.sh / run.sh exports are visible ($RUNTIME, $EDGE_UNIT, ...)
    local desc=$1; shift
    local out rc=0
    out=$(eval "$1" 2>&1) || rc=$?
    if (( rc == 0 )); then
        echo "- PASS: $desc" >>"$SECTION_TMP"
        [ -n "$out" ] && printf '```\n%s\n```\n\n' "$out" >>"$SECTION_TMP" || true
    else
        echo "- FAIL: $desc (rc=$rc)" >>"$SECTION_TMP"
        printf '```\n%s\n```\n\n' "$out" >>"$SECTION_TMP"
        RESULT_OK=0
    fi
}

v_note() { # v_note <line>  - free-form evidence line
    echo "- $1" >>"$SECTION_TMP"
}

v_end() { # v_end -> overall section result (rc 0 = PASS, 1 = FAIL)
    {
        if (( RESULT_OK )); then
            echo "- **RESULT: PASS**"
        else
            echo "- **RESULT: FAIL**"
        fi
        echo ""
    } >>"$RESULTS_FILE"
    cat "$SECTION_TMP" >>"$RESULTS_FILE"
    cat "$SECTION_TMP"
    rm -f "$SECTION_TMP"
    (( RESULT_OK )) && return 0 || return 1
}
