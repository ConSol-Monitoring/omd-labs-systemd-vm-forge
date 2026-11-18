#!/usr/bin/env bash
# S12 - OMD_ADMIN_PASSWORD: the site web credential from the run environment
# (web-admin-credential capability; openspec change admin-password-env).
# Port 18450 (v_port s12; in the enforced 18449..18461 range).
#
# Sub-items (tasks 3.1/3.3/3.4/3.5 of the change):
#   (a) fresh + pw  -> ready; htpasswd at exactly etc/htpasswd (the
#       runuser-HOME proof); thruk 200/302; wrong pw rejected; notice
#       present; the literal pw ABSENT from the container log
#   (b) verbatim: a value with leading/trailing whitespace + metacharacters
#       is the EXACT credential (exact value logs in; trimmed variant fails -
#       no shell-evaluated string, no trimming)
#   (c) replacement container, SAME volume, DIFFERENT value -> stored
#       credential wins: htpasswd UNCHANGED (sha256), stored logs in, new
#       value rejected, "resumed existing site", no notice
#   (d) fresh + exactly-EMPTY value -> no-op: no notice, the generated
#       omdadmin entry stands
#   (e) clean stop contract (exit 130/0) on the (a) volume's container
#   (i)/(ii)  recovery sub-branches (INPROG-only tree -> create --reuse
#       branch; version-link real tree -> omd enable branch, pre-existing
#       generated credential invalidated)
#   (iii)/(iv) protection boundaries: persisted (COMPLETE + stale INPROG)
#       and adopted (no-marker real tree) + different value -> stored wins
#   (j)/(k)   PRE-COMMIT failure injection in BOTH creation tails (S6
#       d-injected pattern): test-only FROM $IMAGE sub-builds, sed-injected
#       exit 1 at the unique PRE-COMMIT entry anchors -> exit 1, named fatal
#       cause WITHOUT the value, COMPLETE absent, INPROG retained; a retry
#       boot with a valid value completes the creation. These prove the
#       INJECTION ORDERING (between credential step and commit) and the
#       rollback/INPROG-retention contract - the failure text is authored by
#       the test itself (the real setter already succeeded before the
#       injection), so the REAL run_bounded/failure path is covered by (l)-(n)
#   (l)       the REAL production failure path: the in-image set_admin_password
#       is broken in a test-only sub-build (rc=99) -> the entry's real
#       run_bounded captures the real rc and the real fatal writes the named
#       cause (production text, NOT test-authored): exit 1,
#       "FATAL: step failed (rc=99): set omdadmin web password", step line
#       present (the real invocation), success notice ABSENT, value ABSENT
#       from entry-fatal+log, run_bounded replayed the child output, COMPLETE
#       absent, INPROG retained
#   (m)       the DISTINCT run_bounded timeout branch (run_bounded: the
#       tool hangs 45s > the 30s bound): "FATAL: step timed out after 30s:
#       set omdadmin web password" AND "step failed (rc=124)", value absent,
#       COMPLETE absent, INPROG retained
#   (n)       retry after the real (l) failure: (l)'s volume + the NORMAL
#       image -> recovery completes, the value is the effective credential,
#       committed
#
# Credential requests use `Authorization: Basic` with a HOST-SIDE base64 of
# "omdadmin:<value>": the raw value (whitespace + quotes + $) must never
# pass through the v_check eval-string quoting (word splitting / re-expansion
# at the eval level would corrupt it). The HTTP Basic header IS the
# omdadmin:<value> pair curl -u sends, so the semantics are identical.
#
# EVAL-STRING QUOTING (two EMPIRICAL traps, 2026-11-18 S12 runs):
# (1) inside an eval string's $( ), `'"$VAR"'` outer-expansion is only safe
#     when `)` follows the expansion (S1 form: $('"$RUNTIME"' exec ...)); the
#     `'"$RUNTIME"' logs` form yields `_lg=$("podman logs ...` - a `"` BEFORE
#     the ) opens an unterminated double-quote in the eval string (unexpected
#     EOF). Use the S6 single-segment form instead: $RUNTIME unquoted in the
#     source, expanded AT eval time.
# (2) `grep -Fc '"$NOTICE"'` outer-expands the value OUTSIDE the eval string:
#     its quotes are consumed by the OUTER shell and the (space-containing)
#     value word-splits at eval time. Multi-word values must expand INSIDE the
#     eval string: grep -Fc "$NOTICE" (double quotes in the eval string).
# Assertion style: `set -e` inside a v_check eval string is NOT reliable
# (bash disables errexit in conditional contexts - S1 header) - every check
# uses explicit `|| exit 1` / explicit success codes.
# Volume-content checks run through the ROOT probe helpers (v_vol_*): the
# host user (uid 1000) gets EACCES on site-chowned volumes (EMPIRICAL).
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/common.sh"
. "$VER_DIR/fixtures.sh"

P=$(v_port s12)
SITE=s12
VOLDIR="$FIXDIR/s12-site"
# order: mkdir FIRST - v_vol_wipe's probe container binds the dir
# (statfs of a missing source fails)
mkdir -p "$VOLDIR"
v_vol_wipe "$VOLDIR" || true

v_begin "S12-$SCEN-$DISTRO"
v_note "port $P; site $SITE; volume $VOLDIR"

# deterministic, distinct values (the log-absence assertions grep -F the
# LITERAL value, so no two sub-item values may be substrings of another)
PW_A='S12FreshPW#x 9'
PW_B=" pw'x\"y\$z "
PW_C=s12storedwins
PW_D=knownstoredpw

NOTICE="web admin password set from OMD_ADMIN_PASSWORD"

# base64 transports (host-side; curl sends the header verbatim - the value
# reaches apache byte-exact)
B64_A=$(printf '%s' "omdadmin:$PW_A" | base64 -w0)
B64_B=$(printf '%s' "omdadmin:$PW_B" | base64 -w0)
# (b) the TRIMMED variant is derived from PW_B itself: strip exactly one
# leading and one trailing character (the TRUE trim of the verbatim value -
# codex F4 05-codex-impl-review: the hand-written variant had lost the
# apostrophe, so the negative check tested a second mutation, not the trim)
PW_B_TRIM="${PW_B#?}"; PW_B_TRIM="${PW_B_TRIM%?}"
B64_TRIM=$(printf '%s' "omdadmin:$PW_B_TRIM" | base64 -w0)
B64_C=$(printf '%s' "omdadmin:$PW_C" | base64 -w0)
B64_D=$(printf '%s' "omdadmin:$PW_D" | base64 -w0)
B64_WRONG=$(printf '%s' "omdadmin:definitely-not-the-pw" | base64 -w0)

