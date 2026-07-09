# Moodle install ol8

# This is Eng.Ahmad 

## Usage

Installs Moodle 4.5 on Oracle Linux 8.x (PHP 8.2 + MariaDB 10.11 via native
DNF module streams, SELinux kept Enforcing). See
`moodle_ol8_script_v2_action_plan.md` for the full design.

```bash
git clone <this-repo-url>
cd Moodle-install-ol8
chmod +x install.sh
./install.sh
```

You'll be prompted once for three values: the server's IP address, the
Moodle database user password, and the MariaDB root password. These are
saved to a local, gitignored state file (`.install_state.tmp` /
`.install_state.done`, chmod 600) so a rerun after an interruption resumes
from the failed step without re-prompting.

`install.sh` orchestrates the 14 numbered steps under `steps/`. On rerun it
offers: run from start, resume from the first incomplete step (default), or
run a single step.

The vendored `libsodium-2.0.23.tgz` and `moodle-latest-405.tgz` must stay at
the repo root - the scripts use them in place and never download anything.

The v1 monolithic script is kept for reference in `legacy/Install.sh`.
