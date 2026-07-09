#!/bin/bash
#===============================================================================
# Moodle 4.5 Standard Installation Script — Oracle Linux 8.x
#===============================================================================
# Built from a verified, working installation (OL 8.10, July 2026).
# Contains ONLY steps confirmed to work. No trial/failed approaches included.
#
# WHAT THIS SCRIPT DOES (high level):
#   1. Collects required inputs (server IP, DB passwords)
#      NOTE: no proxy input — servers arrive with proxy pre-configured
#      by the network team; curl/dnf use it automatically.
#   2. Updates the system
#   3. Enables PHP 8.2 and MariaDB 10.11 module streams (DNF4 modularity)
#   4. Installs Apache, MariaDB, PHP 8.2 + all Moodle-required extensions
#   5. Builds the PHP sodium extension from source
#      (php-sodium is NOT packaged in OL8 AppStream/EPEL — verified)
#   6. Tunes php.ini for Moodle requirements
#   7. Secures MariaDB and creates the Moodle database + user
#   8. Downloads and extracts Moodle 4.5, sets ownership
#   9. Creates the moodledata directory outside the web root
#  10. Applies SELinux booleans and file contexts (system stays Enforcing)
#  11. Configures Apache (default DocumentRoot + /moodle subdirectory —
#      a custom vhost with DocumentRoot=/var/www/html/moodle caused 404s)
#  12. Opens the firewall for HTTP/HTTPS
#  13. Generates config.php (the installer could not write it itself)
#  14. Verifies the installation responds with the expected redirect
#
# AFTER THE SCRIPT: open  http://<SERVER_IP>/moodle  in a browser and
# complete the web installer (DB tables + admin account + site name).
#
# RUN AS: a sudo-capable user (script uses sudo internally).
#   chmod +x moodle_install_ol8.sh
#   ./moodle_install_ol8.sh
#===============================================================================

set -e  # Stop immediately if any command fails (matches "troubleshoot before proceeding")

#===============================================================================
# STEP 0 — USER INPUTS
# Collect everything that changes between servers so the same script
# can be reused as the standard. Nothing is hardcoded per-server.
#===============================================================================
echo "==============================================="
echo " Moodle 4.5 Installer — Oracle Linux 8.x"
echo "==============================================="

# --- Server IP: used for the Moodle wwwroot URL and final verification ---
read -rp "Enter this server's IP address (e.g. 10.0.41.91): " SERVER_IP

# --- Database password for the moodle DB user (input hidden) ---
read -rsp "Enter a password for the Moodle database user 'moodleuser': " DB_PASS
echo ""

# --- MariaDB root password: set during securing step (input hidden) ---
read -rsp "Enter a password to set for the MariaDB root user: " ROOT_PASS
echo ""

# --- Proxy note (no input needed) ---
# The network team (NITC) pre-configures the proxy on each server
# (environment variables + /etc/dnf/dnf.conf). curl and dnf automatically
# use that existing configuration. This script therefore does NOT ask for
# or set any proxy — it relies on the server's existing setup. On servers
# with direct Internet access, downloads simply go direct. Either way works.

# --- Fixed values (the verified standard layout) ---
MOODLE_URL="https://download.moodle.org/download.php/direct/stable405/moodle-latest-405.tgz"
WEB_ROOT="/var/www/html"                 # Default Apache DocumentRoot (kept — verified)
MOODLE_DIR="${WEB_ROOT}/moodle"          # Moodle served as a subdirectory: /moodle
DATA_DIR="/var/moodledata"               # Data dir OUTSIDE the web root (security)
DB_NAME="moodle"
DB_USER="moodleuser"

echo ""
echo "[INFO] Installation will use:"
echo "       Web URL   : http://${SERVER_IP}/moodle"
echo "       Moodle dir: ${MOODLE_DIR}"
echo "       Data dir  : ${DATA_DIR}"
echo "       Database  : ${DB_NAME} / user: ${DB_USER}"
read -rp "Press Enter to begin, or Ctrl+C to cancel..."

#===============================================================================
# STEP 1 — SYSTEM UPDATE
# Ensures all packages and repo metadata are current before installing.
#===============================================================================
echo "[STEP 1] Updating system..."
sudo dnf update -y

#===============================================================================
# STEP 2 — ENABLE MODULE STREAMS (OL8 / DNF4 SPECIFIC)
# OL8 uses DNF4 modularity. The default php stream is 7.2 (too old for
# Moodle 4.5, which needs 8.1–8.3) and default mariadb is 10.3 (needs >=10.6).
# Verified available and working on OL8.10: php:8.2 and mariadb:10.11.
# NOTE: Do NOT use Remi repo (incompatible pattern) — native streams suffice.
#===============================================================================
echo "[STEP 2] Enabling PHP 8.2 and MariaDB 10.11 module streams..."
sudo dnf module reset php -y
sudo dnf module enable php:8.2 -y
sudo dnf module reset mariadb -y
sudo dnf module enable mariadb:10.11 -y