# ---- (a) fresh site + OMD_ADMIN_PASSWORD -> ready, credential applied ----
v_note "--- (a) fresh + pw"
v_run omd-s12a "$IMAGE" "$P" "" -e SITENAME=$SITE -e OMD_ADMIN_PASSWORD="$PW_A" $(v_vol "$VOLDIR" /omd/sites/$SITE z)
v_check "(a) readiness (gate active + /$SITE/ answers 302/200)" \
    'set +e; rt=$(v_wait_ready omd-s12a '"$P"' /'"$SITE"'/); rc=$?; echo "ready-time=${rt}s"; exit $rc'
# the owner is the entry's DETERMINISTICALLY ALLOCATED account (not root):
# the runuser-HOME proof is the PATH itself (the tool writes ~/etc/htpasswd
# from the site user's HOME /omd/sites/<site>; a wrong HOME would miss this
# exact path). Live evidence (omd-qs): the file is uid:uid 664 (the tool's
# umask 002), so no group assertion beyond non-root owner.
v_check "(a) htpasswd at EXACTLY etc/htpasswd, owned by the allocated site user (non-root, root probe)" \
    'v_vol_probe '"$VOLDIR"' "test -f /w/etc/htpasswd && test ! -L /w/etc/htpasswd && [ \"\$(stat -c %u /w/etc/htpasswd)\" != 0 ]"'
v_check "(a) omdadmin entry present (root probe)" \
    'v_vol_probe '"$VOLDIR"' "grep -qx \"omdadmin:.*\" /w/etc/htpasswd"'
v_check "(a) thruk: authenticated 200 / anonymous 302" \
    'set +e; wc=$(curl -sk -H "Authorization: Basic '"$B64_A"'" -o /dev/null -w "%{http_code}" --max-time 8 "https://127.0.0.1:'"$P"'/'"$SITE"'/thruk/"); ac=$(curl -sk -o /dev/null -w "%{http_code}" --max-time 8 "https://127.0.0.1:'"$P"'/'"$SITE"'/thruk/"); echo "with-cred=$wc anon=$ac"; [ "$wc" = 200 ] && [ "$ac" = 302 ]'
v_check "(a) wrong password rejected (anon-equivalent 302, NOT 200)" \
    'set +e; wc=$(curl -sk -H "Authorization: Basic '"$B64_WRONG"'" -o /dev/null -w "%{http_code}" --max-time 8 "https://127.0.0.1:'"$P"'/'"$SITE"'/thruk/"); echo "wrong=$wc"; [ "$wc" = 302 ]'
v_check "(a) notice line present exactly once (deterministic, no value)" \
    '_lg=$($RUNTIME logs omd-s12a 2>/dev/null); n=$(echo "$_lg" | grep -Fc "$NOTICE"); [ "$n" = 1 ]'
v_check "(a) the literal password ABSENT from the container log (hardened: read must succeed and capture the entry's own output)" \
    '_lg=$($RUNTIME logs omd-s12a 2>/dev/null) || exit 1; case "$_lg" in *"omd-labs-entry:"*) ;; *) exit 1;; esac; n=$(echo "$_lg" | grep -Fc "$PW_A" || true); [ "$n" = 0 ]'
# stop (a) now: (b) reuses the SAME host port (suite contract: one
# container at a time); (c) re-runs the (a) volume in a fresh container
rc=$(v_stop omd-s12a)
code=$(v_exited_code omd-s12a)
v_note "(a) stopped before (b) (code=$code, stop rc=$rc)"
v_teardown omd-s12a

# ---- (b) verbatim application: whitespace + metacharacters -------------
v_note "--- (b) verbatim"
VOLDIR_B="$FIXDIR/s12b-site"
mkdir -p "$VOLDIR_B"
v_vol_wipe "$VOLDIR_B" || true
v_run omd-s12b "$IMAGE" "$P" "" -e SITENAME=$SITE -e OMD_ADMIN_PASSWORD="$PW_B" $(v_vol "$VOLDIR_B" /omd/sites/$SITE z)
v_check "(b) readiness" \
    'set +e; rt=$(v_wait_ready omd-s12b '"$P"' /'"$SITE"'/); rc=$?; echo "ready-time=${rt}s"; exit $rc'
v_check "(b) login with the EXACT verbatim value succeeds (leading/trailing space + metacharacters)" \
    'set +e; wc=$(curl -sk -H "Authorization: Basic '"$B64_B"'" -o /dev/null -w "%{http_code}" --max-time 8 "https://127.0.0.1:'"$P"'/'"$SITE"'/thruk/"); echo "exact=$wc"; [ "$wc" = 200 ]'
v_check "(b) the TRIMMED variant FAILS (302 - proves no trimming / no shell-evaluated string)" \
    'set +e; wc=$(curl -sk -H "Authorization: Basic '"$B64_TRIM"'" -o /dev/null -w "%{http_code}" --max-time 8 "https://127.0.0.1:'"$P"'/'"$SITE"'/thruk/"); echo "trimmed=$wc"; [ "$wc" = 302 ]'
v_check "(b) notice present; the verbatim value ABSENT from the log" \
    '_lg=$($RUNTIME logs omd-s12b 2>/dev/null); n=$(echo "$_lg" | grep -Fc "$NOTICE"); m=$(echo "$_lg" | grep -Fc -- "$PW_B" || true); [ "$n" = 1 ] && [ "$m" = 0 ]'
v_teardown omd-s12b

# ---- (c) replacement container, SAME volume, DIFFERENT value -----------
v_note "--- (c) replacement, stored wins (fresh container on the (a) volume)"
ht_hash=$(v_vol_probe "$VOLDIR" "grep -x 'omdadmin:.*' /w/etc/htpasswd")
ht_ck_before=$(v_vol_probe "$VOLDIR" "sha256sum /w/etc/htpasswd" | cut -d' ' -f1)
v_run omd-s12c "$IMAGE" "$P" "" -e SITENAME=$SITE -e OMD_ADMIN_PASSWORD="$PW_C" $(v_vol "$VOLDIR" /omd/sites/$SITE z)
v_check "(c) readiness (resume, gate active + /$SITE/)" \
    'set +e; rt=$(v_wait_ready omd-s12c '"$P"' /'"$SITE"'/); rc=$?; echo "ready-time=${rt}s"; exit $rc'
v_check "(c) log shows 'resumed existing site $SITE' (row 2, no re-creation)" \
    '_lg=$($RUNTIME logs omd-s12c 2>/dev/null); case "$_lg" in *"resumed existing site $SITE"*) ;; *) exit 1;; esac'
v_check "(c) NO notice (the variable is a creation-only input, ignored on resume; hardened read)" \
    '_lg=$($RUNTIME logs omd-s12c 2>/dev/null) || exit 1; case "$_lg" in *"omd-labs-entry:"*) ;; *) exit 1;; esac; n=$(echo "$_lg" | grep -Fc "$NOTICE" || true); [ "$n" = 0 ]'
