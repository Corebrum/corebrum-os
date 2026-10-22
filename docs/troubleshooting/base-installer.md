# Base installer

## Preflight failures

Ubuntu `noble` or `resolute` is required. `/etc/os-release` must contain `VERSION_CODENAME=noble` or `VERSION_CODENAME=resolute`. Other Ubuntu releases, including jammy, stop before any package is installed.

`x86_64` is the only architecture in this phase. ARM64 is a later phase.

The root filesystem needs 8 GiB free. `df -Pk /` reports the value the installer checks.

`archive.ubuntu.com` port 80 must accept a TCP connection. A DNS name that does not answer is a failed preflight, including for `--dry-run`.

## Installer stops midway

Read `/var/log/corebrum/install-latest.log` and run `corebrum doctor`. Re-run `sudo corebrum install base`. APT and the locale steps are safe to repeat. Files the installer edits are copied to `/var/log/corebrum/backups/` first.

## Validation fails after install

`./scripts/validate/base.sh` prints each missing package. Install the base profile again. A missing default route means networking changed outside this installer; Phase 1 does not edit Netplan.

## OpenSSH

SSH is installed only with `--enable-ssh`. The installer enables `ssh.service` and does not change `sshd_config`.

## Removal

`scripts/uninstall.sh` with no profile, and `scripts/uninstall.sh --profile base`, refuse to remove packages. The base profile uses ordinary Ubuntu packages, and uninstalling them can remove tools the rest of the system needs. Desktop removal is separate and is documented in `docs/installation/desktop.md`.