#===============================================================================
# STEP 3 — INSTALL PACKAGES
# PHP 8.2 + all Moodle-required extensions available from AppStream,
# Apache (httpd), MariaDB server, and the toolchain needed later to
# build the sodium extension from source (php-sodium has NO package on OL8).
#===============================================================================
echo "[STEP 3] Installing Apache, MariaDB, PHP 8.2 and extensions..."
sudo dnf install -y \
    httpd mariadb-server \
    php php-cli php-fpm php-mysqlnd php-xml php-mbstring php-curl \
    php-zip php-gd php-intl php-soap php-opcache \
    php-pear php-devel libsodium libsodium-devel make gcc

#===============================================================================
# STEP 4 — ENABLE AND START SERVICES
# httpd + mariadb + php-fpm. IMPORTANT (verified): Apache on OL8 uses
# proxy_fcgi -> php-fpm to execute PHP. php-fpm installs "disabled";
# it MUST be enabled or PHP stops working after a reboot.
#===============================================================================
echo "[STEP 4] Enabling and starting services..."
sudo systemctl enable --now httpd mariadb php-fpm

#===============================================================================
# STEP 5 — BUILD THE PHP SODIUM EXTENSION FROM SOURCE
# Moodle 4.5 requires the sodium extension. Verified facts on OL8:
#   - No php-sodium package exists in AppStream or EPEL
#   - PECL cannot resolve DNS behind the corporate proxy (channel 404s)
#   - Downloading the PECL tarball with curl + building manually WORKS
#===============================================================================
echo "[STEP 5] Building PHP sodium extension from source..."

# 5a. Download the extension source tarball (curl honors proxy env vars)
curl -sSL -o /tmp/sodium.tgz "https://pecl.php.net/get/libsodium"

# 5b. Safety check: confirm it is a real gzip archive, not a proxy error page
if ! file /tmp/sodium.tgz | grep -q "gzip compressed data"; then
    echo "[ERROR] Downloaded file is not a valid gzip archive. Check proxy/network."
    exit 1
fi

# 5c. Extract, then compile against the installed PHP 8.2 headers
cd /tmp
tar -xzf sodium.tgz
cd /tmp/libsodium-*/
sudo phpize                 # Prepares the build for the installed PHP API
sudo ./configure            # Detects libsodium-devel headers
sudo make                   # Compiles sodium.so
sudo make install           # Installs to /usr/lib64/php/modules/

# 5d. Enable the extension for PHP (CLI + FPM read /etc/php.d/)
echo "extension=sodium.so" | sudo tee /etc/php.d/20-sodium.ini > /dev/null

# 5e. Verify it loads — hard stop if not (Moodle will refuse to install)
if php -m | grep -qi "^sodium$"; then
    echo "[OK] sodium extension loaded."
else
    echo "[ERROR] sodium extension did not load. Stopping."
    exit 1
fi

#===============================================================================
# STEP 6 — TUNE php.ini FOR MOODLE
# Required/recommended values (verified):
#   max_input_vars >= 5000 (installer hard requirement)
#   larger upload limits, execution time, and memory for normal operation
# A backup of php.ini is kept before editing.
#===============================================================================
echo "[STEP 6] Tuning php.ini..."
sudo cp /etc/php.ini /etc/php.ini.bak
sudo sed -i \
  -e 's/^;\?max_input_vars.*/max_input_vars = 5000/' \
  -e 's/^upload_max_filesize.*/upload_max_filesize = 512M/' \
  -e 's/^post_max_size.*/post_max_size = 512M/' \
  -e 's/^max_execution_time.*/max_execution_time = 360/' \
  -e 's/^memory_limit.*/memory_limit = 256M/' \
  /etc/php.ini

#===============================================================================
# STEP 7 — SECURE MARIADB (NON-INTERACTIVE)
# Performs the same actions as mysql_secure_installation, scripted:
#   set root password, remove anonymous users, disable remote root,
#   drop the test database, reload privileges.
#===============================================================================
echo "[STEP 7] Securing MariaDB..."
sudo mysql <<SQL
ALTER USER 'root'@'localhost' IDENTIFIED BY '${ROOT_PASS}';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost','127.0.0.1','::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
SQL

#===============================================================================
# STEP 8 — CREATE THE MOODLE DATABASE AND USER
# utf8mb4 + unicode_ci is Moodle's required charset/collation.
# The user is restricted to localhost and to the moodle database only.
#===============================================================================
echo "[STEP 8] Creating Moodle database and user..."
sudo mysql -u root -p"${ROOT_PASS}" <<SQL
CREATE DATABASE IF NOT EXISTS ${DB_NAME} DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
SQL

#===============================================================================
# STEP 9 — DOWNLOAD AND EXTRACT MOODLE 4.5
# curl works through the proxy (verified). The gzip check protects against
# a proxy returning an HTML error page instead of the real archive.
#===============================================================================
echo "[STEP 9] Downloading Moodle 4.5..."
curl -L "$MOODLE_URL" -o /tmp/moodle.tgz