v_check "(c) the STORED credential logs in (the (a) value, extracted before the run)" \
    'set +e; hc=$(curl -sk -H "Authorization: Basic '"$B64_A"'" -o /dev/null -w "%{http_code}" --max-time 8 "https://127.0.0.1:'"$P"'/'"$SITE"'/thruk/"); echo "stored=$hc"; [ "$hc" = 200 ]'
v_check "(c) the NEW value is REJECTED (stored wins, 302)" \
    'set +e; wc=$(curl -sk -H "Authorization: Basic '"$B64_C"'" -o /dev/null -w "%{http_code}" --max-time 8 "https://127.0.0.1:'"$P"'/'"$SITE"'/thruk/"); echo "new=$wc"; [ "$wc" = 302 ]'
ht_ck_after=$(v_vol_probe "$VOLDIR" "sha256sum /w/etc/htpasswd" | cut -d' ' -f1)
v_check "(c) htpasswd content UNCHANGED (sha256 before == after, root probe)" \
    '[ -n "'"$ht_ck_before"'" ] && [ "'"$ht_ck_after"'" = "'"$ht_ck_before"'" ]'
v_note "(c) stored omdadmin hash: $(echo "$ht_hash" | cut -c1-40)..."

# ---- (e) clean stop contract on the (c) container (same (a) volume) ----
v_note "--- (e) clean stop contract"
rc=$(v_stop omd-s12c)
code=$(v_exited_code omd-s12c)
v_check "(e) clean stop -t 30 ends 130/0, not 137 (exit code: $code, stop rc: $rc)" \
    'case '"$code"' in 130|0) ;; *) exit 1;; esac'
v_teardown omd-s12c

# ---- (d) fresh site with EXACTLY-EMPTY OMD_ADMIN_PASSWORD -> no-op -----
v_note "--- (d) empty value = no-op"
VOLDIR_D="$FIXDIR/s12d-site"
mkdir -p "$VOLDIR_D"
v_vol_wipe "$VOLDIR_D" || true
v_run omd-s12d "$IMAGE" "$P" "" -e SITENAME=$SITE -e OMD_ADMIN_PASSWORD= $(v_vol "$VOLDIR_D" /omd/sites/$SITE z)
v_check "(d) readiness" \
    'set +e; rt=$(v_wait_ready omd-s12d '"$P"' /'"$SITE"'/); rc=$?; echo "ready-time=${rt}s"; exit $rc'
v_check "(d) NO notice (the exactly-empty value is a no-op, no setter invocation; hardened read)" \
    '_lg=$($RUNTIME logs omd-s12d 2>/dev/null) || exit 1; case "$_lg" in *"omd-labs-entry:"*) ;; *) exit 1;; esac; n=$(echo "$_lg" | grep -Fc "$NOTICE" || true); [ "$n" = 0 ]'
# the BOUNDED-STEP line is emitted by run_bounded ITSELF before the tool
# call - its absence distinguishes "no invocation" from "invoked silently"
v_check "(d) the credential step was NEVER INVOKED (the run_bounded step line is absent; hardened read)" \
    '_lg=$($RUNTIME logs omd-s12d 2>/dev/null) || exit 1; case "$_lg" in *"omd-labs-entry:"*) ;; *) exit 1;; esac; n=$(echo "$_lg" | grep -Fc "step: set omdadmin web password" || true); [ "$n" = 0 ]'
v_check "(d) the generated omdadmin entry stands in etc/htpasswd (root probe)" \
    'v_vol_probe '"$VOLDIR_D"' "grep -qx \"omdadmin:.*\" /w/etc/htpasswd"'
v_check "(d) 'created new site $SITE' (fresh creation, no credential step)" \
    '_lg=$($RUNTIME logs omd-s12d 2>/dev/null); case "$_lg" in *"created new site $SITE"*) ;; *) exit 1;; esac'
v_teardown omd-s12d

# ---------------------------------------------------------------------------
# (i) recovery sub-branch 1: INPROG-only tree -> `omd create --reuse` branch
# (the interrupted creation never reached the version link); value applied.
# ---------------------------------------------------------------------------
v_note "--- (i) recovery, tree-only (create --reuse branch)"
d=$(fx_d6_interrupted "$SITE" tree-only)
v_run omd-s12i "$IMAGE" "$P" "" -e SITENAME=$SITE -e OMD_ADMIN_PASSWORD="$PW_A" $(v_vol "$d" /omd/sites/$SITE z)
v_check "(i) readiness (recovery completes, gate active + /$SITE/)" \
    'set +e; rt=$(v_wait_ready omd-s12i '"$P"' /'"$SITE"'/); rc=$?; echo "ready-time=${rt}s"; exit $rc'
v_check "(i) recovery banner present" \
    'v_wait_log omd-s12i "recovery complete - resumed existing site '"$SITE"'"'
v_check "(i) login with the environment value succeeds" \
    'set +e; wc=$(curl -sk -H "Authorization: Basic '"$B64_A"'" -o /dev/null -w "%{http_code}" --max-time 8 "https://127.0.0.1:'"$P"'/'"$SITE"'/thruk/"); echo "with-cred=$wc"; [ "$wc" = 200 ]'
v_check "(i) notice present (the creation tail was re-run)" \
    '_lg=$($RUNTIME logs omd-s12i 2>/dev/null); n=$(echo "$_lg" | grep -Fc "$NOTICE"); [ "$n" = 1 ]'
v_check "(i) committed: complete marker present, in-progress gone (root probe)" \
    'v_vol_probe '"$d"' "test -e /w/.omd-labs-init-complete && test ! -e /w/.omd-labs-init-inprogress"'
v_teardown omd-s12i

# ---------------------------------------------------------------------------
# (ii) recovery sub-branch 2: version-link real tree (create had finished)
# -> `omd enable` branch. The pre-existing GENERATED credential (from the
# aborted boot's omd create) is INVALIDATED: old-pw login fails, value wins.
# ---------------------------------------------------------------------------
v_note "--- (ii) recovery, version-link (omd enable branch, old credential invalidated)"
d2=$(fx_d6_interrupted "$SITE" version-link)
# SEED A KNOWN old password into the fixture's generated htpasswd entry so
# the invalidation oracle is a LOGIN PAIR, not a hash-text comparison:
# htpasswd rewrites the salt/hash even for the SAME password, so "new hash
# != old hash" alone cannot prove the old password is dead (codex F1).
# Root-side htpasswd -b (same idiom as (iii)/(iv); -b keeps the value out of
# the host shell's process listing; the value is a known test constant).
PW_OLD=knownoldpw
B64_OLD=$(printf '%s' "omdadmin:$PW_OLD" | base64 -w0)
v_vol_probe "$d2" "htpasswd -b /w/etc/htpasswd omdadmin $PW_OLD" >/dev/null
v_check "(ii) pre-state: the KNOWN old credential is seeded (root probe)" \
    'v_vol_probe '"$d2"' "grep -q \"^omdadmin:\" /w/etc/htpasswd"'
