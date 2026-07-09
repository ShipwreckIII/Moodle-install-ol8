#!/bin/bash
#===============================================================================
# STEP 06 — TUNE php.ini FOR MOODLE
# Required/recommended values (verified):
#   max_input_vars >= 5000 (Moodle installer hard requirement)
#   larger upload limits, execution time, and memory for normal operation
# A backup of php.ini is kept before editing.
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

echo "[STEP 06] Tuning php.ini..."
sudo cp /etc/php.ini /etc/php.ini.bak
sudo sed -i \
  -e 's/^;\?max_input_vars.*/max_input_vars = 5000/' \
  -e 's/^upload_max_filesize.*/upload_max_filesize = 512M/' \
  -e 's/^post_max_size.*/post_max_size = 512M/' \
  -e 's/^max_execution_time.*/max_execution_time = 360/' \
  -e 's/^memory_limit.*/memory_limit = 256M/' \
  /etc/php.ini

touch "${STATE_DIR}/06.done"
echo "[OK] Step 06 complete."
