#!/usr/bin/env bash
# S7 - Fatal paths, post-ready behavior, and the bounded-exit batteries
# (injected hangs B2, full pipe B4) (FR-019; SC-006/SC-010)
# Injection variants (c-g) need test-only image builds (entry/probe variants) -
# implemented as sub-builds here (small Dockerfiles FROM the image under test).
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/common.sh"

. "$VER_DIR/fixtures.sh"
P=$(v_port s7)          # 18461 shared across sub-items (sequential)

v_begin "S7-$SCEN-$DISTRO"

# (a) not-writable mount
d=$(fx_not_writable_dir rwfail)
# codex 85 NOTE: the start time is captured BEFORE v_run (the wall
# semantics every other timed check in the suite uses)
astart=$(date +%s)
v_run omd-s7a "$IMAGE" "$P" "" -e SITENAME=rwfail -v "$d:/omd/sites/rwfail:ro,z"
t=0
while (( t < 45 )); do
    running=$($RUNTIME inspect -f '{{.State.Running}}' omd-s7a 2>/dev/null || echo false)
    [ "$running" = "false" ] && break; sleep 1; t=$((t + 1))
done
aelapsed=$(( $(date +%s) - astart ))
acode=$($RUNTIME inspect -f '{{.State.ExitCode}}' omd-s7a 2>/dev/null || echo unknown)
v_check "(a) not-writable mount ? exit 1 <=30 s (elapsed=${aelapsed}s code=$acode)" \
    'set +e; [ '"$aelapsed"' -le 30 ] && [ '"$acode"' = 1 ]'
    # the entry persists the FATAL reason to /var/log/omd-labs/entry-fatal
    # (deterministic; the log driver loses fast-exit stderr - EMPIRICAL)
v_check "(a) fatal reason names the non-writable location (entry-fatal file)" \
    'v_fatal omd-s7a writ'
v_check "(a) data untouched (marker/creation never attempted - root probe)" \
    'v_vol_probe $d "test ! -e /w/.omd-labs-init-inprogress"'
v_teardown omd-s7a

# (b) post-ready service crash - container STAYS UP (FR-019 second half)
v_run omd-s7b "$IMAGE" "$P" ""
v_check "(b) readiness (gate + 443)" \
    'set +e; rt=$(v_wait_ready omd-s7b '"$P"' /); rc=$?; echo "ready-time=${rt}s"; exit $rc'
$RUNTIME exec omd-s7b systemctl stop $EDGE_UNIT
sleep 2
v_check "(b) after systemctl stop $EDGE_UNIT: container still running (never exits)" \
    'v_running omd-s7b'
v_check "(b) $EDGE_UNIT inactive; status + journalctl explain" \
    "$RUNTIME exec omd-s7b sh -c 'systemctl is-active '"$EDGE_UNIT"' | grep -q inactive && journalctl -u '"$EDGE_UNIT"' --no-pager | grep -q .'"
$RUNTIME exec omd-s7b systemctl start $EDGE_UNIT
sleep 2
v_check "(b) systemctl start $EDGE_UNIT restores 443" \
    'curl -sk -o /dev/null --max-time 5 https://127.0.0.1:'"$P"'/'
v_teardown omd-s7b

# --- injection sub-builds (c-g): test-only image variants FROM the image under test
# (never pushed; local tags omd-s7-<case>) ---
injection_build() { # injection_build <tag> <dockerfile-body-append>
    # T028: the df assignment MUST be on its own line - a `local` statement
    # expands every word BEFORE any local takes effect, so a df that
    # references $tag in the SAME statement is unbound under set -u
    # (latent: the s7 sub-item had never executed before T028 - aborted
    # with "tag: unbound variable").
    local tag=$1 body=$2
    local df="$FIXDIR/Dockerfile-$tag"
    {
        echo "FROM $IMAGE"
        echo "$body"
    } >"$df"
    # T028 (codex 85 rework): the build context is $FIXDIR so the ADD-based
    # injections (c/e/g - plain heredoc scripts, zero escape layering) can
    # reference their fixture files by basename. The earlier RUN-only
    # bodies are context-independent (no COPY/ADD), so this change is
    # safe for them.
    $RUNTIME build -f "$df" -t "local/omd-s7-$tag" "$FIXDIR" >/dev/null
}

