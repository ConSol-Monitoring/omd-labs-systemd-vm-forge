#!/usr/bin/env bash
#
# omd-pipeline-webhook.sh
# =======================
# Trigger the OMD Labs image publish (ConSol-Monitoring/omd-labs-systemd-vm-forge)
# from the OMD build/release pipeline, after a package has been published to
# labs.consol.de. It posts a GitHub `repository_dispatch` event that the image
# repo's publish workflow (.github/workflows/publish.yml) listens for.
#
# This script is the CALLER side. It authenticates with an org-owned GitHub App
# installed ONLY on the image repo (NOT a personal token): it mints a short-lived
# app JWT, then a 1-hour installation token, and posts the event with that token.
#
# --------------------------------------------------------------------------
# WEBHOOK PARAMETERS (what publish.yml consumes)
# --------------------------------------------------------------------------
#   Endpoint   : POST https://api.github.com/repos/<owner>/<repo>/dispatches
#   Auth       : Authorization: Bearer <installation token>
#   Body       : { "event_type": "omd-published",
#                  "client_payload": { "omd_version": "<value>" } }
#
#   event_type  : fixed "omd-published" — must match publish.yml's
#                 `on: repository_dispatch: types:` (a dispatch to a repo with
#                 no listener on the DEFAULT branch is dropped).
#
#   omd_version : which OMD package/channel to build. It is mapped by the image
#                 repo's scripts/install_omd.sh:
#
#     value            channel   package installed              image tag
#     ---------------  --------  -----------------------------  -----------
#     master           testing   omd-labs-edition-daily         :nightly
#                             (the CURRENT daily build, e.g.
#                              omd-5.81.20261115-labs-edition)
#     latest           stable    omd-labs-edition               :latest
#                             (newest stable, e.g. 5.80)
#     5.81  (v5.81)    stable    omd-5.81-labs-edition          :v5.81
#
#     Friendly aliases accepted by THIS script (translated before posting):
#       stable | latest          -> latest
#       testing|nightly|master|daily -> master
#       v5.81 / 5.81            -> 5.81
#
#     NOTE: a specific date-stamped daily (e.g. 5.81.20261115) is NOT a
#     separate omd_version — it is exactly what the `master`/testing channel
#     resolves to at build time. To build "today's nightly", send master.
#
#   HTTP 204   : the event was ACCEPTED. This is NOT a build-success signal —
#                the actual build/publish result shows up in the Actions run
#                (https://github.com/<owner>/<repo>/actions).
#
# --------------------------------------------------------------------------
# CREDENTIALS (org-owned GitHub App — never a personal token)
# --------------------------------------------------------------------------
#   App ID  : env OMD_WEBHOOK_APP_ID  or  --app-id <id>
#   App PEM : env OMD_WEBHOOK_APP_PEM or  --pem <file-or-inline>
#             (a path to the private-key .pem, or the PEM contents inline)
#   (opt.)  installation id: env OMD_WEBHOOK_INSTALLATION_ID or
#             --installation-id <id> — auto-discovered if omitted.
#
# --------------------------------------------------------------------------
# USAGE
# --------------------------------------------------------------------------
#   # build today's nightly (testing/daily):
#   OMD_WEBHOOK_APP_ID=5772253 OMD_WEBHOOK_APP_PEM=/path/key.pem \
#     ./omd-pipeline-webhook.sh --omd-version testing
#
#   # build the newest stable:
#   ./omd-pipeline-webhook.sh --app-id 5772253 --pem /path/key.pem \
#     --omd-version stable
#
#   # build a specific versioned stable release:
#   ./omd-pipeline-webhook.sh --app-id 5772253 --pem /path/key.pem \
#     --omd-version 5.81
#
#   # verify credentials without posting (mints JWT + token, stops):
#   ./omd-pipeline-webhook.sh --app-id 5772253 --pem /path/key.pem --check
#
#   # show what would be sent, without any API calls:
#   ./omd-pipeline-webhook.sh --app-id 5772253 --pem /path/key.pem \
#     --omd-version 5.81 --dry-run
#
# Requires: bash, curl, openssl, python3
#
set -euo pipefail

# ---------- configuration (overridable) -----------------------------------
REPO="${OMD_WEBHOOK_REPO:-ConSol-Monitoring/omd-labs-systemd-vm-forge}"
API="${OMD_WEBHOOK_API:-https://api.github.com}"
EVENT_TYPE="${OMD_WEBHOOK_EVENT:-omd-published}"
APP_ID="${OMD_WEBHOOK_APP_ID:-}"
APP_PEM="${OMD_WEBHOOK_APP_PEM:-}"
INSTALL_ID="${OMD_WEBHOOK_INSTALLATION_ID:-}"
OMD_VERSION="${OMD_WEBHOOK_OMD_VERSION:-}"

