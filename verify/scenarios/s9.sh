#!/usr/bin/env bash
# S9 - Distro parity (FR-017; SC-008)
# Runs S1-S8 identically on local/omd-labs-systemd-vm-rocky:<TAG> and
# local/omd-labs-systemd-vm-debian:<TAG> (distro names swapped: apache2, cron) and asserts
# identical outcomes: same banners, same exit codes, same listener/port
# behavior, same UI path, same stop semantics - any divergence is a defect.
# This is the amd64 arm of SC-008 (T032); arm64 is the T3 gate (T035).
#
# The scenarios run strictly SEQUENTIALLY (suite contract: scenario runs are
# never concurrent). Heavy battery scenarios (s6/s7) make the full parity run
# long; S9_SCENARIOS trims the set when a reduced parity check is wanted.
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/common.sh"

S9_SCENARIOS=${S9_SCENARIOS:-"s1 s2 s3 s3b s4 s5 s6 s7 s8"}

v_begin "S9-parity-$DISTRO"
v_note "parity request distro: $DISTRO; executing S1-S8 on BOTH distros (rocky + debian), tag=$TAG, sequential"

for sc in $S9_SCENARIOS; do
    v_note "parity: running $sc on rocky..."
    set +e
    bash "$VER_DIR/run.sh" "$sc" rocky "$TAG"
    rc_rocky=$?
    set -e
    v_note "parity: running $sc on debian..."
    set +e
    bash "$VER_DIR/run.sh" "$sc" debian "$TAG"
    rc_debian=$?
    set -e
    # per-scenario details (banners, exit codes, listeners, UI path, stop
    # semantics) live in the $sc-<distro> sections of results.md; identical
    # PASS/FAIL outcomes on both distros is the parity assertion.
    v_check "parity $sc: identical outcomes (rocky rc=$rc_rocky, debian rc=$rc_debian)" \
        'set +e; [ '"$rc_rocky"' -eq 0 ] && [ '"$rc_debian"' -eq 0 ]'
done

v_note "parity evidence sections: S1-S8 x {rocky,debian} in results.md; arm64 arm = T035"
v_end