old_hash=$(v_vol_probe "$d2" "grep -x 'omdadmin:.*' /w/etc/htpasswd")
# the htpasswd hash carries $ ($apr1$...) - in the eval string's double-quoted
# context it would be parsed as a variable reference: backslash-escape every
# $ (a $$ there would expand to the PID - the WRONG escape)
old_hash_eval=$(printf '%s' "$old_hash" | sed 's/\$/\\$/g')
v_run omd-s12ii "$IMAGE" "$P" "" -e SITENAME=$SITE -e OMD_ADMIN_PASSWORD="$PW_A" $(v_vol "$d2" /omd/sites/$SITE z)
v_check "(ii) readiness" \
    'set +e; rt=$(v_wait_ready omd-s12ii '"$P"' /'"$SITE"'/); rc=$?; echo "ready-time=${rt}s"; exit $rc'
v_check "(ii) recovery banner + the version-link re-registration line" \
    'v_wait_log omd-s12ii "recovery: creation had completed (version link) - re-registered"'
v_check "(ii) login with the environment value succeeds" \
    'set +e; wc=$(curl -sk -H "Authorization: Basic '"$B64_A"'" -o /dev/null -w "%{http_code}" --max-time 8 "https://127.0.0.1:'"$P"'/'"$SITE"'/thruk/"); echo "with-cred=$wc"; [ "$wc" = 200 ]'
v_check "(ii) the SEEDING credential is now REJECTED: the pre-existing generated credential is INVALIDATED (old-pw login 302; the env value logs in - primary oracle)" \
    'set +e; wc=$(curl -sk -H "Authorization: Basic '"$B64_OLD"'" -o /dev/null -w "%{http_code}" --max-time 8 "https://127.0.0.1:'"$P"'/'"$SITE"'/thruk/"); echo "old-pw=$wc"; [ "$wc" = 302 ]'
[ -n "$old_hash" ] || { echo "S12 (ii): seeded htpasswd entry missing - cannot compare" >&2; exit 1; }
# (explicit || exit 1 on EVERY failing path - the && / || result is what
# v_check's eval sees as rc; no bare final test whose failure is swallowed)
v_check "(ii) the htpasswd entry was REPLACED (new non-empty, different from the SEEDING entry, root probe)" \
    'set +e; new=$(v_vol_probe '"$d2"' "grep -x \"omdadmin:.*\" /w/etc/htpasswd") || exit 1; [ -n "$new" ] || exit 1; [ "$new" != "'"$old_hash_eval"'" ] || exit 1'
v_check "(ii) anonymous access stays 302 (no anonymous bypass introduced)" \
    'set +e; ac=$(curl -sk -o /dev/null -w "%{http_code}" --max-time 8 "https://127.0.0.1:'"$P"'/'"$SITE"'/thruk/"); echo "anon=$ac"; [ "$ac" = 302 ]'
v_check "(ii) notice present" \
    '_lg=$($RUNTIME logs omd-s12ii 2>/dev/null); n=$(echo "$_lg" | grep -Fc "$NOTICE"); [ "$n" = 1 ]'
v_teardown omd-s12ii

# ---------------------------------------------------------------------------
# (iii) protection boundary: persisted volume (COMPLETE present + STALE
# INPROG) + different value -> the STORED credential wins; the stale marker
# is removed after validation (resume path); htpasswd UNCHANGED.
# ---------------------------------------------------------------------------
v_note "--- (iii) persisted (stale INPROG), stored wins"
d3=$(fx_persisted_stale_marker "$SITE")
# a KNOWN stored credential (root-side update of the golden's generated
# entry - set_admin_password's exact tool invocation minus the HOME; the
# golden tree is complete, so the resume path takes no omd mutation before
# the asserts)
v_vol_probe "$d3" "htpasswd -b /w/etc/htpasswd omdadmin $PW_D" >/dev/null
ht3_before=$(v_vol_probe "$d3" "sha256sum /w/etc/htpasswd" | cut -d' ' -f1)
v_run omd-s12iii "$IMAGE" "$P" "" -e SITENAME=$SITE -e OMD_ADMIN_PASSWORD="$PW_C" $(v_vol "$d3" /omd/sites/$SITE z)
v_check "(iii) readiness (resume, not recovery)" \
    'set +e; rt=$(v_wait_ready omd-s12iii '"$P"' /'"$SITE"'/); rc=$?; echo "ready-time=${rt}s"; exit $rc'
v_check "(iii) log shows 'resumed existing site $SITE' (persisted row, not re-creation)" \
    '_lg=$($RUNTIME logs omd-s12iii 2>/dev/null); case "$_lg" in *"resumed existing site $SITE"*) ;; *) exit 1;; esac'
v_check "(iii) stale in-progress marker REMOVED (root probe)" \
    'v_vol_probe '"$d3"' "test ! -e /w/.omd-labs-init-inprogress"'
v_check "(iii) NO notice (no creation tail ran; hardened read)" \
    '_lg=$($RUNTIME logs omd-s12iii 2>/dev/null) || exit 1; case "$_lg" in *"omd-labs-entry:"*) ;; *) exit 1;; esac; n=$(echo "$_lg" | grep -Fc "$NOTICE" || true); [ "$n" = 0 ]'
v_check "(iii) the STORED credential logs in" \
    'set +e; wc=$(curl -sk -H "Authorization: Basic '"$B64_D"'" -o /dev/null -w "%{http_code}" --max-time 8 "https://127.0.0.1:'"$P"'/'"$SITE"'/thruk/"); echo "stored=$wc"; [ "$wc" = 200 ]'
v_check "(iii) the NEW value is REJECTED (302)" \
    'set +e; wc=$(curl -sk -H "Authorization: Basic '"$B64_C"'" -o /dev/null -w "%{http_code}" --max-time 8 "https://127.0.0.1:'"$P"'/'"$SITE"'/thruk/"); echo "new=$wc"; [ "$wc" = 302 ]'
v_check "(iii) htpasswd UNCHANGED (sha256, root probe)" \
    '[ "$(v_vol_probe '"$d3"' "sha256sum /w/etc/htpasswd" | cut -d" " -f1)" = "'"$ht3_before"'" ]'
v_teardown omd-s12iii

# ---------------------------------------------------------------------------
# (iv) protection boundary: ADOPTED legacy (complete real tree, NO markers)
# + different value -> the STORED credential wins; the adopt path is
# credential-blind.
# ---------------------------------------------------------------------------
v_note "--- (iv) adopted legacy, stored wins"
d4="$FIXDIR/s12-adapted-$SITE"
fx_real_site_tree "$SITE" "$FIX_UID" "$FIX_GID" "$d4"
# a KNOWN stored credential (root-side, same reasoning as (iii))
v_vol_probe "$d4" "htpasswd -b /w/etc/htpasswd omdadmin $PW_D" >/dev/null
ht4_before=$(v_vol_probe "$d4" "sha256sum /w/etc/htpasswd" | cut -d' ' -f1)
v_run omd-s12iv "$IMAGE" "$P" "" -e SITENAME=$SITE -e OMD_ADMIN_PASSWORD="$PW_C" $(v_vol "$d4" /omd/sites/$SITE z)
v_check "(iv) readiness (adopt path starts the site)" \
    'set +e; rt=$(v_wait_ready omd-s12iv '"$P"' /'"$SITE"'/); rc=$?; echo "ready-time=${rt}s"; exit $rc'
