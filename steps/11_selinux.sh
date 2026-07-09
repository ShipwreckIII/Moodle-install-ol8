#!/bin/bash
#===============================================================================
# STEP 11 — SELINUX CONFIGURATION (SYSTEM STAYS ENFORCING)
# SELinux is never disabled on this host. Verified required with SELinux
# Enforcing on OL8:
#   - boolean: allow Apache to reach the DB over the network
#   - moodledata: read/WRITE context (Moodle writes session/cache/files here)
#   - moodle code: read-only web content context
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

echo "[STEP 11] Applying SELinux contexts (SELinux remains Enforcing)..."
sudo setsebool -P httpd_can_network_connect_db 1
sudo semanage fcontext -a -t httpd_sys_rw_content_t "${DATA_DIR}(/.*)?" 2>/dev/null || true
sudo restorecon -R "$DATA_DIR"
sudo semanage fcontext -a -t httpd_sys_content_t "${MOODLE_DIR}(/.*)?" 2>/dev/null || true
sudo restorecon -R "$MOODLE_DIR"

touch "${STATE_DIR}/11.done"
echo "[OK] Step 11 complete."