CHECK=0
DRY_RUN=0
TMP_FILES=()
cleanup() { rm -f "${TMP_FILES[@]}" 2>/dev/null || true; }
trap cleanup EXIT

usage() {
  cat <<'EOF'
omd-pipeline-webhook.sh — trigger the OMD Labs image publish from the OMD build
pipeline by posting a GitHub repository_dispatch event.

Usage:
  ./omd-pipeline-webhook.sh --omd-version <value> [options]

Credentials (org-owned GitHub App, NOT a personal token):
  --app-id <id>            GitHub App ID            (or env OMD_WEBHOOK_APP_ID)
  --pem <file|inline>      App private key          (or env OMD_WEBHOOK_APP_PEM)
  --installation-id <id>   (optional; auto-discovered if omitted)

Options:
  --omd-version <value>    master|latest|testing|stable|nightly|daily|X.YY
                           (or env OMD_WEBHOOK_OMD_VERSION)
  --repo <owner/name>      target repo (default ConSol-Monitoring/omd-labs-systemd-vm-forge)
  --event-type <type>      (default omd-published)
  --check                  verify credentials (JWT + installation + token) and stop
  --dry-run                print the plan + payload, no API calls
  -h, --help               this help

omd_version mapping (full table in the file header):
  master|testing|nightly|daily -> :nightly (testing/daily package)
  latest|stable                -> :latest  (newest stable)
  X.YY (e.g. 5.81)            -> :vX.YY   (versioned stable)

Requires: bash, curl, openssl, python3
EOF
}

# ---------- argument parsing ----------------------------------------------
while [ $# -gt 0 ]; do
  case "$1" in
    --app-id)            APP_ID="$2"; shift 2;;
    --pem)               APP_PEM="$2"; shift 2;;
    --omd-version)       OMD_VERSION="$2"; shift 2;;
    --installation-id)   INSTALL_ID="$2"; shift 2;;
    --repo)              REPO="$2"; shift 2;;
    --event-type)        EVENT_TYPE="$2"; shift 2;;
    --check)             CHECK=1; shift;;
    --dry-run)           DRY_RUN=1; shift;;
    -h|--help)           usage; exit 0;;
    *) echo "Unknown argument: $1" >&2; usage; exit 2;;
  esac
done

[ -n "$APP_ID" ]  || { echo "ERROR: APP ID missing (env OMD_WEBHOOK_APP_ID or --app-id)" >&2; exit 2; }
[ -n "$APP_PEM" ] || { echo "ERROR: App PEM missing (env OMD_WEBHOOK_APP_PEM or --pem)" >&2; exit 2; }

# ---------- resolve the PEM (file path or inline) -------------------------
if [ -f "$APP_PEM" ]; then
  PEM_FILE="$APP_PEM"
  [ -r "$PEM_FILE" ] || { echo "ERROR: cannot read PEM file '$PEM_FILE'" >&2; exit 2; }
else
  PEM_FILE="$(mktemp)"; TMP_FILES+=("$PEM_FILE")
  printf '%s\n' "$APP_PEM" > "$PEM_FILE"
fi
# sanity: must be a private key
grep -q 'PRIVATE KEY' "$PEM_FILE" || { echo "ERROR: '$APP_PEM' does not look like a private-key PEM" >&2; exit 2; }

# ---------- map friendly omd_version -> canonical -------------------------
if [ -n "$OMD_VERSION" ]; then
  case "$OMD_VERSION" in
    stable|latest)                 OMD_VERSION="latest" ;;
    testing|nightly|master|daily)  OMD_VERSION="master" ;;
    v[0-9]*)                       OMD_VERSION="${OMD_VERSION#v}" ;;
    [0-9]*) : ;;                                    # a bare version like 5.81
    *) echo "WARNING: omd_version '$OMD_VERSION' is not a recognized channel (master/latest) or a version (X.YY); sending as-is." >&2;;
  esac