v_check "(iv) prominent 'adopted existing site' banner" \
    'v_wait_log omd-s12iv "adopted existing site '"$SITE"' (no init marker - legacy/pre-marker volume)"'
v_check "(iv) NO notice (the credential step is absent from adopt_site; hardened read)" \
    '_lg=$($RUNTIME logs omd-s12iv 2>/dev/null) || exit 1; case "$_lg" in *"omd-labs-entry:"*) ;; *) exit 1;; esac; n=$(echo "$_lg" | grep -Fc "$NOTICE" || true); [ "$n" = 0 ]'
v_check "(iv) the STORED credential logs in" \
    'set +e; wc=$(curl -sk -H "Authorization: Basic '"$B64_D"'" -o /dev/null -w "%{http_code}" --max-time 8 "https://127.0.0.1:'"$P"'/'"$SITE"'/thruk/"); echo "stored=$wc"; [ "$wc" = 200 ]'
v_check "(iv) the NEW value is REJECTED (302)" \
    'set +e; wc=$(curl -sk -H "Authorization: Basic '"$B64_C"'" -o /dev/null -w "%{http_code}" --max-time 8 "https://127.0.0.1:'"$P"'/'"$SITE"'/thruk/"); echo "new=$wc"; [ "$wc" = 302 ]'
v_check "(iv) htpasswd UNCHANGED (sha256, root probe)" \
    '[ "$(v_vol_probe '"$d4"' "sha256sum /w/etc/htpasswd" | cut -d" " -f1)" = "'"$ht4_before"'" ]'
v_teardown omd-s12iv

# ---------------------------------------------------------------------------
# (j) failure injection at the CREDENTIAL step of the FRESH tail.
# TEST-ONLY sub-build (S6 d-injected pattern): sed appends a sentinel +
# named-cause fatal line + exit 1 AFTER the unique PRE-COMMIT anchor
# "complete marker, then remove the in-progress marker" (which immediately
# precedes touch "$COMPLETE") - the injection lands BETWEEN the credential
# step and the commit, so: exit 1, entry-fatal present WITHOUT the value,
# COMPLETE absent, INPROG RETAINED (T027: the rollback retains the
# provenance marker), and the retry completes the creation. The fatal line
# mirrors run_bounded's format ("step failed (rc=N): <desc>") with a
# deterministic rc=99 and NEVER carries the value.
# ---------------------------------------------------------------------------
v_note "--- (j) fresh tail: injected failure at the credential step"
DFJ="$FIXDIR/Dockerfile-s12-fresh-inj"
{
    echo "FROM $IMAGE"
    echo "RUN sed -i '/complete marker, then remove the in-progress marker/a echo \"FATAL: step failed (rc=99): set omdadmin web password\" >&2; { mkdir -p /var/log/omd-labs; echo \"FATAL: step failed (rc=99): set omdadmin web password\" > /var/log/omd-labs/entry-fatal; } 2>/dev/null; touch /var/log/omd-labs/.s12-fresh-inj 2>/dev/null; exit 1   # TEST-ONLY injected failure at the fresh credential step (pre-commit)' /usr/local/bin/omd-labs-entry"
} >"$DFJ"
$RUNTIME build -f "$DFJ" -t local/omd-s12-fresh-inj -q . >/dev/null
d5="$FIXDIR/s12inj-fresh"
mkdir -p "$d5"
v_vol_wipe "$d5" || true
cname=omd-s12j-inj
v_run "$cname" local/omd-s12-fresh-inj "$P" "" -e SITENAME=$SITE -e OMD_ADMIN_PASSWORD="$PW_A" $(v_vol "$d5" /omd/sites/$SITE z)
t=0
while (( t < 180 )); do
    running=$($RUNTIME inspect -f '{{.State.Running}}' "$cname" 2>/dev/null || echo false)
    [ "$running" = "false" ] && break; sleep 2; t=$((t + 2))
done
code=$($RUNTIME inspect -f '{{.State.ExitCode}}' "$cname" 2>/dev/null || echo running)
v_check "(j) failure at the fresh credential step ? exit 1 (code=$code)" \
    '[ "$code" = "1" ]'
v_fatal "$cname" "FATAL: step failed (rc=99): set omdadmin web password"
v_check "(j) the injected line was REACHED (sentinel present, cp from stopped container)" \
    'set +e; '"$RUNTIME"' cp '"$cname"':/var/log/omd-labs/.s12-fresh-inj '"$FIXDIR"'/s12-fresh-inj-sentinel && [ -e '"$FIXDIR"'/s12-fresh-inj-sentinel ]'
v_check "(j) the credential step had SUCCEEDED before the injection (notice present, value NOT in it)" \
    '_lg=$($RUNTIME logs $cname 2>/dev/null); n=$(echo "$_lg" | grep -Fc "$NOTICE"); m=$(echo "$_lg" | grep -Fc "$PW_A" || true); [ "$n" = 1 ] && [ "$m" = 0 ]'
v_check "(j) the password value ABSENT from entry-fatal AND the container log (hardened: fresh copy, cp+read must succeed)" \
    'set +e; rm -f '"$FIXDIR"'/s12-j-entry-fatal; "$RUNTIME" cp $cname:/var/log/omd-labs/entry-fatal '"$FIXDIR"'/s12-j-entry-fatal || exit 1; _lg=$("$RUNTIME" logs $cname 2>/dev/null) || exit 1; case "$_lg" in *"omd-labs-entry:"*) ;; *) exit 1;; esac; f="$_lg $(cat '"$FIXDIR"'/s12-j-entry-fatal)"; n=$(echo "$f" | grep -Fc "$PW_A" || true); [ "$n" = 0 ]'
v_check "(j) COMPLETE marker ABSENT (the commit never ran, root probe)" \
    'v_vol_probe '"$d5"' "test ! -e /w/.omd-labs-init-complete"'
v_check "(j) INPROG marker RETAINED (retry re-enters the creation lifecycle, root probe)" \
    'v_vol_probe '"$d5"' "test -e /w/.omd-labs-init-inprogress"'
