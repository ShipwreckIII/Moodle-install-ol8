#!/bin/bash
#===============================================================================
# STEP 01 — SYSTEM UPDATE
# Ensures all packages and repo metadata are current before installing
# anything else. Running this first avoids installing PHP/MariaDB against
# stale repo metadata (a known cause of dependency resolution errors).
#===============================================================================
set -e

# Resolve the repo root regardless of where this script is invoked from, so
# it stays independently runnable (steps/ is one level below the repo root).
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_DONE="${REPO_ROOT}/.install_state.done"
STATE_TMP="${REPO_ROOT}/.install_state.tmp"
STATE_DIR="${REPO_ROOT}/state"
mkdir -p "$STATE_DIR"

# Load SERVER_IP / DB_PASS / ROOT_PASS and the fixed layout values written
# by install.sh (Fix #3) so this script can run standalone.
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

echo "[STEP 01] Updating system packages..."
sudo dnf update -y

touch "${STATE_DIR}/01.done"
echo "[OK] Step 01 complete."
