#!/usr/bin/env bash
# verify/run.sh - runner for the 001-systemd-vm-startup verification suite.
#
# Usage: verify/run.sh <scenario> [distro] [tag]
#   scenario: s1 s2 s3 s3b s4 s5 s6 s7 s8 s9 s10 s11a s11b s12
#   distro:   rocky (default) | debian
#   tag:      image tag (default: branch-derived, master -> nightly)
#
# Rules (quickstart.md Prerequisites):
#   - one scenario per invocation; scenario runs are never concurrent
#   - unique host port per scenario (18451..18461)
#   - each scenario writes its own uniquely named section of results.md
#   - the suite MUST be runnable against any image (baseline images included);
#     a scenario that cannot pass on an old image records FAIL (red baseline)
set -euo pipefail

SCEN=${1:?"usage: run.sh <scenario> [distro rocky|debian] [tag] [subitem]"}
DISTRO=${2:-rocky}
# (M7, codex 99) the tag is ALWAYS argument 3 and the subitem ALWAYS argument
# 4 (s6 d/f/g, ...). The old form silently dropped the explicitly supplied tag
# whenever a 4th argument was present (run.sh s6 rocky candidate g verified
# the branch-default image, not candidate - wrong-image smoke, debate/76).
TAG=${3:-$(git rev-parse --abbrev-ref HEAD | sed 's/^master$/nightly/')}

case $DISTRO in
    rocky)  SLOT=0; EDGE_UNIT=httpd;  CRON_UNIT=crond;  SSH_UNIT=sshd;;
    debian) SLOT=1; EDGE_UNIT=apache2; CRON_UNIT=cron;   SSH_UNIT=ssh;;
    *) echo "unknown distro: $DISTRO" >&2; exit 64;;
esac

# shellcheck source=verify/common.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

IMAGE=$(v_image "$DISTRO" "$TAG")
export SCEN DISTRO SLOT EDGE_UNIT CRON_UNIT SSH_UNIT IMAGE TAG

# the complete documented end-to-end bound (360 s) - overridable for bounded
# red-baseline runs against images without the omd-ready unit (T004)
export READY_DEADLINE="${READY_DEADLINE:-360}"
export OMD_VERIFY_LOCK

# suite concurrency (suite contract: scenario runs are never concurrent) is
# enforced by a real lock, not just by convention: (re)create the lock file
# so its mtime marks THIS run's start, then hold it for the whole invocation
# (2026-11-13 recorded fix, 002 analyze round B2, codex). The BLOCKING flock
# is the never-concurrent guarantee - a second invocation cannot reach its
# pre-cleanup while this one runs, so an active run's containers are
# untouched - and the moment the lock is released (this run ends), every
# still-running suite container becomes provably stale, so the NEXT run's
# pre-cleanup owns its cleanup.
: > "$OMD_VERIFY_LOCK"
exec 9> "$OMD_VERIFY_LOCK"
flock 9

echo "### runner: scenario=$SCEN distro=$DISTRO tag=$TAG image=$IMAGE runtime=$RUNTIME"
# pre-cleanup: a CRASHED previous run may have leaked its containers - the
# names AND the host ports (pasta) would then block this run (EMPIRICAL
# 2026-11-10: leaked omd-s2c1 held 18453, aborting the next distro's start).
# The old name-prefix sweep (rm of every running ^omd-s) is GONE: a name
# prefix is not ownership - it deleted a user's omd-sandbox container by
# pattern match. Ownership now requires (1) the suite labels applied by
# v_suite_label at every suite creation site and (2) the staleness proof of
# v_precleanup (the lock above): a suite-labeled container started after
# this run's lock is THIS run's and is never touched.
v_precleanup
bash "$VER_DIR/scenarios/$SCEN.sh" ${4:-}
exit $?
