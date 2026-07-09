#!/bin/bash
#===============================================================================
# Moodle 4.5 Standard Installation — Oracle Linux 8.x — MAIN ORCHESTRATOR (v2)
#===============================================================================
# This replaces the v1 monolithic script with 14 numbered subscripts under
# steps/, each independently runnable and each writing a state/NN.done marker
# on success. This script:
#   - Collects the 3 required inputs once and remembers them across reruns
#     (Fix #3), so an interrupted install can be resumed without re-typing
#     SERVER_IP / DB_PASS / ROOT_PASS.
#   - Offers "run from start" / "resume from first incomplete step" /
#     "run a single step" (Fix #4) based on which steps/*.done markers exist.
#   - Stops immediately on the first failing step and reports which one
#     failed, so the user can fix it and rerun to resume.
#
# RUN AS: a sudo-capable user, from the cloned repo directory (the vendored
# libsodium-2.0.23.tgz and moodle-latest-405.tgz must sit next to this file).
#   chmod +x install.sh
#   ./install.sh
#===============================================================================

set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DONE="${REPO_ROOT}/.install_state.done"
STATE_TMP="${REPO_ROOT}/.install_state.tmp"
STATE_DIR="${REPO_ROOT}/state"
mkdir -p "$STATE_DIR"

# --- Fixed values (the verified standard layout - see action plan "Context") ---
# These never change between servers, so they live alongside the 3 real
# inputs in the state file purely so every subscript can source ONE file
# and be independently runnable (Fix #3 / Fix #4).
WEB_ROOT="/var/www/html"          # Default Apache DocumentRoot (kept - verified)
MOODLE_DIR="${WEB_ROOT}/moodle"   # Moodle served as a subdirectory: /moodle
DATA_DIR="/var/moodledata"        # Data dir OUTSIDE the web root (security)
DB_NAME="moodle"
DB_USER="moodleuser"
DB_PREFIX="mdl_"

echo "==============================================="
echo " Moodle 4.5 Installer - Oracle Linux 8.x (v2)"
echo "==============================================="

#===============================================================================
# Fix #3 - resume/state file: reuse saved SERVER_IP/DB_PASS/ROOT_PASS on rerun
# instead of re-prompting. Look for .install_state.done first (a previous
# fully-successful run), then .install_state.tmp (an interrupted run).
#===============================================================================
STATE_FOUND=""
if [ -f "$STATE_DONE" ]; then
    STATE_FOUND="$STATE_DONE"
elif [ -f "$STATE_TMP" ]; then
    STATE_FOUND="$STATE_TMP"
fi

REUSE_VALUES=false
if [ -n "$STATE_FOUND" ]; then
    # shellcheck disable=SC1090
    source "$STATE_FOUND"
    echo ""
    echo "Saved values found in $(basename "$STATE_FOUND"):"
    echo "  SERVER_IP = ${SERVER_IP}"
    echo "  DB_PASS   = ********"
    echo "  ROOT_PASS = ********"
    read -rp "Reuse saved values? [Y/n]: " REUSE_ANSWER
    REUSE_ANSWER=${REUSE_ANSWER:-Y}
    if [[ "$REUSE_ANSWER" =~ ^[Yy] ]]; then
        REUSE_VALUES=true
    fi
fi

if [ "$REUSE_VALUES" != true ]; then
    echo ""
    read -rp "Enter this server's IP address (e.g. 10.0.41.91): " SERVER_IP
    read -rsp "Enter a password for the Moodle database user 'moodleuser': " DB_PASS
    echo ""
    read -rsp "Enter a password to set for the MariaDB root user: " ROOT_PASS
    echo ""

    # New values were entered - a stale .install_state.done would otherwise
    # win on the NEXT run (this script checks .done before .tmp above) and
    # silently resurrect the OLD passwords/IP. Drop it before writing the
    # new working copy.
    rm -f "$STATE_DONE"

    # printf %q shell-escapes each value so passwords containing quotes or
    # other special characters survive being `source`d back in by the
    # subscripts without breaking.
    {
        printf 'SERVER_IP=%q\n' "$SERVER_IP"
        printf 'DB_PASS=%q\n' "$DB_PASS"
        printf 'ROOT_PASS=%q\n' "$ROOT_PASS"
        printf 'WEB_ROOT=%q\n' "$WEB_ROOT"
        printf 'MOODLE_DIR=%q\n' "$MOODLE_DIR"
        printf 'DATA_DIR=%q\n' "$DATA_DIR"
        printf 'DB_NAME=%q\n' "$DB_NAME"
        printf 'DB_USER=%q\n' "$DB_USER"
        printf 'DB_PREFIX=%q\n' "$DB_PREFIX"
    } > "$STATE_TMP"
    # Contains plaintext passwords - never world/group readable.
    chmod 600 "$STATE_TMP"