fi
[ -n "$OMD_VERSION" ] || { echo "ERROR: OMD_VERSION missing (env OMD_WEBHOOK_OMD_VERSION or --omd-version). Expected: master|latest|testing|stable|nightly|daily|X.YY" >&2; exit 2; }
# a date-stamped daily (X.YY.ZZZ) is NOT an addressable version: the testing/
# daily channel is addressed with omd_version=master (which installs the
# CURRENT daily build). Reject it locally with guidance instead of letting
# the workflow's validator fail later.
if [[ "$OMD_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "ERROR: '$OMD_VERSION' looks like a date-stamped daily (X.YY.ZZZ). Those are NOT addressable versions: build today's nightly with omd_version=master (testing channel, installs the current daily), or address a pinned stable with a bare X.YY (even minor)." >&2
  exit 2
fi

# ---------- dry-run: print the plan, make no API calls ---------------------
if [ "$DRY_RUN" = 1 ]; then
  echo "DRY RUN — no API calls."
  echo "  repo         : $REPO"
  echo "  endpoint     : POST $API/repos/$REPO/dispatches"
  echo "  event_type   : $EVENT_TYPE"
  echo "  omd_version  : $OMD_VERSION"
  echo "  app id       : $APP_ID"
  echo "  installation : ${INSTALL_ID:-<auto-discover>}"
  echo "  payload      : {\"event_type\":\"$EVENT_TYPE\",\"client_payload\":{\"omd_version\":\"$OMD_VERSION\"}}"
  exit 0
fi

# ---------- helpers -------------------------------------------------------
b64url() { base64 | tr -d '\n' | tr '+/' '-_' | tr -d '='; }
json_field() { python3 -c "import sys,json;print(json.load(sys.stdin)['$1'])"; }

# ---------- 1) mint the app JWT (RS256, ~5 min) ---------------------------
NOW="$(date +%s)"
HDR=$(printf '{"alg":"RS256","typ":"JWT"}' | b64url)
PAY=$(printf '{"iss":%s,"iat":%s,"exp":%s,"aud":"github"}' "$APP_ID" "$NOW" "$((NOW+300))" | b64url)
SIG=$(printf '%s.%s' "$HDR" "$PAY" | openssl dgst -sha256 -sign "$PEM_FILE" -binary | b64url)
JWT="${HDR}.${PAY}.${SIG}"
echo "JWT minted (app id $APP_ID, ~300 s lifetime)."

# ---------- 2) installation id (given or discovered) ----------------------
if [ -z "$INSTALL_ID" ]; then
  # discovery via the repo endpoint (GET /app/installations is unreliable for
  # a fresh install — it returned an empty list for a live installation).
  local_inst_file="$(mktemp)"; TMP_FILES+=("$local_inst_file")
  HTTP_CODE="$(curl -s -o "$local_inst_file" -w '%{http_code}' \
    -H "Authorization: Bearer $JWT" -H "Accept: application/vnd.github+json" \
    "$API/repos/$REPO/installation")"
  [ "$HTTP_CODE" = 200 ] || { echo "ERROR: could not discover installation for $REPO (HTTP $HTTP_CODE):" >&2; cat "$local_inst_file" >&2; echo >&2; exit 1; }
  INSTALL_ID="$(json_field id < "$local_inst_file")"
  echo "Discovered installation id $INSTALL_ID for $REPO."
fi

# ---------- 3) mint a 1-hour installation token ---------------------------
TOKEN="$(curl -s -X POST -H "Authorization: Bearer $JWT" -H "Accept: application/vnd.github+json" \
    "$API/app/installations/$INSTALL_ID/access_tokens" | json_field token)"
[ -n "$TOKEN" ] || { echo "ERROR: could not mint an installation access token" >&2; exit 1; }
echo "Installation token minted (~1 h)."

if [ "$CHECK" = 1 ]; then
  echo "CHECK OK — credentials valid, installation found, token minted. Nothing was dispatched."
  exit 0
fi

# ---------- 4) post the repository_dispatch -------------------------------
PAYLOAD="{\"event_type\":\"$EVENT_TYPE\",\"client_payload\":{\"omd_version\":\"$OMD_VERSION\"}}"
RESP_FILE="$(mktemp)"; TMP_FILES+=("$RESP_FILE")
HTTP_CODE="$(curl -s -o "$RESP_FILE" -w '%{http_code}' -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Accept: application/vnd.github+json" \
  -H "Content-Type: application/json" \
  "$API/repos/$REPO/dispatches" \
  -d "$PAYLOAD")"

case "$HTTP_CODE" in
  204)
    echo "SUCCESS (HTTP 204): dispatch accepted for omd_version='$OMD_VERSION'."
    echo "  The build/publish runs in GitHub Actions (HTTP 204 is NOT a build-success signal):"
    echo "    https://github.com/$REPO/actions"
    ;;
  404)
    echo "ERROR (HTTP 404): the app/installation likely lacks access on $REPO, or no workflow on the DEFAULT branch listens for event_type '$EVENT_TYPE'." >&2
    cat "$RESP_FILE" >&2; echo >&2; exit 1;;
  403)
    echo "ERROR (HTTP 403): the installation token lacks the permission required to dispatch to $REPO (the app needs Contents: write)." >&2
    cat "$RESP_FILE" >&2; echo >&2; exit 1;;
  422)
    echo "ERROR (HTTP 422): validation failed (bad event_type/client_payload, or the endpoint was spammed)." >&2
    cat "$RESP_FILE" >&2; echo >&2; exit 1;;
  *)
    echo "ERROR (HTTP $HTTP_CODE): unexpected response." >&2
    cat "$RESP_FILE" >&2; echo >&2; exit 1;;
esac