# (c) pre-ready site-start failure (injected): omd-site forced to fail
# codex 85 MAJOR-c: the old wrapper was `echo "exit 1"` - NO SHEBANG, so it
# could fail with an EXEC error instead of the intended script exit, and
# started NO daemons (so the cleanup check had nothing to clean). The old
# "no daemons left" check also passed VACUOUSLY: `exec ps` on a STOPPED
# container always errors (rc!=0 mapped to pass). Rework: the wrapper is a
# REAL script that runs the site's REAL startup, verifies the daemon is
# actually running, then exit 1. The cleanup is proven DURABLY (root
# volume probes after the container stopped): the probe's bounded
# `omd stop` leaves the "80-naemon stop" lines in the site's omd.log and
# leaves NO naemon pid file. (Ground truth, probe C: both artifacts
# present.)
# The wrapper is a PLAIN HEREDOC fixture written to $FIXDIR and ADDed into
# the image: zero escape layering (the RUN printf approach was proven
# dash-broken - EMPIRICAL: `printf: %?: invalid directive` on ${SITE#?}
# in the debian build). The build itself verifies the baked file (bash -n).
# The SITE extraction is quote-free parameter expansion: the env line is
# SITE_NAME="name" (write_env format), cut -c11- returns "name", the
# ${SITE#?}/${SITE%?} strip the surrounding quotes.
# codex 87 MAJOR (validated EMPIRICALLY): a marker written BEFORE the
# launch proves nothing about the daemon - on a FRESH site the direct
# `naemon -ud` launch aborts instantly (no naemon.cfg yet: "Cannot open
# main configuration file"), and the omd.log stop lines + missing pid file
# were produced by the cleanup REGARDLESS of whether a daemon ever ran
# (empirical t028c-dx probe: naemon aborted, no pid file ever appeared,
# yet the stop lines were present). Rework: the wrapper runs the REAL
# production start path (`omd start <site>` - what the real
# omd-site-start does: creates the site config and starts the daemons),
# then BOUNDARILY verifies the daemon ACTUALLY RAN - the site's OWN pid
# file (EMPIRICAL path: tmp/run/naemon.pid) must name a LIVE process
# (kill -0) whose executable is the naemon binary and whose user is the
# site - and only then writes a durable SUCCESS marker carrying that
# evidence (probe-naemon-evidence). If the daemon never comes up, the
# marker is ABSENT and the harness precondition (the marker assertion)
# FAILS - an absent daemon cannot pass (c).
cat >"$FIXDIR/site-start-partial.sh" <<'WEOF'
#!/usr/bin/env bash
# TEST-ONLY s7(c) partial start: the site's REAL startup path (omd start -
# the production path that creates the site config and starts the
# daemons), a BOUNDED verification that a daemon is ACTUALLY RUNNING, then
# failure.
set -u
SITE=$(grep ^SITE_NAME= /run/omd-labs.env 2>/dev/null | cut -c11-)
SITE=${SITE#?}
SITE=${SITE%?}
[ -n "$SITE" ] || exit 0
mkdir -p /omd/sites/$SITE/tmp
echo probe-partial-start > /omd/sites/$SITE/tmp/probe-partial-start
# the REAL site start (the production omd-site-start execs exactly this):
/usr/bin/omd start "$SITE" >/dev/null 2>&1
# BOUNDED proof that a daemon ACTUALLY STARTED (codex 87): the site's OWN
# naemon pid file must appear and name a LIVE process whose executable is
# the naemon binary and whose user is the site. Only then is the durable
# SUCCESS marker written - it carries the launch evidence.
EV=/omd/sites/$SITE/tmp/probe-naemon-evidence
i=0
while [ $i -lt 30 ]; do
    if [ -f /omd/sites/$SITE/tmp/run/naemon.pid ]; then
        NP=$(cat /omd/sites/$SITE/tmp/run/naemon.pid 2>/dev/null || true)
        if [ -n "$NP" ] && kill -0 "$NP" 2>/dev/null; then
            EXE=$(readlink /proc/$NP/exe 2>/dev/null || true)
            case "$EXE" in *naemon)
                USR=$(ps -o user= -p "$NP" 2>/dev/null | tr -d ' ')
                { echo "PID=$NP"; echo "EXE=$EXE"; echo "USER=$USR"; echo "VERIFIED=$(date +%s)"; } > "$EV"
                exit 1
                ;;
            esac
        fi
    fi
    i=$(( i + 1 )); sleep 1
done
echo "probe: naemon FAILED to start (pid file / live process never verified)" >&2
exit 1
WEOF
d7c=$(mktemp -d "$FIXDIR/s7c.XXXXXX")
injection_build sitefail 'ADD site-start-partial.sh /usr/local/bin/omd-site-start
RUN chmod 755 /usr/local/bin/omd-site-start && bash -n /usr/local/bin/omd-site-start'
cstart=$(date +%s)
v_run omd-s7c local/omd-s7-sitefail "$P" "" -e SITENAME=sitefail -v "$d7c:/omd/sites/sitefail:z"
t=0
while (( t < 240 )); do
    running=$($RUNTIME inspect -f '{{.State.Running}}' omd-s7c 2>/dev/null || echo false)
    [ "$running" = "false" ] && break; sleep 2; t=$((t + 2))
done
ccode=$($RUNTIME inspect -f '{{.State.ExitCode}}' omd-s7c 2>/dev/null || echo unknown)
celapsed=$(( $(date +%s) - cstart ))
v_check "(c) pre-ready site-start failure ? container exit 1 (code=$ccode, elapsed=${celapsed}s)" \
    'set +e; [ '"$ccode"' = 1 ]'
# not an instant death: a REAL (partial) start - fresh-site init + omd
# start + the bounded verification + the fatal - takes real wall time
# (empirical ~7-8 s; the old instant `echo "exit 1"` death was ~3 s). The
# 90 s unit timeout is the hard inner bound; the marker assertion below is
# the real gate (an instant death leaves NO marker and fails that check).
v_check "(c) the failure is a REAL partial start, not an instant death (wall 5-240 s, elapsed=${celapsed}s)" \
    'set +e; [ '"$celapsed"' -ge 5 ] && [ '"$celapsed"' -le 240 ] || { echo "wall ${celapsed}s out of bounds"; exit 1; }'
# the expected start-failure reason (the exact FATAL-BLOCK marker, NOT
# any FATAL substring - codex 85)
v_check "(c) FATAL-BLOCK marker in the stopped container's log (bounded wait)" \
    'v_wait_log omd-s7c "FATAL-BLOCK-BEGIN (omd-ready rc=1"'
# the DURABLE success marker: the wrapper wrote it ONLY after it had
# verified a live naemon via the site's OWN pid file (kill -0 on the pid
# from tmp/run/naemon.pid + /proc/<pid>/exe = the naemon binary + user =
# the site). It carries the launch evidence (PID / EXE / USER lines). Its
# absence means the daemon never started -> the check FAILS (codex 87
# MAJOR: the pre-launch marker proved nothing about the daemon).
v_check "(c) the real daemon was RUNNING before the failure (volume: durable verified-startup marker with PID/EXE/USER evidence)" \
    'v_vol_probe '"$d7c"' "test -s /w/tmp/probe-naemon-evidence && grep -q \"^PID=[0-9][0-9]*$\" /w/tmp/probe-naemon-evidence && grep -q \"^EXE=.*naemon$\" /w/tmp/probe-naemon-evidence && grep -q \"^USER=sitefail$\" /w/tmp/probe-naemon-evidence && cat /w/tmp/probe-naemon-evidence"'
