#!/bin/bash
#===============================================================================
# STEP 05 — BUILD THE PHP SODIUM EXTENSION FROM SOURCE (Fix #2: vendored)
# Moodle 4.5 requires the sodium extension. Verified facts on OL8:
#   - No php-sodium package exists in AppStream or EPEL.
#   - PECL cannot resolve DNS behind the corporate proxy (channel 404s), and
#     a plain curl download of the PECL tarball fails the same way
#     (verified failure: "curl: (6) Could not resolve host: pecl.php.net") -
#     proxy env vars are not reliably inherited by script subshells.
#   - Fix: the sodium extension source is vendored in this repo as
#     libsodium-2.0.23.tgz and copied locally instead of downloaded, which
#     removes the external dependency entirely.
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

SODIUM_TGZ="${REPO_ROOT}/libsodium-2.0.23.tgz"

if [ ! -f "$SODIUM_TGZ" ]; then
    echo "[ERROR] ${SODIUM_TGZ} not found. This script must run from the cloned repo." >&2
    exit 1
fi

echo "[STEP 05] Copying vendored sodium source tarball..."
cp "$SODIUM_TGZ" /tmp/sodium.tgz

# Safety check: confirm it's a real gzip archive, not a corrupted clone or
# a Git LFS pointer file (kept from v1 as a sanity check on the vendored copy).
if ! file /tmp/sodium.tgz | grep -q "gzip compressed data"; then
    echo "[ERROR] ${SODIUM_TGZ} is not a valid gzip archive. Check the repo clone." >&2
    exit 1
fi

echo "[STEP 05] Extracting and building the sodium extension..."
cd /tmp
tar -xzf sodium.tgz
cd /tmp/libsodium-*/
sudo phpize                 # Prepares the build against the installed PHP API
sudo ./configure            # Detects libsodium-devel headers (Fix #1 dependency)
sudo make
sudo make install            # Installs sodium.so to /usr/lib64/php/modules/

# Enable the extension for PHP (both CLI and FPM read /etc/php.d/).
echo "extension=sodium.so" | sudo tee /etc/php.d/20-sodium.ini > /dev/null

# Hard stop if it didn't load - Moodle will refuse to install without it.
if php -m | grep -qi "^sodium$"; then
    echo "[OK] sodium extension loaded."
else
    echo "[ERROR] sodium extension did not load." >&2
    exit 1
fi

touch "${STATE_DIR}/05.done"
echo "[OK] Step 05 complete."
