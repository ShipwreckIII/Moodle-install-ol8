#!/bin/bash
#===============================================================================
# STEP 07 — SECURE MARIADB (NON-INTERACTIVE)
# Performs the same actions as mysql_secure_installation, scripted so the
# whole install can run unattended after the initial 3 prompts:
#   set root password, remove anonymous users, disable remote root,
#   drop the test database, reload privileges.
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

echo "[STEP 07] Securing MariaDB..."
sudo mysql <<SQL
ALTER USER 'root'@'localhost' IDENTIFIED BY '${ROOT_PASS}';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost','127.0.0.1','::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
SQL

touch "${STATE_DIR}/07.done"
echo "[OK] Step 07 complete."
