#!/usr/bin/env bash
# S11b - Base runtime/derived install smoke (Stage 2, 99-consensus B6; gates
# candidate publication). The base image's PRODUCT CLAIM: its labs.consol.de
# repos let an OMD package be installed and yield a WORKING site image. The
# reproducible variant (build-time install on the base) is exercised here:
#   FROM <base> + install_omd.sh (stable omd-labs-edition) + vendor
#   normalization + alias re-assert  =>  derived image
# then the derived image boots with SITENAME and reaches site readiness. This
# proves the base's repos are functional + the base is a valid foundation.
# (The manual runtime-install path - install in a live container, then
# daemon-reload + enable before site start - is the operator variant; the
# build-time path is the preferred reproducible one.)
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/common.sh"
# a generous bound: the derived image installs OMD (a couple of minutes) and
# then boots a site.
export READY_DEADLINE="${READY_DEADLINE:-420}"

BASE_IMAGE=$(v_base_image "$DISTRO" "$TAG")
DERIVED="local/omd-labs-systemd-vm-s11b-$DISTRO:latest"
P=$(v_port s11b)
SSH_P=$((P + 1))
E=$EDGE_UNIT

v_begin "S11b-$SCEN-$DISTRO"
v_note "derived image (FROM $BASE_IMAGE + stable OMD): $DERIVED"

# build the derived image (no OMD in the base; install stable omd-labs-edition
# from the base's configured repos + vendor normalization + alias re-assert -
# the same steps the OMD Dockerfile stage performs). The derived Dockerfile is
# written to a temp file (NOT a heredoc inside v_check's eval - that would not
# parse reliably); v_check then just runs the build against it.
case "$DISTRO" in
    rocky)  NORM='rm -f /etc/systemd/system/omd.service /etc/systemd/system/multi-user.target.wants/omd.service && systemctl enable omd-site.service omd-ready.service sshd httpd crond';;
    debian) NORM='rm -f /etc/systemd/system/omd.service /etc/systemd/system/multi-user.target.wants/omd.service && systemctl enable omd-site.service omd-ready.service ssh apache2 cron';;
esac
DFILE=$(mktemp /tmp/s11b-der-XXXXXX.Dockerfile)
cat > "$DFILE" <<DEREOF
FROM $BASE_IMAGE
ADD ./scripts/install_omd.sh /tmp/install_omd.sh
RUN chmod +x /tmp/install_omd.sh && /tmp/install_omd.sh $DISTRO latest \
    && $NORM \
    && test -L /etc/systemd/system/omd.service \
    && test "\$(readlink -f /etc/systemd/system/omd.service)" = /usr/lib/systemd/system/omd-site.service
DEREOF
v_check "build derived image (base + stable OMD package from the base's repos)" \
    '"$RUNTIME" build --quiet -t '"$DERIVED"' -f '"$DFILE"' . && rm -f '"$DFILE"''

v_run omd-s11b "$DERIVED" "$P" "$SSH_P" -e SITENAME=s11b

v_check "site readiness within bound (gate active + /s11b 2xx/3xx)" \
    '(set +e; rt=$(v_wait_ready omd-s11b '"$P"' "/s11b"); rc=$?; echo "ready-time=${rt}s rc=$rc"; exit $rc)'

v_check "omd is now present (installed from the base's repos)" \
    '"$RUNTIME" exec omd-s11b sh -c "test -x /usr/bin/omd" && echo "omd present"'

v_check "/s11b answers 2xx/3xx (site UI / login redirect)" \
    '_c=$(curl -sk -o /dev/null -w "%{http_code}" --max-time 5 "https://127.0.0.1:'"$P"'/s11b/"); echo "code=$_c"; case "$_c" in 2*|3*) ;; *) exit 1;; esac'

# capture the status text as evidence AND the real exit code: `rc=$(cmd; echo $?)`
# is wrong - the substitution would capture cmd's OUTPUT plus the echoed 0 as
# $rc. Assignment status = the command's rc, so take $? right after the
# assignment (set +e so a failing exec does not abort the check before it
# records evidence).
v_check "omd status s11b rc 0 (site running)" \
    '(set +e; out=$('"$RUNTIME"' exec omd-s11b omd status s11b); rc=$?; echo "$out"; echo "omd status rc=$rc"; [ "$rc" = "0" ])'

# clean stop contract (contrast verify/baseline.md)
rc=$(v_stop omd-s11b)
code=$(v_exited_code omd-s11b)
v_check "clean stop -t 30 ends 130/0, not 137 (exit code: $code, stop rc: $rc)" \
    'case '"$code"' in 130|0) ;; *) exit 1;; esac'

v_teardown omd-s11b
v_note "teardown done (derived image $DERIVED retained for inspection)"
v_end
