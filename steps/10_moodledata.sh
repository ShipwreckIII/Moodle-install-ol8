#!/bin/bash
#===============================================================================
# STEP 10 — CREATE THE MOODLEDATA DIRECTORY
# MUST be outside the web root (never /var/www/...) so uploaded files are
# not directly downloadable through Apache. 750 = apache full access,
# group read, no other.
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

echo "[STEP 10] Creating moodledata directory..."
sudo mkdir -p "$DATA_DIR"
sudo chown -R apache:apache "$DATA_DIR"
sudo chmod 750 "$DATA_DIR"

touch "${STATE_DIR}/10.done"
echo "[OK] Step 10 complete."
