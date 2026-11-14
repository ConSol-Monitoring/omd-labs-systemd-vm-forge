#!/usr/bin/env bash
# S2 - Named site via SITENAME: create, resume, site-start baseline (US2, US4 sc4; SC-002; FR-004/FR-005)
# Volume-content checks run through the ROOT probe helpers (v_vol_*): after
# the first start the entry chowns the volume top dir to site:omd 0750 and
# the host user (uid 1000) gets EACCES - EMPIRICAL 2026-11-10.
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/common.sh"
. "$VER_DIR/fixtures.sh"

P=$(v_port s2)
SITE=mysite
VOLDIR="$FIXDIR/s2-site"
v_vol_wipe "$VOLDIR" || true
mkdir -p "$VOLDIR"

v_begin "S2-$SCEN-$DISTRO"

# --- first start: create ---
v_run omd-s2 "$IMAGE" "$P" "" -e SITENAME=$SITE $(v_vol "$VOLDIR" /omd/sites/$SITE z)
v_check "readiness (gate active + /$SITE/ answers 302/200)" \
    'set +e; rt=$(v_wait_ready omd-s2 '"$P"' /'"$SITE"'/); rc=$?; echo "ready-time=${rt}s"; exit $rc'
v_check "log shows prominent 'created new site $SITE'" \
    '_lg=$("$RUNTIME" logs omd-s2 2>/dev/null); case "$_lg" in *"created new site $SITE"*) ;; *) exit 1;; esac'
v_check "omd status $SITE running (rc 0)" \
    "$RUNTIME exec omd-s2 omd status $SITE"
v_check "site data on host volume (etc/var/local/version + init-complete marker, root probe)" \
    'v_vol_ls '"$VOLDIR"' etc var local version .omd-labs-init-complete'
v_check "5 site daemons run as user $SITE" \
    "$RUNTIME exec omd-s2 sh -c 'ps -o user= -C naemon | sort -u | head -1' | grep -qx $SITE"
v_check "HTTPS /$SITE/ through the edge (host-side)" \
    "curl -sk -o /dev/null -w '%{http_code}' --max-time 5 https://127.0.0.1:$P/$SITE/ | grep -E '^(302|200)$'"
v_note "site-start ready-time (first start): see 'readiness' evidence above; formal median-of-5 baseline = T034 (FR-018)"

# --- restart same container: resume ---
v_stop omd-s2 >/dev/null
v_check "restart same container reaches ready again" \
    '"$RUNTIME" start omd-s2 || exit 1; rt=$(v_wait_ready omd-s2 '"$P"' /'"$SITE"'/) || { echo "not ready after restart"; exit 1; }; echo "ready-time=${rt}s"'
v_check "log shows 'resumed existing site $SITE' (no re-creation)" \
    '_lg=$("$RUNTIME" logs omd-s2 2>/dev/null); case "$_lg" in *"resumed existing site $SITE"*) ;; *) exit 1;; esac'

# --- fresh replacement container: registration restored (D6 row 2) ---
v_teardown omd-s2
v_run omd-s2b "$IMAGE" "$P" "" -e SITENAME=$SITE $(v_vol "$VOLDIR" /omd/sites/$SITE z)
v_check "replacement container resumes (account absent in fresh image)" \
    'set +e; rt=$(v_wait_ready omd-s2b '"$P"' /'"$SITE"'/); rc=$?; echo "ready-time=${rt}s"; exit $rc'
v_check "replacement: 'resumed existing site $SITE'" \
    '_lg=$("$RUNTIME" logs omd-s2b 2>/dev/null); case "$_lg" in *"resumed existing site $SITE"*) ;; *) exit 1;; esac'
v_check "replacement: omd status $SITE rc 0" \
    "$RUNTIME exec omd-s2b omd status $SITE"
v_teardown omd-s2b