v_check "(c) bounded cleanup ran: the site omd.log records the naemon stop (durable root probe)" \
    'v_vol_probe '"$d7c"' "grep -q \"80-naemon stop\" /w/var/log/omd.log"'
v_check "(c) bounded cleanup ran: no naemon pid file left (durable root probe)" \
    'v_vol_probe '"$d7c"' "[ -z \"\$(find /w/tmp -name \"*.pid\" -path \"*naemon*\" 2>/dev/null)\" ]"'
# NOTE 3 convention (codex 81): sweep the per-run volume at teardown
$RUNTIME run --rm -v "$d7c:/w:z" "$IMAGE" \
  sh -c "find /w -mindepth 1 -maxdepth 1 -exec rm -rf {} +" >/dev/null 2>&1 || true
v_teardown omd-s7c

# (d) ready-gate deadline (injected never-active dependency)
# codex 85 MAJOR-d: the old injection REPLACED the whole probe with
# `sleep 130; exit 2` - it tested exit-code propagation ONLY (it would pass
# if the real probe never checked its deadline). Rework: the REAL probe
# runs; the never-ready condition is a MASKED distro edge unit (the probe
# sees it as permanently transient/inactive, 443 never comes up, and no
# unit is `failed` - so only the deadline path can fire). Assert the
# probe's OWN deadline reason (the exact fatal condition string), not a
# synthetic exit. (T028 latent note: the old body's `echo -e` was also
# dash-broken on debian - see (c)/(g) for the printf convention; the (d)
# injection needs no script at all - a mask symlink is build-time text.)
injection_build deadlined 'RUN case $(grep -m1 "^ID=" /etc/os-release | cut -d= -f2) in debian) ln -sf /dev/null /etc/systemd/system/apache2.service;; *) ln -sf /dev/null /etc/systemd/system/httpd.service;; esac'
dstart=$(date +%s)
v_run omd-s7d local/omd-s7-deadlined "$P" ""
t=0
while (( t < 240 )); do
    running=$($RUNTIME inspect -f '{{.State.Running}}' omd-s7d 2>/dev/null || echo false)
    [ "$running" = "false" ] && break; sleep 3; t=$((t + 3))
done
dcode=$($RUNTIME inspect -f '{{.State.ExitCode}}' omd-s7d 2>/dev/null || echo unknown)
delapsed=$(( $(date +%s) - dstart ))
# code=2 is the probe's deadline code (the real probe reached it); the
# >=125 proves the full 120 s gate window elapsed (boot offset + window,
# not an early fail); the <=145 proves the probe's OWN deadline fired
# BEFORE the unit's 150 s backstop. If the mask had NOT taken effect the
# probe would succeed (no site - base services) and the container would
# keep running, failing the code/timing asserts.
v_check "(d) ready-gate deadline (REAL probe, masked edge) ? exit 2 within the 150 s backstop (code=$dcode, elapsed=${delapsed}s)" \
    'set +e; [ '"$dcode"' = 2 ] && [ '"$delapsed"' -ge 125 ] && [ '"$delapsed"' -le 145 ]'
# the probe's OWN deadline reason (its exact fatal condition string -
# proof the real probe ran its deadline path)
v_check "(d) the real probe's deadline reason (log: readiness deadline exceeded)" \
    'v_wait_log omd-s7d "readiness deadline exceeded"'
v_teardown omd-s7d

