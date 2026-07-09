#!/bin/bash
#===============================================================================
# STEP 12 — APACHE CONFIGURATION AND FIREWALL
# VERIFIED LESSON: a custom vhost with DocumentRoot=/var/www/html/moodle
# breaks the /moodle URL (resolves to .../moodle/moodle -> 404). The
# working standard is to keep the DEFAULT DocumentRoot (/var/www/html) and
# serve Moodle as the /moodle subdirectory. Only ServerName is added, to
# suppress the AH00558 startup warning. Do NOT reintroduce a custom vhost.
#
# Firewall: open HTTP and HTTPS permanently. (Network-level firewalls/
# proxies between subnets are outside this server - those need a ticket
# to the network team, not a script change here.)
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

echo "[STEP 12] Configuring Apache..."
echo "ServerName localhost" | sudo tee /etc/httpd/conf.d/servername.conf > /dev/null
sudo apachectl configtest

echo "[STEP 12] Opening firewall for HTTP/HTTPS..."
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --reload

touch "${STATE_DIR}/12.done"
echo "[OK] Step 12 complete."