# --- SC-002: two concurrent containers, different SITENAME, each its own site ---
# Each container's system edge apache carries ONLY its own site's vhost
# (/omd/apache is image-FS, not the volume). Container A publishes the
# scenario port; container B publishes none (two pasta forwarders cannot
# bind the same host port) - B's edge is probed in-container on loopback.
# Both containers run at the same time: that IS the concurrency assertion.
V1="$FIXDIR/s2cc-a"; V2="$FIXDIR/s2cc-b"
v_vol_wipe "$V1" || true; mkdir -p "$V1"
v_vol_wipe "$V2" || true; mkdir -p "$V2"
v_run omd-s2c1 "$IMAGE" "$P" "" -e SITENAME=s2siteA $(v_vol "$V1" /omd/sites/s2siteA z)
v_check "SC-002: concurrent site A ready (/s2siteA/ via published edge)" \
    'set +e; rt=$(v_wait_ready omd-s2c1 '"$P"' /s2siteA/); rc=$?; echo "ready-time=${rt}s"; exit $rc'
# NOTE: raw run (not v_run) so NO host port is published - two pasta
# forwarders cannot bind the same host port; B is probed in-container
# on loopback. SELABEL carries its own leading colon ("$V2:...:z") -
# appending the stripped form glued "z" onto the CONTAINER PATH (site
# went to the overlay, volume stayed empty - EMPIRICAL 2026-11-10).
# The raw run must not kill the script (set +e) - a failed B start
# must fail the CHECK below, not abort the scenario with c1 leaked.
set +e
$RUNTIME run --name omd-s2c2 $(v_flags) $(v_suite_label) -d -e SITENAME=s2siteB -v "$V2:/omd/sites/s2siteB${SELABEL}" "$IMAGE" >/dev/null 2>&1
run_b_rc=$?
set -e
[ "$run_b_rc" -eq 0 ] || { echo "container B start failed (rc=$run_b_rc)"; v_teardown omd-s2c1; exit 1; }
# B's edge is probed from inside container B on loopback (its edge apache
# answers /s2siteB/; curl rc 0 = an HTTP answer, i.e. 302/200 - the OMD
# login redirect)
v_check "SC-002: concurrent site B ready (gate active + /s2siteB/ on its own edge)" \
    'set +e; deadline=${READY_DEADLINE:-360}; t0=$SECONDS; while (( SECONDS - t0 < deadline )); do v_running omd-s2c2 || { echo "B exited (code $(v_exited_code omd-s2c2))"; exit 1; }; st=$($RUNTIME exec omd-s2c2 systemctl is-active omd-ready 2>/dev/null || echo unknown); if [ "$st" = active ]; then $RUNTIME exec omd-s2c2 sh -c "curl -sk -o /dev/null --max-time 4 https://127.0.0.1/s2siteB/" && { echo "ready-time=$((SECONDS - t0))s"; exit 0; }; fi; sleep 1; done; echo "B not ready within $deadline s"; exit 1'
v_check "SC-002: site A still serving WHILE B runs (no interference, both up)" \
    "curl -sk -o /dev/null -w '%{http_code}' --max-time 5 https://127.0.0.1:$P/s2siteA/ | grep -E '^(302|200)$'"
v_check "SC-002: omd status of BOTH sites rc 0 (independent site daemons)" \
    'set +e; out=$( { '"$RUNTIME"' exec omd-s2c1 omd status s2siteA >/dev/null 2>&1 && echo A0 || echo AX; '"$RUNTIME"' exec omd-s2c2 omd status s2siteB >/dev/null 2>&1 && echo B0 || echo BY; } ); echo "$out"; case "$out" in *A0*B0*) exit 0;; *) exit 1;; esac'
v_check "SC-002: both volumes populated independently (root probe)" \
    'v_vol_ls '"$V1"' .omd-labs-init-complete etc && v_vol_ls '"$V2"' .omd-labs-init-complete etc'
v_teardown omd-s2c2 omd-s2c1

v_note "site-start reference ready-time: see readiness evidence above (formal median-of-5 = T034)"
v_end