# (e) forwarder dead at fatal time
# codex 85 MAJOR-e rework (the old check passed VACUOUSLY - the old kill
# raced the fast fatal and the "DIRECT-COPY line in journal" check exited
# 0 by construction when it found nothing; the line was 0x in BOTH green
# runs): the probe's stdout goes to the JOURNAL (the unit has no
# StandardOutput= - default), never to podman logs; the journal is
# VOLATILE (EMPIRICAL: /run/log/journal gone after a stop;
# /var/log/journal unreadable post-stop) - so the observation channel is a
# TEST-ONLY tee shim around the REAL probe (runs /usr/local/bin/
# omd-ready-check.real, tees its full output to a durable file, propagates
# the probe's exit via PIPESTATUS - the contract under test is preserved;
# the spec's "in the journal" is satisfied - the line IS logged to the
# journal, the tap is only the observation channel after the volatile
# journal is gone). Precondition sync (codex: "best-effort production
# diagnostics do not excuse failing to arrange the test precondition"):
# the fatal is DELAYED (wrapper sleep 45; omd-site stays activating so
# the probe polls), the forwarder is killed at t=8, and its death is
# PROVEN (bounded kill -0 poll) at t=10-30 - well BEFORE the fatal at
# t=45+. The degraded line for a dead forwarder is the probe's own
# "DIRECT-COPY: status=4 (forwarder dead - pipe copy skipped)" (the
# documented status=4, probe :175-176). The fatal-reason file is
# HARD-asserted (no file-write failure is injected in this case - codex:
# do not convert retrieval failure into a passing note).
# Plain heredoc fixtures (zero escape layering - the RUN printf approach
# was proven dash-broken; the ADD bodies are context-independent text).
cat >"$FIXDIR/site-start-delayed-fatal.sh" <<'WEOF'
#!/usr/bin/env bash
# TEST-ONLY s7(e): delayed fatal - keep omd-site ACTIVATING (the probe
# polls) so the test can prove the forwarder's death BEFORE the fatal.
sleep 45
exit 1
WEOF
cat >"$FIXDIR/probe-tee-shim.sh" <<'WEOF'
#!/usr/bin/env bash
# TEST-ONLY s7(e/g): run the REAL probe, tap its output to a durable
# file (the journal is the probe's real stdout sink - volatile post-stop,
# EMPIRICAL - so the tap is the observation channel only), and propagate
# the probe's exit code via PIPESTATUS (the contract under test).
# NOTE: the tap lives in /var/log/omd-labs (OVERLAY - survives stop)
# because /tmp is a systemd tmpfs (EMPIRICAL: cleared on stop, so a
# /tmp tap is unreadable after the fatal). The dir does not exist yet
# when the probe STARTS (the probe creates it only at fatal time - so
# the mkdir must be here, or tee loses the entire pre-fatal stream).
mkdir -p /var/log/omd-labs
t0=$(date +%s)
/usr/local/bin/omd-ready-check.real 2>&1 | tee -a /var/log/omd-labs/probe-out.tap
rc=${PIPESTATUS[0]}
date +%s >> /var/log/omd-labs/probe-out.tap
echo "PROBE-RC=$rc" >> /var/log/omd-labs/probe-out.tap
exit "$rc"
WEOF
injection_build fwddead 'RUN mv /usr/local/bin/omd-ready-check /usr/local/bin/omd-ready-check.real
ADD site-start-delayed-fatal.sh /usr/local/bin/omd-site-start
ADD probe-tee-shim.sh /usr/local/bin/omd-ready-check
RUN chmod 755 /usr/local/bin/omd-site-start /usr/local/bin/omd-ready-check && bash -n /usr/local/bin/omd-ready-check && bash -n /usr/local/bin/omd-site-start'
v_run omd-s7e local/omd-s7-fwddead "$P" "" -e SITENAME=fwddead
# kill the forwarder at t=8 (long before the delayed fatal at t=45+)
( sleep 8; $RUNTIME exec omd-s7e sh -c 'kill $(cat /run/fwd.pid) 2>/dev/null' || true ) &
FWDPID=$!
wait "$FWDPID" 2>/dev/null || true
# PROVE the forwarder is dead BEFORE the fatal fires (bounded kill -0 poll)
v_check "(e) precondition: the forwarder IS dead (kill -0 fails, proved before the fatal)" \
    'set +e; fwd=$($RUNTIME exec omd-s7e cat /run/fwd.pid 2>/dev/null); [ -n "$fwd" ] || { echo NO-FWD-PID; exit 1; }; i=0; while (( i < 30 )); do $RUNTIME exec omd-s7e sh -c "kill -0 $fwd" 2>/dev/null && { sleep 1; i=$((i+1)); continue; }; exit 0; done; echo "forwarder still alive after 30s"; exit 1'
t=0
while (( t < 120 )); do
    running=$($RUNTIME inspect -f '{{.State.Running}}' omd-s7e 2>/dev/null || echo false)
    [ "$running" = "false" ] && break; sleep 3; t=$((t + 3))
done
ecode=$($RUNTIME inspect -f '{{.State.ExitCode}}' omd-s7e 2>/dev/null || echo unknown)
v_check "(e) forwarder dead at fatal time ? exit still 1 (code=$ecode)" \
    'set +e; [ '"$ecode"' = 1 ]'
# the documented degradation line, observed through the durable tap of the
# REAL probe's output (status=4 = the dead-forwarder path of the probe's
# own direct_copy) - the line is logged to the journal (the spec's
# "in the journal"); the journal is volatile post-stop (verified), so the
# tap is the observation channel
v_check "(e) the REAL probe logged the dead-forwarder degradation line (DIRECT-COPY: status=4)" \
    'set +e; tmp=$(mktemp -d); for i in 1 2 3 4 5 6 7 8; do $RUNTIME cp omd-s7e:/var/log/omd-labs/probe-out.tap "$tmp/o" 2>/dev/null && [ -s "$tmp/o" ] && break; sleep 1; done; grep -q "DIRECT-COPY: status=4" "$tmp/o" || { echo "no status=4 line:"; tail -5 "$tmp/o" 2>/dev/null; rm -rf "$tmp"; exit 1; }; grep "DIRECT-COPY: status=4" "$tmp/o" | head -1; rm -rf "$tmp"'
# the guaranteed artifact: the writable-layer fatal-reason file (HARD -
# no write failure is injected in this case; codex 85: retrieval failure
# is a test failure, not a note)
v_check "(e) the writable-layer fatal-reason file carries the reason (guaranteed artifact)" \
    'set +e; tmp=$(mktemp -d); $RUNTIME cp omd-s7e:/var/log/omd-labs/fatal-reason "$tmp/r" 2>/dev/null && grep -q "READY-FATAL" "$tmp/r" && head -1 "$tmp/r"; rc=$?; rm -rf "$tmp"; exit $rc'
v_teardown omd-s7e

# (f) injected-hang battery (B2/N2)
# T028 (latent - the s7 sub-item had never executed): the old f1/f1b
# injections used `sed "1a exec sleep 9999"` - the EXEC made the sleep
# PID 1 (replacing the entry), so the container NEVER ran the bootstrap
# and NEVER exited (code=0 - still alive when asserted). The faithful
# injection is a run_bounded CHILD inserted directly before the entry's
# `exec /sbin/init` (the anchor exists exactly once): the child's cap is
# the REMAINING bootstrap budget, so the whole bootstrap still exits 1
# <=120 s from container start (N2) with a bounded FATAL pre-init.
# Verified empirically before codifying (rocky): exit 1 at wall=122 s,
# entry-fatal "FATAL: step failed (rc=124)".
injection_build hangpreinit 'RUN sed -i "/^exec \/sbin\/init$/i run_bounded 9999 \"TEST-ONLY injected hang (s7 f1)\" sleep 9999" /usr/local/bin/omd-labs-entry'
f1start=$(date +%s)
v_run omd-s7f1 local/omd-s7-hangpreinit "$P" "" -e SITENAME=hangpre
t=0
while (( t < 200 )); do
    running=$($RUNTIME inspect -f '{{.State.Running}}' omd-s7f1 2>/dev/null || echo false)
    [ "$running" = "false" ] && break; sleep 2; t=$((t + 2))
