#!/bin/bash
#===============================================================================
# STEP 03 — INSTALL PACKAGES (Fix #1: EPEL enabled BEFORE the main install)
# libsodium and libsodium-devel (the build headers the sodium extension in
# step 05 compiles against) live in EPEL, not AppStream, and EPEL is not
# enabled by default on OL8. Without enabling it first, the dnf install
# below fails with:
#   "No match for argument: libsodium libsodium-devel"
# oracle-epel-release-el8 is Oracle's own EPEL release package - safe to
# enable permanently and does not conflict with AppStream.
#
# The rest of this step installs Apache, MariaDB, PHP 8.2 and every
# extension Moodle 4.5 requires, plus the toolchain (make, gcc, php-devel)
# needed later to build the sodium extension from source (there is no
# php-sodium package on OL8).
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

# --- Fix #1: EPEL first, so libsodium/libsodium-devel resolve below ---
echo "[STEP 03] Enabling EPEL (required for libsodium/libsodium-devel)..."
sudo dnf install -y oracle-epel-release-el8

echo "[STEP 03] Installing Apache, MariaDB, PHP 8.2 and extensions..."
sudo dnf install -y \
    httpd mariadb-server \
    php php-cli php-fpm php-mysqlnd php-xml php-mbstring php-curl \
    php-zip php-gd php-intl php-soap php-opcache \
    php-pear php-devel libsodium libsodium-devel make gcc

touch "${STATE_DIR}/03.done"
echo "[OK] Step 03 complete."
