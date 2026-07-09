#!/bin/bash
#===============================================================================
# STEP 02 — ENABLE MODULE STREAMS (OL8 / DNF4 SPECIFIC)
# OL8 uses DNF4 modularity. The default php stream is 7.2 (too old for
# Moodle 4.5, which needs 8.1-8.3) and the default mariadb stream is 10.3
# (Moodle needs >=10.6). Verified available and working on OL8.10:
# php:8.2 and mariadb:10.11.
# NOTE: Do NOT use the Remi repo here - it's an incompatible pattern on this
# host and native module streams are sufficient (verified working approach).
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

echo "[STEP 02] Enabling PHP 8.2 and MariaDB 10.11 module streams..."
sudo dnf module reset php -y
sudo dnf module enable php:8.2 -y
sudo dnf module reset mariadb -y
sudo dnf module enable mariadb:10.11 -y

touch "${STATE_DIR}/02.done"
echo "[OK] Step 02 complete."