done
f1code=$($RUNTIME inspect -f '{{.State.ExitCode}}' omd-s7f1 2>/dev/null || echo unknown)
f1elapsed=$(( $(date +%s) - f1start ))
# wall from before v_run: the entry's 120 s budget runs from its T0 epoch
# (a few seconds after container start) - 130 is the honest wall bound
# (EMPIRICAL smoke: wall=122 s).
v_check "(f1) hung pre-init child ? bounded exit 1 <=130 s wall (the 120 s bootstrap bound, entry epoch) (code=$f1code, elapsed=${f1elapsed}s)" \
    'set +e; [ '"$f1code"' = 1 ] && [ '"$f1elapsed"' -le 130 ]'
v_check "(f1) the pre-init budget FATAL is recorded (the bounded child was killed, rc=124/137)" \
    'v_fatal omd-s7f1 "step failed (rc=1"'
# T028: the old check ran `journalctl` via exec - which FAILS on a stopped
# container, so the non-empty error text made it pass VACUOUSLY (always 0).
# The real proof that the entry died BEFORE /sbin/init: the container log
# carries NO systemd journal lines (systemd's own lines DO appear in
# podman logs when systemd ran - EMPIRICAL, t27c1 log).
v_check "(f1) no systemd ever ran (log carries no systemd[1] lines - died before /sbin/init)" \
    'set +e; l=$($RUNTIME logs omd-s7f1 2>/dev/null | head -400); [ -n "$l" ] || { echo "no container log captured - cannot prove absence (guard: a missing log is not a pass)"; exit 1; }; n=$(echo "$l" | grep -c "systemd\[1\]"); [ "$n" -eq 0 ]'
v_teardown omd-s7f1

# f1b: LATE-INVOCATION remaining budget (N2). codex 85 MAJOR: the old
# injection (one run_bounded child doing `sleep 100; exec sleep 9999`)
# computed its cap at t~0 (remaining ~115 s) - the sleep 100 ran INSIDE
# the cap, so it never exercised the late-invocation path. The faithful
# case is TWO steps injected before the `exec /sbin/init` anchor: a
# budget-consumer step that burns (remaining - 12 s) of the 120 s budget
# (it succeeds), then a hanging child whose run_bounded call happens when
# ~12 s remain and whose cap is the REMAINING budget (~12 s).
# The consumer's sleep is ADAPTIVE (`sleep $(( $(rem_budget) - 12 ))`):
# the real bootstrap consumes a VARYING share of the budget (empirical:
# ~10 s rocky, ~77 s debian), so a FIXED `sleep 100` completes on rocky
# (leaving ~10-17 s for the hang child) but is CAPPED-AND-KILLED on debian
# (only ~43 s left -> the consumer itself fatals, the hang child never
# runs, and the last "bounded:" line is the consumer's ~43 s - the t028e
# debian FAIL). The adaptive burn = (remaining - 12 s) leaves EXACTLY
# ~12 s for the hang child on BOTH distros, so the hang child's cap is
# deterministically ~12 s (the proof: the entry logs the computed cap
# "step: ... (bounded: Ns)"; the LAST such line is the hang child's and
# N<=25 s, not the ~115-120 s an early call would log). The whole
# bootstrap still exits 1 bounded (wall ~122 s, window 100-135 s - NOT
# the t~190 s a per-child-only cap would allow).
injection_build hanglate 'RUN sed -i "/^exec \/sbin\/init$/i run_bounded 9999 \"TEST-ONLY s7 f1b budget consumer\" sleep \$(( \$(rem_budget) - 12 ))" /usr/local/bin/omd-labs-entry && sed -i "/^exec \/sbin\/init$/i run_bounded 9999 \"TEST-ONLY injected hang (s7 f1b)\" sleep 9999" /usr/local/bin/omd-labs-entry'
f1bstart=$(date +%s)
v_run omd-s7f1b local/omd-s7-hanglate "$P" "" -e SITENAME=hanglate
t=0
while (( t < 240 )); do
    running=$($RUNTIME inspect -f '{{.State.Running}}' omd-s7f1b 2>/dev/null || echo false)
    [ "$running" = "false" ] && break; sleep 2; t=$((t + 2))
done
f1bcode=$($RUNTIME inspect -f '{{.State.ExitCode}}' omd-s7f1b 2>/dev/null || echo unknown)
f1belapsed=$(( $(date +%s) - f1bstart ))
# wall from before v_run: the >=100 proves the 100 s budget-consumer step
# actually ran (an early EXEC failure ~3 s would fail it); <=135 proves the
# whole bootstrap was bounded by the budget (100 s consumer + ~15-20 s
# remaining cap + a few s bootstrap; the entry's T0 epoch is a few s after
# container start).
v_check "(f1b) late-invocation remaining budget ? whole bootstrap still exit 1, 100s<=wall<=135s (N2 - not t~190 s) (code=$f1bcode, elapsed=${f1belapsed}s)" \
    'set +e; [ '"$f1bcode"' = 1 ] && [ '"$f1belapsed"' -ge 100 ] && [ '"$f1belapsed"' -le 135 ]'
