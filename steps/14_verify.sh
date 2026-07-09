#!/bin/bash
#===============================================================================
# STEP 14 — RESTART SERVICES AND VERIFY (Fix #5: proxy bypass)
# VERIFIED LESSON: the corporate proxy env vars intercept even localhost
# requests (plain curl to localhost returned a proxy 403 with WAF headers,
# while Apache never received the request). The fix is `--noproxy '*'` on
# this specific check only - this is the ONLY proxy-related code in the
# whole install, and it exists purely to make curl talk to Apache directly.
#
# Expected result: HTTP 302/303 with `Location: install.php` (fresh install)
# or `X-Redirect-By: Moodle` (already configured).
#===============================================================================
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_DONE="${REPO_ROOT}/.install_state.done"
STATE_TMP="${REPO_ROOT}/.install_state.tmp"
STATE_DIR="${REPO_ROOT}/state"
mkdir -p "$STATE_DIR"

if [ -f "$STATE_DONE" ]; then
    # shellcheck disable=SC1090
    source "$STATE_DONE"
elif [ -f "$STATE_TMP" ]; then
    # shellcheck disable=SC1090
    source "$STATE_TMP"
else
    echo "[ERROR] No state file found (.install_state.done/.tmp). Run install.sh first." >&2
    exit 1
fi

echo "[STEP 14] Restarting httpd and php-fpm..."
sudo systemctl restart httpd php-fpm

echo "[STEP 14] Verifying Moodle responds (bypassing the proxy for this local check)..."
RESPONSE_HEADERS="$(curl -sI --noproxy '*' "http://127.0.0.1/moodle/")"
HTTP_CODE="$(echo "$RESPONSE_HEADERS" | head -n1 | awk '{print $2}')"

if [ "$HTTP_CODE" = "302" ] || [ "$HTTP_CODE" = "303" ] || [ "$HTTP_CODE" = "200" ]; then
    echo "[OK] Moodle responds (HTTP ${HTTP_CODE})."
else
    echo "[ERROR] Unexpected HTTP code: ${HTTP_CODE} - investigate before continuing." >&2
    echo "$RESPONSE_HEADERS" >&2
    exit 1
fi

touch "${STATE_DIR}/14.done"
echo "[OK] Step 14 complete."

echo ""
echo "==============================================================="
echo " SERVER-SIDE INSTALLATION COMPLETE"
echo "==============================================================="
echo " 1. Open in a browser:  http://${SERVER_IP}/moodle"
echo " 2. The web installer will run environment checks, create the"
echo "    database tables, then ask you to create the ADMIN account."
echo "    Admin password rules: 8+ chars, 1 digit, 1 lower, 1 upper,"
echo "    1 special character (* - #)."
echo " 3. If the page is unreachable from a client machine but works"
echo "    locally (this step's check returned ${HTTP_CODE}), the block"
echo "    is the NETWORK path (proxy/firewall between subnets), not"
echo "    this server. Request the network team (e.g. NITC) open"
echo "    HTTP/HTTPS to this server."
echo "==============================================================="
