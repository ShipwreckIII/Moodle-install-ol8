#!/bin/bash
#===============================================================================
# STEP 04 — ENABLE AND START SERVICES
# httpd + mariadb + php-fpm. IMPORTANT (verified): Apache on OL8 uses
# proxy_fcgi -> php-fpm to execute PHP. php-fpm installs disabled by
# default; it MUST be explicitly enabled or PHP stops working after a
# reboot (Apache would keep running, but every .php request would fail).
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

echo "[STEP 04] Enabling and starting httpd, mariadb, php-fpm..."
sudo systemctl enable --now httpd mariadb php-fpm

touch "${STATE_DIR}/04.done"
echo "[OK] Step 04 complete."