v_note "(j) no site service could be up: the entry fatals PRE-init (before exec /sbin/init) - the named cause IS the proof nothing was started"
v_teardown "$cname"
# retry: the NORMAL image completes the creation (recovery branch, INPROG)
v_run omd-s12j-retry "$IMAGE" "$P" "" -e SITENAME=$SITE -e OMD_ADMIN_PASSWORD="$PW_A" $(v_vol "$d5" /omd/sites/$SITE z)
v_check "(j) retry completes: ready (gate + /$SITE/)" \
    'set +e; rt=$(v_wait_ready omd-s12j-retry '"$P"' /'"$SITE"'/); rc=$?; echo "ready-time=${rt}s"; exit $rc'
v_check "(j) retry: login with the value succeeds" \
    'set +e; wc=$(curl -sk -H "Authorization: Basic '"$B64_A"'" -o /dev/null -w "%{http_code}" --max-time 8 "https://127.0.0.1:'"$P"'/'"$SITE"'/thruk/"); echo "with-cred=$wc"; [ "$wc" = 200 ]'
v_check "(j) retry committed: complete marker + in-progress gone (root probe)" \
    'v_vol_probe '"$d5"' "test -e /w/.omd-labs-init-complete && test ! -e /w/.omd-labs-init-inprogress"'
v_teardown omd-s12j-retry

# ---------------------------------------------------------------------------
# (k) failure injection at the CREDENTIAL step of the RECOVERY tail
# (same pattern; the unique PRE-COMMIT anchor "re-enters recovery)").
# ---------------------------------------------------------------------------
v_note "--- (k) recovery tail: injected failure at the credential step"
DFK="$FIXDIR/Dockerfile-s12-rec-inj"
{
    echo "FROM $IMAGE"
    echo "RUN sed -i '/re-enters recovery)/a echo \"FATAL: step failed (rc=99): set omdadmin web password\" >&2; { mkdir -p /var/log/omd-labs; echo \"FATAL: step failed (rc=99): set omdadmin web password\" > /var/log/omd-labs/entry-fatal; } 2>/dev/null; touch /var/log/omd-labs/.s12-rec-inj 2>/dev/null; exit 1   # TEST-ONLY injected failure at the recovery credential step (pre-commit)' /usr/local/bin/omd-labs-entry"
} >"$DFK"
$RUNTIME build -f "$DFK" -t local/omd-s12-rec-inj -q . >/dev/null
# the recovery pre-state: INPROG-only, version link ABSENT (create --reuse
# branch) - the same fixture shape as (i)
d6=$(fx_d6_interrupted "$SITE" tree-only)
cname=omd-s12k-inj
v_run "$cname" local/omd-s12-rec-inj "$P" "" -e SITENAME=$SITE -e OMD_ADMIN_PASSWORD="$PW_A" $(v_vol "$d6" /omd/sites/$SITE z)
t=0
while (( t < 180 )); do
    running=$($RUNTIME inspect -f '{{.State.Running}}' "$cname" 2>/dev/null || echo false)
    [ "$running" = "false" ] && break; sleep 2; t=$((t + 2))
done
code=$($RUNTIME inspect -f '{{.State.ExitCode}}' "$cname" 2>/dev/null || echo running)
v_check "(k) failure at the recovery credential step ? exit 1 (code=$code)" \
    '[ "$code" = "1" ]'
v_fatal "$cname" "FATAL: step failed (rc=99): set omdadmin web password"
v_check "(k) the injected line was REACHED (sentinel present, cp from stopped container)" \
    'set +e; '"$RUNTIME"' cp '"$cname"':/var/log/omd-labs/.s12-rec-inj '"$FIXDIR"'/s12-rec-inj-sentinel && [ -e '"$FIXDIR"'/s12-rec-inj-sentinel ]'
v_check "(k) the credential step had SUCCEEDED before the injection (notice present, value NOT in it)" \
    '_lg=$($RUNTIME logs $cname 2>/dev/null); n=$(echo "$_lg" | grep -Fc "$NOTICE"); m=$(echo "$_lg" | grep -Fc "$PW_A" || true); [ "$n" = 1 ] && [ "$m" = 0 ]'
v_check "(k) the password value ABSENT from entry-fatal AND the container log (hardened: fresh copy, cp+read must succeed)" \
    'set +e; rm -f '"$FIXDIR"'/s12-k-entry-fatal; "$RUNTIME" cp $cname:/var/log/omd-labs/entry-fatal '"$FIXDIR"'/s12-k-entry-fatal || exit 1; _lg=$("$RUNTIME" logs $cname 2>/dev/null) || exit 1; case "$_lg" in *"omd-labs-entry:"*) ;; *) exit 1;; esac; f="$_lg $(cat '"$FIXDIR"'/s12-k-entry-fatal)"; n=$(echo "$f" | grep -Fc "$PW_A" || true); [ "$n" = 0 ]'
v_check "(k) COMPLETE marker ABSENT (the recovery never committed, root probe)" \
    'v_vol_probe '"$d6"' "test ! -e /w/.omd-labs-init-complete"'
v_check "(k) INPROG marker RETAINED (root probe)" \
    'v_vol_probe '"$d6"' "test -e /w/.omd-labs-init-inprogress"'
v_note "(k) no site service could be up: the entry fatals PRE-init - the named cause IS the proof nothing was started"
v_teardown "$cname"
v_run omd-s12k-retry "$IMAGE" "$P" "" -e SITENAME=$SITE -e OMD_ADMIN_PASSWORD="$PW_A" $(v_vol "$d6" /omd/sites/$SITE z)
v_check "(k) retry completes: ready (gate + /$SITE/)" \
    'set +e; rt=$(v_wait_ready omd-s12k-retry '"$P"' /'"$SITE"'/); rc=$?; echo "ready-time=${rt}s"; exit $rc'
v_check "(k) retry: login with the value succeeds" \
    'set +e; wc=$(curl -sk -H "Authorization: Basic '"$B64_A"'" -o /dev/null -w "%{http_code}" --max-time 8 "https://127.0.0.1:'"$P"'/'"$SITE"'/thruk/"); echo "with-cred=$wc"; [ "$wc" = 200 ]'
v_check "(k) retry committed: complete marker + in-progress gone (root probe)" \
    'v_vol_probe '"$d6"' "test -e /w/.omd-labs-init-complete && test ! -e /w/.omd-labs-init-inprogress"'
v_teardown omd-s12k-retry

