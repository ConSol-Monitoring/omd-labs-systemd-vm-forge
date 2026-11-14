#!/usr/bin/env bash
# S5 - Customization: valid settings enable a component + precedence (US5 sc1/sc2/sc5; SC-012; FR-010)
# File + env set the SAME key to CONFLICTING valid values (N4): env must win.
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/common.sh"
. "$VER_DIR/fixtures.sh"

P=$(v_port s5)
SITE=custsite
VOLDIR="$FIXDIR/s5-site"
v_vol_wipe "$VOLDIR" || true
mkdir -p "$VOLDIR"
mkdir -p "$FIXDIR/s5-none"
v_vol_wipe "$FIXDIR/s5-none" || true
CONF=$(fx_settings_file)

v_begin "S5-$SCEN-$DISTRO"

v_run omd-s5 "$IMAGE" "$P" "" -e SITENAME=$SITE \
    -e OMDCFG_MOD_GEARMAN=on -e OMDCFG_GEARMAND_PORT=0.0.0.0:4730 \
    -v "$CONF:/etc/omd-labs/site-settings.conf:ro${SELABEL:+,z}" $(v_vol "$VOLDIR" /omd/sites/$SITE z)
v_check "readiness (gate + /$SITE/)" \
    'set +e; rt=$(v_wait_ready omd-s5 '"$P"' /'"$SITE"'/); rc=$?; echo "ready-time=${rt}s"; exit $rc'
v_check "gearmand listening on 4730 when ready (SC-012 - component came up with the site)" \
    "$RUNTIME exec omd-s5 sh -c 'ss -ltn | grep -qE \":4730 \"'"
v_check "env value WON the conflict: omd config show GEARMAND_PORT = 0.0.0.0:4730 (EXACT line)" \
    "$RUNTIME exec omd-s5 runuser -u $SITE -- omd config show GEARMAND_PORT | grep -qx '0.0.0.0:4730'"
v_check "effective config observable: MOD_GEARMAN = on (EXACT line)" \
    "$RUNTIME exec omd-s5 runuser -u $SITE -- omd config show MOD_GEARMAN | grep -qx on"
v_check "container log carries the effective-customization summary (FR-010; bounded wait for log flush)" \
    'v_wait_log omd-s5 customization'
v_check "listener address is the env value (0.0.0.0:4730)" \
    "$RUNTIME exec omd-s5 sh -c 'ss -ltn | grep 4730 | grep -q \"0.0.0.0\"'"

# no-customization baseline: no 4730 listener (S2/S4 runs)
# N2 (codex 75): the negative check must first PROVE it observed a real
# listener list - an empty capture (exec failed / ss missing) would make
# the case-statement pass for the wrong reason.
v_teardown omd-s5
v_run omd-s5-none "$IMAGE" "$P" "" -e SITENAME=plain5 $(v_vol "$FIXDIR/s5-none" /omd/sites/plain5 z)
v_check "no customization input ? ready BEFORE the negative listener check" \
    'set +e; rt=$(v_wait_ready omd-s5-none '"$P"' /plain5/); rc=$?; echo "ready-time=${rt}s"; exit $rc'
v_check "no customization input ? no 4730 listener (capture non-empty first - N2)" \
    "set +e; out=\$($RUNTIME exec omd-s5-none sh -c 'ss -ltn' 2>/dev/null); [ -n \"\$out\" ] || { echo 'EMPTY ss capture - negative check void'; exit 1; }; case \$out in *:4730*) echo \"\$out\"; exit 1;; esac; exit 0"
v_teardown omd-s5-none

# --- S6c: persisted site restarted WITH inputs ? stored config wins + notice ---
v_run omd-s5-re "$IMAGE" "$P" "" -e SITENAME=$SITE \
    -e OMDCFG_MOD_GEARMAN=off -e OMDCFG_GEARMAND_PORT=127.0.0.1:9999 \
    -v "$CONF:/etc/omd-labs/site-settings.conf:ro${SELABEL:+,z}" $(v_vol "$VOLDIR" /omd/sites/$SITE z)
v_check "S6c: persisted site resumes ready (stored configuration authoritative)" \
    'set +e; rt=$(v_wait_ready omd-s5-re '"$P"' /'"$SITE"'/); rc=$?; echo "ready-time=${rt}s"; exit $rc'
v_check "S6c: stored value survives (GEARMAND_PORT still 0.0.0.0:4730 - inputs NOT applied, EXACT line)" \
    "$RUNTIME exec omd-s5-re runuser -u $SITE -- omd config show GEARMAND_PORT | grep -qx '0.0.0.0:4730'"
v_check "S6c: log carries the deterministic notice that inputs were not applied (FR-012; bounded wait)" \
    'v_wait_log omd-s5-re "not applied"'
v_teardown omd-s5-re
v_end
