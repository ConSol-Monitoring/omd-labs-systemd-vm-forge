#!/usr/bin/env bash
# S3b - SSH end-to-end with provisioned credentials (US4 sc6; SC-004; FR-003)
# (a) valid key :ro -> ssh e2e as root, dest 700/644 root root, source
#     NEVER mutated (owner/mode/mtime+size + sha256, B2/NOTE3);
# (b) malformed / empty / comment-only key -> exit 1 <=30 s each, fatal
#     names the file (3 fail-fast variants, one container each, NO host
#     port - a fail-fast container needs none);
# (c) no key -> sshd active + listening on 22, login REFUSED by that sshd
#     (documented expected state - FR-003: no baked secret).
# Ports (v_port s3b; a host port may never map to 443 and 22 at once -
# codex B2; and a port may not be reused while its container still runs -
# codex B2-round-69: (a) is torn down BEFORE (c) reuses 18455):
#   a: 443=18454 22=18455 -> teardown -> c: 443=18455 22=18456
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/common.sh"

P=$(v_port s3b 0)      # 18454: run (a) HTTPS
PA_SSH=$((P + 1))      # 18455: run (a) SSH
PC=$((P + 1))          # 18455: run (c) HTTPS (reused AFTER (a)+(b) teardown)
PC_SSH=$((P + 2))      # 18456: run (c) SSH (negative login test targets
                       # THIS sshd, not the HTTPS port - codex B2-69)

v_begin "S3b-$SCEN-$DISTRO"
. "$VER_DIR/fixtures.sh"

KEYPUB=$(fx_ssh_keypair)
BADKEY=$(fx_bad_key)

# NOTE (codex-69): SELinux needs a SINGLE comma-separated options field
# ("ro,z") - ":ro:z" is an invalid bind-mount spec (suite convention s7:
# ':ro,z'; s2's SELABEL glues its own colon onto the helper, never onto
# a ':ro' suffix).
KEYMNT="${KEYPUB}:/root/.ssh/omd_ssh_keys:ro${SELABEL:+,z}"

# --- (a) key provisioned (documented :ro form - source NEVER mutated) ---
src_meta_before=$(stat -c '%U:%G %a %Y %s' "$KEYPUB" 2>/dev/null || echo unknown)
src_sum_before=$(sha256sum "$KEYPUB" | awk '{print $1}')
v_run omd-s3b "$IMAGE" "$P" "$PA_SSH" -v "$KEYMNT"
v_check "(a) readiness (gate active + 443)" \
    'set +e; rt=$(v_wait_ready omd-s3b '"$P"' /); rc=$?; echo "ready-time=${rt}s"; exit $rc'
v_check "(a) SSH login succeeds end-to-end as root (whoami=root)" \
    "ssh -i /tmp/omd-test-key -o StrictHostKeyChecking=no -o BatchMode=yes -p $PA_SSH root@127.0.0.1 'whoami' | grep -qx root"
v_check "(a) /root/.ssh = 700 root root (image-owned dir, install -d)" \
    "$RUNTIME exec omd-s3b stat -c '%a %U %G' /root/.ssh | grep -qx '700 root root'"
v_check "(a) /root/.ssh/authorized_keys = 644 root root (image-owned copy)" \
    "$RUNTIME exec omd-s3b stat -c '%a %U %G' /root/.ssh/authorized_keys | grep -qx '644 root root'"
src_meta_after=$(stat -c '%U:%G %a %Y %s' "$KEYPUB")
src_sum_after=$(sha256sum "$KEYPUB" | awk '{print $1}')
v_check "(a) :ro bind source untouched - owner/mode/mtime+size (before='$src_meta_before')" \
    '[ "'"$src_meta_after"'" = "'"$src_meta_before"'" ]'
v_check "(a) :ro bind source untouched - sha256 (before=$src_sum_before)" \
    '[ "'"$src_sum_after"'" = "'"$src_sum_before"'" ]'
# TEARDOWN (a) BEFORE any port reuse (codex B2-69): (c) reuses 18455 for
# its HTTPS port; the port must be free first.
v_stop omd-s3b >/dev/null || true
$RUNTIME rm -f omd-s3b >/dev/null 2>&1 || true