fi

echo ""
echo "[INFO] Installation will use:"
echo "       Web URL   : http://${SERVER_IP}/moodle"
echo "       Moodle dir: ${MOODLE_DIR}"
echo "       Data dir  : ${DATA_DIR}"
echo "       Database  : ${DB_NAME} / user: ${DB_USER}"
read -rp "Press Enter to begin, or Ctrl+C to cancel..."

#===============================================================================
# Fix #4 - run from start / resume from first incomplete step / run one step
#===============================================================================
STEPS="01 02 03 04 05 06 07 08 09 10 11 12 13 14"

find_step_script() {
    local n="$1"
    ls "${REPO_ROOT}/steps/${n}"_*.sh 2>/dev/null | head -n1
}

run_step() {
    local n="$1"
    local script
    script="$(find_step_script "$n")"
    if [ -z "$script" ]; then
        echo "[ERROR] No step script found for step ${n}." >&2
        exit 1
    fi
    echo ""
    echo "=== Running step ${n}: $(basename "$script") ==="
    if ! bash "$script"; then
        echo ""
        echo "[FAILED] Step ${n} ($(basename "$script")) failed." >&2
        echo "Fix the error above, then rerun ./install.sh - it will resume from this step." >&2
        exit 1
    fi
}

# Does any progress already exist from a previous run?
HAS_DONE_MARKERS=false
for n in $STEPS; do
    if [ -f "${STATE_DIR}/${n}.done" ]; then
        HAS_DONE_MARKERS=true
        break
    fi
done

MODE="start"
START_FROM="01"
SINGLE_STEP=""

if [ "$HAS_DONE_MARKERS" = true ]; then
    echo ""
    echo "Previous progress found in ${STATE_DIR}/:"
    echo "  1) Run from start (clears all progress markers)"
    echo "  2) Resume from first incomplete step (default)"
    echo "  3) Run a single specific step"
    read -rp "Select [1/2/3] (default 2): " MENU_CHOICE
    MENU_CHOICE=${MENU_CHOICE:-2}

    case "$MENU_CHOICE" in
        1)
            read -rp "This clears ALL progress markers and reruns every step. Continue? [y/N]: " CONFIRM
            if [[ "$CONFIRM" =~ ^[Yy] ]]; then
                rm -f "${STATE_DIR}"/*.done
                MODE="start"
            else
                echo "Cancelled."
                exit 0
            fi
            ;;
        2)
            MODE="resume"
            for n in $STEPS; do
                if [ ! -f "${STATE_DIR}/${n}.done" ]; then
                    START_FROM="$n"
                    break
                fi
            done
            ;;
        3)
            MODE="single"
            read -rp "Enter step number to run (1-14): " STEP_NUM
            SINGLE_STEP="$(printf '%02d' "$((10#$STEP_NUM))")"
            ;;
        *)
            echo "[ERROR] Invalid selection." >&2
            exit 1
            ;;
    esac
fi

if [ "$MODE" = "single" ]; then
    run_step "$SINGLE_STEP"
else
    RUN=false
    for n in $STEPS; do
        if [ "$n" = "$START_FROM" ]; then
            RUN=true
        fi
        if [ "$RUN" = true ]; then
            run_step "$n"
        fi
    done

    # Fix #3: only mark the run complete after every step - including the
    # final verification in step 14 - has succeeded.
    if [ -f "$STATE_TMP" ]; then
        mv "$STATE_TMP" "$STATE_DONE"
        chmod 600 "$STATE_DONE"
    fi

    echo ""
    echo "==============================================================="
    echo " INSTALLATION COMPLETE"
    echo "==============================================================="
    echo " Open in a browser:  http://${SERVER_IP}/moodle"
    echo " The web installer will run environment checks, create the"
    echo " database tables, then ask you to create the ADMIN account."
    echo "==============================================================="
fi