# ---------------------------------------------------------------------------
# (l)/(m)/(n) the REAL production failure path - the credential TOOL is
# broken in a test-only sub-build (codex F2 05-codex-impl-review: the (j)/(k)
# injections above run AFTER the real setter succeeded and author their own
# fatal text, so they prove ordering/rollback only). Here the in-image
# set_admin_password is the thing that fails - the entry's run_bounded
# captures the REAL rc and calls the REAL fatal (production text, no test
# authoring of the entry-fatal file).
#
# Why breaking the tool (not runuser): omd create --reuse internally calls
# the SAME tool via set_admin_password_or_warn (omd.py:3191), which
# SWALLOWS the failure (warns, continues - omd create stays green). A broken
# runuser would instead fatal at that EARLIER step (wrong step, and
# customization OMDCFG_* keys also use runuser). Breaking the tool leaves the
# whole credential chain (entry -> runuser -u <site> -> the site's OWN
# version link) untouched and exactly the entry's explicit credential step
# failing: the production `run_bounded 30 "set omdadmin web password"
# runuser -u ... -- ${SITE_DIR}/version/bin/set_admin_password "$PW"` (entry
# :395 fresh / :752 recovery) is byte-identical across images.
#
# Injection: sed -i '/^#!/a <line>' on the version's tool file (the `default`
# link resolves to the single installed version - the entry's ${SITE_DIR}/
# version link and OMD's own internal call both hit the same file).
# (l) rc=99  : `echo s12-tool-fault && exit 99`  -> the rc!=124/137 branch
# (m) rc=124 : `sleep 45 && exit 130` (45s > the 30s bound) -> the DISTINCT
#             timeout branch (run_bounded :98-101)
# (n) retry  : (l)'s failed volume + the NORMAL image completes the creation
#             (the recovery omd-enable branch - omd create --reuse left the
#             version link) - a successful retry after a REAL tool failure.
# (j)/(k) are KEPT as the pre-commit ordering/rollback tests; (l)/(m)/(n)
# use their own fresh fixture dirs (no aliasing with (i)/(k)/(j)).
# ---------------------------------------------------------------------------
v_note "--- (l) fresh tail: the REAL tool fails (rc=99) - production run_bounded/fatal"
DFT="$FIXDIR/Dockerfile-s12-tool-fault"
# The sub-build OVERWRITES the version's set_admin_password with a fault
# body (printf, single-quoted format - no sed-anchor/escape surface):
#   1. writes a MARK FILE into the SITE HOME (runuser sets
#      HOME=/omd/sites/<site> - the same channel that puts the real
#      htpasswd there): a DETERMINISTIC, log-driver-independent proof the
#      fault body executed;
#   2. prints the fault line to the child's stdout (run_bounded replays
#      it into the entry stderr - observed manually, NOT asserted: on this
#      host the journald driver does not return a fail-fast container's
#      stderr tail through `podman logs` non-deterministically - EMPIRICAL
#      run6/run8);
#   3. exit 99 -> the REAL run_bounded rc!=124/137 branch + the REAL fatal.
# (The entry's own INVOCATION is proven by the run_bounded step line
# [stdout, reliable] + the rc=99 entry-fatal [file, reliable].)
cat >"$DFT" <<S12DF
FROM $IMAGE
RUN V=\$(readlink -f /opt/omd/versions/default) && printf '#!/bin/bash\nprintf s12-toolfault > \$HOME/.s12-toolfault-mark 2>/dev/null\necho s12-tool-fault\nexit 99\n' > "\$V/bin/set_admin_password"
S12DF
$RUNTIME build -f "$DFT" -t local/omd-s12-tool-fault -q . >/dev/null
d7="$FIXDIR/s12-toolfault-l"
mkdir -p "$d7"
v_vol_wipe "$d7" || true
cname=omd-s12l-tool
v_run "$cname" local/omd-s12-tool-fault "$P" "" -e SITENAME=$SITE -e OMD_ADMIN_PASSWORD="$PW_A" $(v_vol "$d7" /omd/sites/$SITE z) || exit 1
t=0
while (( t < 180 )); do
    running=$($RUNTIME inspect -f '{{.State.Running}}' "$cname" 2>/dev/null || echo false)
    [ "$running" = "false" ] && break; sleep 2; t=$((t + 2))
done
code=$($RUNTIME inspect -f '{{.State.ExitCode}}' "$cname" 2>/dev/null || echo running)
v_check "(l) the real tool failure -> exit 1 (code=$code)" \
    '[ "$code" = "1" ]'
# the named cause is PRODUCTION text (run_bounded :102), not test-authored
v_fatal "$cname" "FATAL: step failed (rc=99): set omdadmin web password"
v_check "(l) the credential step WAS invoked (the real run_bounded step line present, hardened read)" \
    '_lg=$($RUNTIME logs $cname 2>/dev/null) || exit 1; case "$_lg" in *"omd-labs-entry:"*) ;; *) exit 1;; esac; case "$_lg" in *"step: set omdadmin web password"*) ;; *) exit 1;; esac'
v_check "(l) the success notice is ABSENT (the setter did not succeed; hardened read)" \
    '_lg=$($RUNTIME logs $cname 2>/dev/null) || exit 1; case "$_lg" in *"omd-labs-entry:"*) ;; *) exit 1;; esac; n=$(echo "$_lg" | grep -Fc "$NOTICE" || true); [ "$n" = 0 ]'
v_check "(l) the value is ABSENT from entry-fatal AND the container log (non-disclosure on the real failure path; fresh copy, cp+read must succeed)" \
    'set +e; rm -f '"$FIXDIR"'/s12-l-entry-fatal; "$RUNTIME" cp $cname:/var/log/omd-labs/entry-fatal '"$FIXDIR"'/s12-l-entry-fatal || exit 1; _lg=$("$RUNTIME" logs $cname 2>/dev/null) || exit 1; case "$_lg" in *"omd-labs-entry:"*) ;; *) exit 1;; esac; f="$_lg $(cat '"$FIXDIR"'/s12-l-entry-fatal)"; n=$(echo "$f" | grep -Fc "$PW_A" || true); [ "$n" = 0 ]'
# the fault-body-executed proof via the VOLUME MARK (deterministic channel).
# NOT via the container log: on this host the journald driver does not
# return a fail-fast container's STDERR tail through `podman logs`
# non-deterministically - EMPIRICAL run6 (absent at t+2s) and run8 (absent
# after a full 30 s v_wait_log poll, while raw journalctl and attached stdio
# show the lines). The mark is written by the injected line into the site
# HOME (runuser HOME=/omd/sites/<site>) - the same channel as the real
# htpasswd, readable after teardown via the root probe.
v_check "(l) the fault body EXECUTED (the volume mark the injected line wrote, root probe)" \
    'v_vol_probe '"$d7"' "test -f /w/.s12-toolfault-mark"'
v_check "(l) COMPLETE marker ABSENT (the commit never ran, root probe)" \
    'v_vol_probe '"$d7"' "test ! -e /w/.omd-labs-init-complete"'
v_check "(l) INPROG marker RETAINED (the next boot re-enters the lifecycle, root probe)" \
    'v_vol_probe '"$d7"' "test -e /w/.omd-labs-init-inprogress"'
v_note "(l) no site service could be up: the entry fatals PRE-init (before exec /sbin/init) - the named cause IS the proof nothing was started"
v_teardown "$cname"