# --- (b) broken key file ? fail-fast (3 variants, one container each) ---
# the entry writes /var/log/omd-labs/entry-fatal (overlay) before exit 1 -
# readable via v_fatal even after the container stopped.
for i in 1 2 3; do
    case $i in
        1) f="$BADKEY"; lbl=badkey ;;
        2) f="$FIXDIR/badkey-empty"; : >"$f"; lbl=empty ;;
        3) f="$FIXDIR/badkey-commentonly"; printf '# only comments here\n\n# nothing else\n' >"$f"; lbl=commentonly ;;
    esac
    cname="omd-s3b-bad$i"
    # timer per variant (codex NOTE-69: a shared start would measure
    # cumulative runtime and falsely fail later cases)
    bstart=$(date +%s)
    set +e
    $RUNTIME rm -f "$cname" >/dev/null 2>&1 || true
    $RUNTIME run --name "$cname" $(v_flags) $(v_suite_label) -d \
        -v "$f:/root/.ssh/omd_ssh_keys:ro${SELABEL:+,z}" "$IMAGE" >/dev/null 2>&1
    set -e
    t=0
    while (( t < 45 )); do
        running=$($RUNTIME inspect -f '{{.State.Running}}' "$cname" 2>/dev/null || echo false)
        [ "$running" = "false" ] && break
        sleep 1; t=$((t + 1))
    done
    elapsed=$(( $(date +%s) - bstart ))
    code=$($RUNTIME inspect -f '{{.State.ExitCode}}' "$cname" 2>/dev/null || echo unknown)
    v_check "(b$i=$lbl) broken key -> exit 1 <=30 s (elapsed=${elapsed}s code=$code)" \
        'set +e; [ '"$elapsed"' -le 30 ] && [ '"$code"' = 1 ]'
    v_check "(b$i=$lbl) fatal reason names the key file (entry-fatal file)" \
        "v_fatal $cname 'SSH public key file at /root/.ssh/omd_ssh_keys'"
done

# --- (c) no key ? sshd up + listening, login REFUSED (documented state) ---
v_run omd-s3b-nokey "$IMAGE" "$PC" "$PC_SSH"
v_check "(c) readiness (gate active + 443)" \
    'set +e; rt=$(v_wait_ready omd-s3b-nokey '"$PC"' /); rc=$?; echo "ready-time=${rt}s"; exit $rc'
v_check "(c) sshd active + listening on 22" \
    "$RUNTIME exec omd-s3b-nokey sh -c 'systemctl is-active $SSH_UNIT | grep -qx active && ss -ltn | grep -qE \":22 \"'"
# negative test: the client connects to the MAPPED SSH port 18456 -> the
# container's sshd; with no provisioned key and no baked secret the login
# must be REFUSED (not just unreachable). A refused auth attempt exits
# non-zero with an auth error; a connection failure would also exit
# non-zero, so assert BOTH that the port answers AND that ssh failed:
# offers the ACTUAL fixture key (the one (a) accepted) with IdentitiesOnly:
# the refusal must be of THIS credential by THIS sshd, not of an anonymous
# attempt (codex NOTE-71: PreferredAuthentications=none never offered the
# key and would pass even if the container retained the authorized key)
ssh_rc=0
ssh_err=$(ssh -i /tmp/omd-test-key -o IdentitiesOnly=yes -o StrictHostKeyChecking=no -o BatchMode=yes -o ConnectTimeout=5 -o PreferredAuthentications=publickey -p "$PC_SSH" root@127.0.0.1 true 2>&1) || ssh_rc=$?
v_check "(c) no login possible - sshd refuses (port 18456 answers, auth refused; rc=$ssh_rc)" \
    'set +e; [ '"$ssh_rc"' -ne 0 ] && echo "'"$ssh_err"'" | grep -qEi "refused|denied|no more authentication|not allowed" && ! echo "'"$ssh_err"'" | grep -qEi "connection refused|timed out|no route|could not resolve"'

v_teardown omd-s3b omd-s3b-bad1 omd-s3b-bad2 omd-s3b-bad3 omd-s3b-nokey
v_end
