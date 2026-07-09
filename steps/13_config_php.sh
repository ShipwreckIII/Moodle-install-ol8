#!/bin/bash
#===============================================================================
# STEP 13 — GENERATE config.php
# VERIFIED: the web installer cannot write config.php itself (the web root
# is not writable by design). This step generates it here with the correct
# values, so the web installer skips straight to environment checks and
# DB table creation.
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

echo "[STEP 13] Writing config.php..."
sudo tee "${MOODLE_DIR}/config.php" > /dev/null <<EOF
<?php  // Moodle configuration file

unset(\$CFG);
global \$CFG;
\$CFG = new stdClass();

\$CFG->dbtype    = 'mariadb';
\$CFG->dblibrary = 'native';
\$CFG->dbhost    = 'localhost';
\$CFG->dbname    = '${DB_NAME}';
\$CFG->dbuser    = '${DB_USER}';
\$CFG->dbpass    = '${DB_PASS}';
\$CFG->prefix    = '${DB_PREFIX}';
\$CFG->dboptions = array (
  'dbpersist' => 0,
  'dbport' => '',
  'dbsocket' => '',
  'dbcollation' => 'utf8mb4_unicode_ci',
);

\$CFG->wwwroot   = 'http://${SERVER_IP}/moodle';
\$CFG->dataroot  = '${DATA_DIR}';
\$CFG->admin     = 'admin';

\$CFG->directorypermissions = 0777;

require_once(__DIR__ . '/lib/setup.php');

// There is no php closing tag in this file,
// it is intentional because it prevents trailing whitespace problems!
EOF

# Ownership + SELinux label on the generated file (verified required so
# Apache can read it under the httpd_sys_content_t context from step 11).
sudo chown apache:apache "${MOODLE_DIR}/config.php"
sudo restorecon "${MOODLE_DIR}/config.php"

touch "${STATE_DIR}/13.done"
echo "[OK] Step 13 complete."
