# Moodle 4.5 — Oracle Linux 8.x Install

Installs Moodle 4.5 on Oracle Linux 8.x: PHP 8.2 + MariaDB 10.11 via native DNF
module streams, Apache with the default DocumentRoot (Moodle served at `/moodle`),
SELinux kept **Enforcing**. See `moodle_ol8_script_v2_action_plan.md` for the full design.

---

## Before you run

**1. Confirm the OS is Oracle Linux 8.x**

```bash
cat /etc/oracle-release
```
Expected: `Oracle Linux Server release 8.x`. This script is OL8-only — it uses DNF4
module streams, which do not exist on OL9/OL10.

**2. Confirm you have a sudo-capable user**

```bash
sudo -v && echo SUDO_OK
```
Run the installer as a normal sudo-capable user, **not** as root — the scripts call
`sudo` internally.

**3. Assume a fresh server**

The scripts do not clean up after a previous attempt. There must be no pre-existing
Apache/MariaDB/PHP configuration, no `moodle` database, and no `/var/moodledata`.

**4. Do not disable SELinux**

Step 11 applies the correct booleans and file contexts. SELinux stays Enforcing.

---

## Behind the corporate proxy

Servers arrive with the proxy pre-configured for `dnf` and `curl` by the network team,
but **`git` is not configured** and `git clone` will fail with a DNS resolution error.
Configure it explicitly first:

```bash
sudo dnf install -y git
git config --global http.proxy http://10.0.52.250:8080
git config --global https.proxy http://10.0.52.250:8080
```

On a server with direct Internet access, skip the two `git config` lines.
To undo them later:

```bash
git config --global --unset http.proxy
git config --global --unset https.proxy
```

---

## Install

```bash
git clone https://github.com/ShipwreckIII/Moodle-install-ol8.git
cd Moodle-install-ol8
chmod +x Install.sh
./Install.sh
```

**Verify the vendored tarballs survived the clone** before running:

```bash
file libsodium-2.0.23.tgz moodle-latest-405.tgz
```
Both must report `gzip compressed data` (~28 KB and ~80 MB). If either reports
`ASCII text`, it is a Git LFS pointer, not the real archive — re-clone.

`libsodium-2.0.23.tgz` and `moodle-latest-405.tgz` must stay at the repo root. The
scripts use them in place and never download anything.

---

## Prompts and resume

You are prompted once for three values: the server's IP address, the Moodle database
user password, and the MariaDB root password. These are saved to a local, gitignored
state file (`.install_state.tmp` / `.install_state.done`, chmod 600), so a rerun after
an interruption resumes from the failed step without re-prompting.

`Install.sh` orchestrates the 14 numbered steps under `steps/`. On rerun it offers:
run from start, resume from the first incomplete step (default), or run a single step.

---

## After the script

Open `http://<SERVER_IP>/moodle` and complete the web installer (environment checks,
database tables, admin account).

Admin password rules: 8+ chars, 1 digit, 1 lowercase, 1 uppercase, 1 special character.

If the final verification passed (HTTP 302/303) but the page is unreachable from a
client machine, the block is the **network path** between subnets, not this server —
request the network team open HTTP/HTTPS to it.

---

The v1 monolithic script is kept for reference in `legacy/Install.sh`.