# (m) the DISTINCT timeout branch (run_bounded :99-101: rc 124/137 -> the
# "step timed out" stderr line + the step-failed fatal).
# The tool sleeps 45 s (the 30 s bound fires). rc is 137 when `runuser` is
# in the chain (the group TERM does not reach the tool, -k 1 escalates to
# SIGKILL - EMPIRICAL run5/accidental-run) and 124 for a plain child (the
# group TERM kills it - EMPIRICAL pre-build probe); the entry treats 124/137
# IDENTICALLY (:99), so the deterministic oracles are: the entry-fatal
# "FATAL: step failed (rc=124|137)" line (fixed-string dual -e match) + the
# step line showing the 30 s bound was applied. The "step timed out" stderr
# line is observed manually (attached stdio / journalctl) but NOT asserted:
# on this host the journald driver does not return a fail-fast container's
# stderr tail through `podman logs` non-deterministically (EMPIRICAL
# run6/run8 - absent after a full 30 s poll; the line IS in the journal).
# Same printf-overwrite mechanism as (l) - no sed escape surface.
v_note "--- (m) fresh tail: the REAL tool TIMES OUT (45s > the 30s bound)"
DHT="$FIXDIR/Dockerfile-s12-tool-hang"
cat >"$DHT" <<S12DF
FROM $IMAGE
RUN V=\$(readlink -f /opt/omd/versions/default) && printf '#!/bin/bash\nsleep 45\nexit 130\n' > "\$V/bin/set_admin_password"
S12DF
$RUNTIME build -f "$DHT" -t local/omd-s12-tool-hang -q . >/dev/null
d8="$FIXDIR/s12-toolfault-m"
mkdir -p "$d8"
v_vol_wipe "$d8" || true
cname=omd-s12m-tool
v_run "$cname" local/omd-s12-tool-hang "$P" "" -e SITENAME=$SITE -e OMD_ADMIN_PASSWORD="$PW_A" $(v_vol "$d8" /omd/sites/$SITE z) || exit 1
t=0
while (( t < 180 )); do
    running=$($RUNTIME inspect -f '{{.State.Running}}' "$cname" 2>/dev/null || echo false)
    [ "$running" = "false" ] && break; sleep 2; t=$((t + 2))
done
code=$($RUNTIME inspect -f '{{.State.ExitCode}}' "$cname" 2>/dev/null || echo running)
v_check "(m) the real tool timeout -> exit 1 (code=$code)" \
    '[ "$code" = "1" ]'
# entry-fatal carries the fatal() line with a TIMEOUT rc (124 group-TERM or
# 137 KILL-escalation - the entry treats both identically at :99). FIXED-STRING
# dual -e patterns (NOT a regex): an ERE with unescaped ( ) would not match the
# LITERAL (rc=137) text through the eval-escaping layer, and fixed strings are
# immune to that. The named step must be present with rc 124 OR 137 (not e.g. 99).
v_check "(m) entry-fatal carries the TIMEOUT rc (124 or 137) for the named step (fresh copy, cp+read must succeed)" \
    'set +e; rm -f '"$FIXDIR"'/s12-m-entry-fatal; "$RUNTIME" cp $cname:/var/log/omd-labs/entry-fatal '"$FIXDIR"'/s12-m-entry-fatal || exit 1; f=$(cat '"$FIXDIR"'/s12-m-entry-fatal) || exit 1; n=$(echo "$f" | grep -Fc -e "FATAL: step failed (rc=124): set omdadmin web password" -e "FATAL: step failed (rc=137): set omdadmin web password" || true); [ "$n" = 1 ]'
v_check "(m) the credential step WAS invoked (the real run_bounded step line present, hardened read)" \
    '_lg=$($RUNTIME logs $cname 2>/dev/null) || exit 1; case "$_lg" in *"omd-labs-entry:"*) ;; *) exit 1;; esac; case "$_lg" in *"step: set omdadmin web password"*) ;; *) exit 1;; esac'
v_check "(m) the value is ABSENT from entry-fatal AND the container log (fresh copy, cp+read must succeed)" \
    'set +e; rm -f '"$FIXDIR"'/s12-m-entry-fatal; "$RUNTIME" cp $cname:/var/log/omd-labs/entry-fatal '"$FIXDIR"'/s12-m-entry-fatal || exit 1; _lg=$("$RUNTIME" logs $cname 2>/dev/null) || exit 1; case "$_lg" in *"omd-labs-entry:"*) ;; *) exit 1;; esac; f="$_lg $(cat '"$FIXDIR"'/s12-m-entry-fatal)"; n=$(echo "$f" | grep -Fc "$PW_A" || true); [ "$n" = 0 ]'
v_check "(m) COMPLETE marker ABSENT (the commit never ran, root probe)" \
    'v_vol_probe '"$d8"' "test ! -e /w/.omd-labs-init-complete"'
v_check "(m) INPROG marker RETAINED (root probe)" \
    'v_vol_probe '"$d8"' "test -e /w/.omd-labs-init-inprogress"'
v_teardown "$cname"

# (n) RETRY after a real tool failure: (l)'s failed volume (INPROG present,
# COMPLETE absent, omd create --reuse had completed -> version link present)
# + the NORMAL image -> recovery omd-enable branch, the real (unbroken) tool
# sets the value, the creation commits.
v_note "--- (n) retry after the real (l) failure: the normal image completes the creation"
v_run omd-s12n-retry "$IMAGE" "$P" "" -e SITENAME=$SITE -e OMD_ADMIN_PASSWORD="$PW_A" $(v_vol "$d7" /omd/sites/$SITE z) || exit 1
v_check "(n) readiness (recovery completes, gate active + /$SITE/)" \
    'set +e; rt=$(v_wait_ready omd-s12n-retry '"$P"' /'"$SITE"'/); rc=$?; echo "ready-time=${rt}s"; exit $rc'
v_check "(n) the value is now the effective credential (login 200)" \
    'set +e; wc=$(curl -sk -H "Authorization: Basic '"$B64_A"'" -o /dev/null -w "%{http_code}" --max-time 8 "https://127.0.0.1:'"$P"'/'"$SITE"'/thruk/"); echo "with-cred=$wc"; [ "$wc" = 200 ]'
v_check "(n) notice present exactly once (the creation tail ran, hardened read)" \
    '_lg=$($RUNTIME logs omd-s12n-retry 2>/dev/null) || exit 1; case "$_lg" in *"omd-labs-entry:"*) ;; *) exit 1;; esac; n=$(echo "$_lg" | grep -Fc "$NOTICE"); [ "$n" = 1 ]'
v_check "(n) committed: complete marker present, in-progress gone (root probe)" \
    'v_vol_probe '"$d7"' "test -e /w/.omd-labs-init-complete && test ! -e /w/.omd-labs-init-inprogress"'
v_teardown omd-s12n-retry

v_note "sub-items (a)-(e), (i)-(iv), (j), (k), (l), (m), (n) done"
v_end