# the PROOF that the late child's cap is the REMAINING budget: the entry
# logs the cap it computed for each step ("step: <desc> (bounded: Ns)");
# the LAST such line is the late child's and N must be small (<=25 s -
# the adaptive consumer leaves ~12 s; empirical smoke: consumer bounded
# 118 s, hang child bounded 12 s, wall 122 s on debian). An
# early call (or a per-child cap) would log ~115-120 s and FAIL this.
v_check "(f1b) the run_bounded cap logged for the late child is the REMAINING budget (bounded: Ns, N<=25)" \
    'set +e; l=$($RUNTIME logs omd-s7f1b 2>/dev/null | head -400); [ -n "$l" ] || { echo "no container log captured - cannot prove the cap"; exit 1; }; b=$(echo "$l" | grep -oE "bounded: [0-9]+s" | tail -1 | grep -oE "[0-9]+"); [ -n "$b" ] || { echo "no bounded-cap line in log:"; echo "$l" | grep -iE "step|bounded" | head -5; exit 1; }; [ "$b" -le 25 ] || { echo "cap $b s is NOT the remaining budget (expected ~12 s)"; exit 1; }; echo "logged cap: $b s"'
v_check "(f1b) the pre-init budget FATAL is recorded (the remaining-budget cap fired)" \
    'v_fatal omd-s7f1b "step failed (rc=1"'
v_teardown omd-s7f1b

# f2: stuck dependency job - omd-site forced 'activating' (hangs past its
# TimeoutStartSec=90s). (T028 latent: the old `echo -e` body was dash-broken
# on debian - see (d) above; printf fix.)
injection_build depstuck 'RUN printf "#!/bin/bash\nsleep 9999\n" > /usr/local/bin/omd-site-start && chmod 755 /usr/local/bin/omd-site-start'
f2start=$(date +%s)
v_run omd-s7f2 local/omd-s7-depstuck "$P" "" -e SITENAME=depstuck
t=0
while (( t < 300 )); do
    running=$($RUNTIME inspect -f '{{.State.Running}}' omd-s7f2 2>/dev/null || echo false)
    [ "$running" = "false" ] && break; sleep 3; t=$((t + 3))
done
f2code=$($RUNTIME inspect -f '{{.State.ExitCode}}' omd-s7f2 2>/dev/null || echo unknown)
f2elapsed=$(( $(date +%s) - f2start ))
# the job must fail AT its TimeoutStartSec (90s) - the >=90 wall bound
# proves the real timeout path (not an early EXEC failure: the dash-broken
# 203 death was ~3 s); EMPIRICAL rocky wall death on the real path is
# 91-94 s (the 90 s job timeout runs from job start, slightly after
# container start). The After=-only gate then still runs and exits 1 (no
# indefinite wait) - the <=135 proves the whole container exited after
# the timeout (90 s job + gate run + stop sequence).
v_check "(f2) stuck dependency job ? fails at TimeoutStartSec, After=-only gate still runs ? exit 1 (code=$f2code, elapsed=${f2elapsed}s)" \
    'set +e; [ '"$f2code"' = 1 ] && [ '"$f2elapsed"' -ge 90 ] && [ '"$f2elapsed"' -le 135 ]'
# the gate's FATAL names the failed dependency unit (the probe inspects the
# per-unit states - the After=-only path: a failed omd-site unblocks the
# gate, which then reports it) - from the stopped container's log (bounded
# wait, same evidence channel as (c)).
v_check "(f2) the After=-only gate ran and failed on the stuck unit (log: omd-site.service failed)" \
    'v_wait_log omd-s7f2 "omd-site.service failed"'
# codex 85 NOTE: the DETERMINISTIC evidence that the failure was the
# TimeoutStartSec path (not an early death) - systemd's own line
# "omd-site.service: start operation timed out. Terminating." (EMPIRICAL
# one-shot: job-start + exactly 90 s; appears in podman logs via the
# forwarder's journal replay - /tmp/t28-f2-oneshot.log).
v_check "(f2) systemd evidence: omd-site timed out (start operation timed out)" \
    'v_wait_log omd-s7f2 "omd-site.service: start operation timed out" 60'
v_teardown omd-s7f2

# f3: hung probe - the probe's OWN 120 s window never fires (the probe IS
# the hang), so the unit's TimeoutStartSec=150s backstop kills it (unit
# failed) and FailureAction=exit fires (B2). (T028 latent: the old
# `echo -e` body was dash-broken on debian - the unit died EXEC (203) in
# 3 s and the old loose assertion [ != 0 ] && [ t<=260 ] PASSED it
# vacuously; the >=150 lower bound now makes the real backstop path
# mandatory. printf fix, see (d).)
injection_build probehang 'RUN printf "#!/bin/bash\nsleep 9999\n" > /usr/local/bin/omd-ready-check && chmod 755 /usr/local/bin/omd-ready-check'
f3start=$(date +%s)
v_run omd-s7f3 local/omd-s7-probehang "$P" ""
t=0
while (( t < 300 )); do
    running=$($RUNTIME inspect -f '{{.State.Running}}' omd-s7f3 2>/dev/null || echo false)
    [ "$running" = "false" ] && break; sleep 3; t=$((t + 3))
done
f3code=$($RUNTIME inspect -f '{{.State.ExitCode}}' omd-s7f3 2>/dev/null || echo unknown)
f3elapsed=$(( $(date +%s) - f3start ))
# the >=140 proves the kill happened AT the unit backstop (not earlier -
# the dash-broken 203 EXEC death was ~3 s); EMPIRICAL rocky wall death on
# the real path is 144-147 s (the 150 s job timeout runs from job start,
# so the wall-from-container-start can be slightly below 150 s); the
# <=210 proves it fired without a second backstop. code=255 is the
# EMPIRICAL systemd exit for a killed oneshot with FailureAction=exit
# (rocky ground truth; a distro divergence is a parity defect - T032).
v_check "(f3) hung probe ? killed at the 150 s backstop, FailureAction=exit ? exit 255 (code=$f3code, elapsed=${f3elapsed}s)" \
    'set +e; [ '"$f3code"' = 255 ] && [ '"$f3elapsed"' -ge 140 ] && [ '"$f3elapsed"' -le 210 ]'
