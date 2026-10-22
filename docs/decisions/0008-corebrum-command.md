# 0008. The corebrum command

Date: 2026-10-22
Status: Accepted

## Context

Phases 1–3 install the base profile, the Hyprland session, and workstation services through `scripts/install.sh --profile`. Phase 4 asks for one command that can install, report status, diagnose, and show configuration, with a headless profile and a desktop profile. A second run must not duplicate configuration, and a failure must say what to do next. User home directories stay untouched.

A fresh virtual-machine install is the acceptance check for a machine that does not already run Corebrum. CI only runs lint, unit tests, and `--dry-run`. It does not install a profile onto the runner.

## Decision

- `scripts/corebrum.sh` is the command. A real install links it to `/usr/local/bin/corebrum`. The link points at the checkout, so the command and the checkout stay the same files.
- `corebrum install base` is the headless profile. `corebrum install headless` is that same profile. `corebrum install desktop` installs base, the Hyprland session, and workstation services.
- `--enable-ssh` is the optional feature. `--dry-run` still changes nothing.
- `corebrum status`, `corebrum doctor`, `corebrum config`, and `corebrum version` are read-only.
- `corebrum doctor` runs the base, desktop, and services validators when those pieces are present and prints the next install command when one fails. It also rejects duplicate keys in `/etc/corebrum/desktop.state`.
- Configuration copies still go through the existing backup helper. State keys are recorded once. The command does not write `~/.config`.
- The branded menu is the app grid, named Corebrum, with Fuzzel's prompt set to Corebrum and a desktop entry at `/usr/local/share/applications/corebrum-grid.desktop`.
- Install logs stay in `/var/log/corebrum`. A failed install tells you to read `install-latest.log` and run `corebrum doctor`.
- The VM procedure is documented in `docs/installation/cli.md`. It is not part of `make check`.

## Consequences

Desktop uninstall removes the desktop entry and the other Corebrum desktop files. It leaves `/usr/local/bin/corebrum` in place so the checkout command still has a PATH name. ROS 2 is still not part of this command.
