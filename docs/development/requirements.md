# Development requirements

Phase 0 and Phase 1 checks need:

- Bash 4.3 or newer (`local -n` namerefs). Ubuntu 24.04 ships Bash 5.2.
- GNU Make
- ShellCheck, from the Ubuntu `shellcheck` package
- `timeout` from coreutils
- Outbound TCP to `archive.ubuntu.com` port 80 for `scripts/install.sh`, including `--dry-run`

`make check` runs ShellCheck, the unit tests, and `./scripts/install.sh --profile base --dry-run`. The dry-run still executes host preflight, so the machine running it must be Ubuntu 24.04 x86-64 with at least 8 GiB free on `/`. GitHub Actions uses `ubuntu-24.04` for that reason.

A real install additionally needs root and systemd (`timedatectl`). Do not point the real installer at a machine whose networking or disk layout you cannot restore. The acceptance target is a fresh virtual machine, documented in `docs/installation/ubuntu-server.md`.

Python is not used in this phase, so there is no pytest job. `shfmt` is not in the Ubuntu 24.04 archive; ShellCheck is the script check until an official formatting package is verified.

No third-party package repositories are configured by the base installer.