# codex 85 NOTE: the DETERMINISTIC evidence that the kill was the unit
# backstop (not an earlier death) - systemd's own line
# "omd-ready.service: start operation timed out. Terminating." (EMPIRICAL
# one-shot: job-start + exactly 150 s; podman logs via the forwarder's
# journal replay - /tmp/t28-f3-oneshot.log).
v_check "(f3) systemd evidence: omd-ready killed at the 150 s backstop (start operation timed out)" \
    'v_wait_log omd-s7f3 "omd-ready.service: start operation timed out" 90'
v_teardown omd-s7f3

# (g) FULL-PIPE + baseline (B4) - the direct_copy write path, REAL probe
# codex 85 BLOCKER: the old test's fill loop wrote to /dev/null and killed
# the forwarder, so the pipe was NEVER filled or blocked - it exercised the
# dead-forwarder path (status=4, covered by (e)), NOT the write path at all.
# Rework - the REAL probe's direct_copy (omd-ready-check :171-211) opens
# /proc/<fwd>/fd/1 O_WRONLY|O_NONBLOCK and writes. The forwarder's fd 1 is
# what direct_copy targets, so:
#   g0 (baseline):  the REAL forwarder (fd 1 = the container log pipe,
#     continuously drained by the runtime) -> the reason line is sent ->
#     DIRECT-COPY: status=0 (reason=sent). The happy path against the REAL
#     probe (proves the tap/shim does not distort the real contract).
#   g1 (fullpipe):  a test-only FORWARDER shim re-points its fd 1 to a
#     PRIVATE fifo (O_RDWR, never drained) and fills the buffer -> the
#     buffer stays FULL -> the REAL probe's O_NONBLOCK write to
#     /proc/<fwd>/fd/1 returns EAGAIN -> DIRECT-COPY: status=1
#     (reason=partial). DETERMINISTIC: a full pipe returns EAGAIN instantly
#     for any write - EMPIRICAL host proof (errno 11), no timing race.
#     (status=2, the 5 s write deadline, is UNREACHABLE for a pipe in
#     practice - a full pipe returns EAGAIN instantly and an empty one
#     drains, so the deadline cannot elapse mid-write; the 5 s deadline
#     remains the code-level backstop, and the B4 contract's degraded
#     outcome is status=1.)
# The probe's stdout goes to the JOURNAL (no StandardOutput=; the journal is
# volatile post-stop - EMPIRICAL), so a test-only TEE shim taps the REAL
# probe's output to a durable file and records the per-operation wall (t0
# before the probe, t1 after) so the write operation's bound is measured on
# the operation, not just the container. The fatal is (c)-style (wrapper
# exit 1). The fatal-reason file is HARD-asserted (no file-write failure is
# injected - codex 85: retrieval failure is a test failure, not a note).
cat >"$FIXDIR/site-start-fatal-fast.sh" <<'WEOF'
#!/usr/bin/env bash
# TEST-ONLY s7(g): instant site-start failure (fast fatal path).
exit 1
WEOF
cat >"$FIXDIR/fwd-shim-fullpipe.sh" <<'WEOF'
#!/usr/bin/env bash
# TEST-ONLY s7(g1): re-point fd 1 (inherited = the container log pipe) to a
# PRIVATE fifo held O_RDWR, then fill it with BLOCKING writes until the
# buffer is full. Because the read half is held open but never read, the
# buffer stays FULL: the next blocking write blocks (holding it full), and
# the REAL probe's O_WRONLY|O_NONBLOCK write to /proc/<fwd>/fd/1 returns
# EAGAIN -> DIRECT-COPY: status=1 (deterministic).
# `exec 1<>` is O_RDWR (non-blocking for a fifo - a read-ONLY open would
# deadlock waiting for a peer writer). EMPIRICAL host proof: a filled,
# never-drained fifo gives a second O_NONBLOCK writer EAGAIN, errno 11.
rm -f /run/g1-pipe
mkfifo /run/g1-pipe
exec 1<>/run/g1-pipe
while :; do
    printf 'FILL-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\n' >&1 2>/dev/null