if ! file /tmp/moodle.tgz | grep -q "gzip compressed data"; then
    echo "[ERROR] Moodle download is not a valid archive. Check proxy/network."
    exit 1
fi

echo "[STEP 9] Extracting to ${WEB_ROOT}..."
sudo tar -xzf /tmp/moodle.tgz -C "$WEB_ROOT/"

# Ownership: the tarball preserves foreign UIDs (verified: 1005:1005 UNKNOWN).
# Apache must own the tree.
sudo chown -R apache:apache "$MOODLE_DIR"

#===============================================================================
# STEP 10 — CREATE THE MOODLEDATA DIRECTORY
# MUST be outside the web root (never /var/www/...) so uploaded files are
# not directly downloadable. 750 = apache full access, group read, no other.
#===============================================================================
echo "[STEP 10] Creating moodledata directory..."
sudo mkdir -p "$DATA_DIR"
sudo chown -R apache:apache "$DATA_DIR"
sudo chmod 750 "$DATA_DIR"

#===============================================================================
# STEP 11 — SELINUX CONFIGURATION (SYSTEM STAYS ENFORCING)
# Verified required on OL8 with SELinux Enforcing:
#   - boolean: allow Apache to reach the DB over the network
#   - moodledata: read/WRITE context (Moodle writes session/cache/files here)
#   - moodle code: read-only web content context
#===============================================================================
echo "[STEP 11] Applying SELinux contexts..."
sudo setsebool -P httpd_can_network_connect_db 1
sudo semanage fcontext -a -t httpd_sys_rw_content_t "${DATA_DIR}(/.*)?" 2>/dev/null || true
sudo restorecon -R "$DATA_DIR"
sudo semanage fcontext -a -t httpd_sys_content_t "${MOODLE_DIR}(/.*)?" 2>/dev/null || true
sudo restorecon -R "$MOODLE_DIR"

#===============================================================================
# STEP 12 — APACHE CONFIGURATION
# VERIFIED LESSON: a custom vhost with DocumentRoot=/var/www/html/moodle
# breaks the /moodle URL (resolves to .../moodle/moodle -> 404).
# The working standard: keep the DEFAULT DocumentRoot (/var/www/html) and
# serve Moodle as the /moodle subdirectory. Only ServerName is added to
# suppress the AH00558 startup warning.
#===============================================================================
echo "[STEP 12] Configuring Apache..."
echo "ServerName localhost" | sudo tee /etc/httpd/conf.d/servername.conf > /dev/null
sudo apachectl configtest

#===============================================================================
# STEP 13 — FIREWALL
# Open HTTP and HTTPS permanently. (Network-level firewalls/proxies between
# subnets are outside the server — those may need a ticket to the network team.)
#===============================================================================
echo "[STEP 13] Opening firewall for HTTP/HTTPS..."
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --reload

#===============================================================================
# STEP 14 — GENERATE config.php
# VERIFIED: the web installer cannot write config.php (web root is not
# writable by design). We generate it here with the correct values, so the
# web installer skips straight to environment checks and DB table creation.
#===============================================================================
echo "[STEP 14] Writing config.php..."
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
\$CFG->prefix    = 'mdl_';
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

# Ownership + SELinux label on the generated file (verified required)
sudo chown apache:apache "${MOODLE_DIR}/config.php"
sudo restorecon "${MOODLE_DIR}/config.php"

#===============================================================================
# STEP 15 — RESTART SERVICES AND VERIFY
# Expected verification result (verified on the working install):
#   HTTP 302/303 redirect toward install.php (fresh) or the site (configured).
#===============================================================================
echo "[STEP 15] Restarting services..."
sudo systemctl restart httpd php-fpm

echo "[STEP 15] Verifying Moodle responds..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost/moodle/")
if [ "$HTTP_CODE" = "302" ] || [ "$HTTP_CODE" = "303" ] || [ "$HTTP_CODE" = "200" ]; then
    echo "[OK] Moodle responds (HTTP ${HTTP_CODE})."
else
    echo "[WARNING] Unexpected HTTP code: ${HTTP_CODE} — investigate before continuing."
fi

#===============================================================================
# DONE — FINAL INSTRUCTIONS
#===============================================================================
echo ""
echo "==============================================================="
echo " SERVER-SIDE INSTALLATION COMPLETE"
echo "==============================================================="
echo " 1. Open in a browser:  http://${SERVER_IP}/moodle"
echo " 2. The web installer will run environment checks, create the"
echo "    database tables, then ask you to create the ADMIN account."
echo "    Admin password rules: 8+ chars, 1 digit, 1 lower, 1 upper,"
echo "    1 special character (* - #)."
echo " 3. If the page is unreachable from a client machine but works"
echo "    locally (curl http://localhost/moodle/ returns 302), the"
echo "    block is the NETWORK path (proxy/firewall between subnets)."
echo "    Verified fix: request the network team (e.g. NITC) to open"
echo "    HTTP/HTTPS to this server."
echo "==============================================================="