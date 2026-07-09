#!/bin/bash
#===============================================================================
# STEP 09 — EXTRACT MOODLE 4.5 (Fix #2: vendored, no download)
# moodle-latest-405.tgz is vendored in the repo instead of being downloaded
# from download.moodle.org, removing the external/proxy dependency for the
# ~80 MB archive entirely.
# The gzip check protects against a corrupted clone (or a Git LFS pointer
# file standing in for the real archive) rather than a proxy error page.
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

MOODLE_TGZ="${REPO_ROOT}/moodle-latest-405.tgz"

if [ ! -f "$MOODLE_TGZ" ]; then
    echo "[ERROR] ${MOODLE_TGZ} not found. This script must run from the cloned repo." >&2
    exit 1
fi

echo "[STEP 09] Copying vendored Moodle archive..."
cp "$MOODLE_TGZ" /tmp/moodle.tgz

if ! file /tmp/moodle.tgz | grep -q "gzip compressed data"; then
    echo "[ERROR] ${MOODLE_TGZ} is not a valid gzip archive. Check the repo clone." >&2
    exit 1
fi

echo "[STEP 09] Extracting to ${WEB_ROOT}..."
sudo tar -xzf /tmp/moodle.tgz -C "$WEB_ROOT/"

# Ownership: the tarball preserves foreign UIDs (verified: 1005:1005 UNKNOWN
# on the original build host). Apache must own the tree to serve/write to it.
sudo chown -R apache:apache "$MOODLE_DIR"

touch "${STATE_DIR}/09.done"
echo "[OK] Step 09 complete."