done
WEOF
cat >"$FIXDIR/probe-tee-tap.sh" <<'WEOF'
#!/usr/bin/env bash
# TEST-ONLY s7(g): run the REAL probe, tap its output to a durable file and
# record the per-operation wall (t0 before, t1 + rc after). Propagates the
# probe's exit via PIPESTATUS (the contract under test).
# NOTE: the tap lives in /var/log/omd-labs (OVERLAY - survives stop)
# because /tmp is a systemd tmpfs (EMPIRICAL: cleared on stop, so a
# /tmp tap is unreadable after the fatal).
mkdir -p /var/log/omd-labs
date +%s > /var/log/omd-labs/probe-tap.t0
/usr/local/bin/omd-ready-check.real 2>&1 | tee -a /var/log/omd-labs/probe-out.tap
rc=${PIPESTATUS[0]}
date +%s > /var/log/omd-labs/probe-tap.t1
echo "PROBE-RC=$rc" >> /var/log/omd-labs/probe-out.tap
exit "$rc"
WEOF
# g0: baseline (real forwarder, status=0) - no forwarder shim; g1: fullpipe
# (the shim replaces omd-labs-forwarder, so the entry's spawn runs the shim).
injection_build baseline 'RUN mv /usr/local/bin/omd-ready-check /usr/local/bin/omd-ready-check.real
ADD site-start-fatal-fast.sh /usr/local/bin/omd-site-start
ADD probe-tee-tap.sh /usr/local/bin/omd-ready-check
RUN chmod 755 /usr/local/bin/omd-site-start /usr/local/bin/omd-ready-check && bash -n /usr/local/bin/omd-ready-check && bash -n /usr/local/bin/omd-site-start'
injection_build fullpipe 'RUN mv /usr/local/bin/omd-ready-check /usr/local/bin/omd-ready-check.real
ADD site-start-fatal-fast.sh /usr/local/bin/omd-site-start
ADD probe-tee-tap.sh /usr/local/bin/omd-ready-check
ADD fwd-shim-fullpipe.sh /usr/local/bin/omd-labs-forwarder
RUN chmod 755 /usr/local/bin/omd-site-start /usr/local/bin/omd-ready-check /usr/local/bin/omd-labs-forwarder && bash -n /usr/local/bin/omd-ready-check && bash -n /usr/local/bin/omd-site-start && bash -n /usr/local/bin/omd-labs-forwarder'
for gcase in "baseline 0 sent (the happy path - REAL forwarder, REAL probe)" \
             "fullpipe 1 partial (EAGAIN - the undrained full pipe, REAL probe)"; do
    gname=${gcase%% *}; gexpstat=$(echo "$gcase" | awk '{print $2}'); gexpwhy=$(echo "$gcase" | awk '{print $3}')
    gstart=$(date +%s)
    v_run omd-s7"$gname" "local/omd-s7-$gname" "$P" "" -e SITENAME="$gname"
    t=0
    while (( t < 180 )); do
        running=$($RUNTIME inspect -f '{{.State.Running}}' omd-s7"$gname" 2>/dev/null || echo false)
        [ "$running" = "false" ] && break; sleep 2; t=$((t + 2))
    done
    gcode=$($RUNTIME inspect -f '{{.State.ExitCode}}' omd-s7"$gname" 2>/dev/null || echo unknown)
    gelapsed=$(( $(date +%s) - gstart ))
    gtap=$(mktemp -d)
    $RUNTIME cp omd-s7"$gname":/var/log/omd-labs/probe-out.tap "$gtap/o" 2>/dev/null || true
    $RUNTIME cp omd-s7"$gname":/var/log/omd-labs/probe-tap.t0 "$gtap/t0" 2>/dev/null || true
    $RUNTIME cp omd-s7"$gname":/var/log/omd-labs/probe-tap.t1 "$gtap/t1" 2>/dev/null || true
    # codex 87 MAJOR: the exit assertion was DISCARDED by the old
    # `set +e; [ "$gcode" = 1 ]; grep ...` (semicolon - v_check counts
    # only the final command's status, common.sh:344-350), so a probe
    # exiting 255/137 would still pass. Now the clause is MANDATORY
    # (`|| exit 1` inside the eval) and a SEPARATE check proves the
    # clause is non-vacuous: the same body with a deliberately wrong
    # code must FAIL.
    v_check "(g/$gname) container exited 1 AND the REAL probe's direct_copy returned status=$gexpstat ($gexpwhy) (code=$gcode, elapsed=${gelapsed}s)" \
        'set +e; gbody() { [ "$1" = 1 ] || { echo "exit code $1 != 1"; return 1; }; grep -q "DIRECT-COPY: status='"$gexpstat"'" "'"$gtap"'/o" 2>/dev/null || { echo "no status='"$gexpstat"' line:"; tail -5 "'"$gtap"'/o" 2>/dev/null; return 1; }; }; gbody '"$gcode"' || exit 1; grep "DIRECT-COPY" "'"$gtap"'/o" 2>/dev/null | head -1'
    v_check "(g/$gname) non-vacuous: the same body with a DELIBERATELY wrong code FAILS (proof the exit assertion is mandatory)" \
        'set +e; gbody() { [ "$1" = 1 ] || { echo "exit code $1 != 1"; return 1; }; grep -q "DIRECT-COPY: status='"$gexpstat"'" "'"$gtap"'/o" 2>/dev/null || return 1; }; gbody '"$gcode"' || { echo "BUG: real code failed the body"; exit 1; }; gbody 999 && { echo "BUG: wrong code 999 passed - assertion vacuous"; exit 1; }; echo "proof: body(real=$'"$gcode"') accepted, body(999) rejected"'
    # the per-operation wall (t0..t1 around the REAL probe) proves the write
    # operation is BOUNDED: both the happy path and the EAGAIN path complete
    # in well under the 5 s deadline (a full pipe returns EAGAIN instantly).
    v_check "(g/$gname) the direct-copy operation is BOUNDED (per-op wall < 15 s from the tap)" \
        'set +e; [ -s "'"$gtap"'/t0" ] && [ -s "'"$gtap"'/t1" ] || { echo "missing tap timing"; exit 1; }; op=$(( $(cat "'"$gtap"'/t1") - $(cat "'"$gtap"'/t0") )); [ "$op" -ge 0 ] && [ "$op" -lt 15 ] || { echo "per-op wall ${op}s out of bounds"; exit 1; }; echo "per-op wall=${op}s"'
    v_check "(g/$gname) writable-layer fatal-reason file carries the reason (guaranteed artifact, HARD)" \
        'set +e; tmp=$(mktemp -d); $RUNTIME cp omd-s7'"$gname"':/var/log/omd-labs/fatal-reason "$tmp/r" 2>/dev/null && grep -q "READY-FATAL" "$tmp/r" && head -1 "$tmp/r"; rc=$?; rm -rf "$tmp"; exit $rc'
    rm -rf "$gtap"
    v_teardown omd-s7"$gname"
done

v_note "post-ready crash never exits the container (a/b contrast); all hangs bounded (f)"
v_end
