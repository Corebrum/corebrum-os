# Ubuntu Server 24.04 and 26.04 base install

Phase 1 turns a fresh Ubuntu Server 24.04 or 26.04 LTS system, x86-64 or ARM64, into the Corebrum base profile. It installs a short package list, generates the `en_US.UTF-8` locale, and enables systemd-timesyncd when NTP is off. It does not install a desktop, ROS 2, Zenoh, or OpenSSH unless you pass `--enable-ssh`. Other Ubuntu releases are rejected.

The installer does not edit Netplan, NetworkManager, `sshd_config`, or the bootloader.

## Acceptance target

Accept Phase 1 on a new virtual machine, not on a workstation that already has a desktop. This repository's development machine can run `--dry-run` and the unit tests. That is not acceptance.

Recommended VM resources: 2 CPUs, 4 GiB RAM, 20 GiB disk. The installer refuses to continue when `/` has less than 8 GiB free.

Use the Ubuntu Server 24.04 or 26.04 LTS ISO for x86-64 or arm64. If you use Multipass, confirm the `multipass` command exists on the host first, and that it can launch `24.04` or `26.04`. An unverified example, once Multipass is installed, is:

```bash
multipass launch 26.04 --name corebrum-base --disk 20G --memory 4G --cpus 2
```

Copy this repository onto the VM. Do not pipe the installer from the network. On a server that does not have `git` yet:

```bash
sudo apt update
sudo apt install -y git ca-certificates
git clone https://github.com/Corebrum/corebrum-os.git
cd corebrum-os
```

The base profile then installs `curl`, `tmux`, and `nano`, and updates APT again. OpenSSH is the `--enable-ssh` flag below, which also runs `systemctl enable --now ssh`. After that, `hostname -I` shows an address for the connection. Cursor's agent installer, `agent login`, and edits to `~/.bashrc` are not part of this profile.

## Dry-run

```bash
./scripts/install.sh --profile base --dry-run
```

The command checks architecture, Ubuntu `noble` or `resolute`, free disk, and a TCP connection to `archive.ubuntu.com` port 80. It prints the `apt-get` install it would run. It must not install packages or write `/etc` or `/var`.

## Install

```bash
sudo ./scripts/install.sh --profile base
sudo ./scripts/validate/base.sh
```

Logs are written to `/var/log/corebrum/install-<timestamp>.log`, with `install-latest.log` pointing at the newest file. If `/etc/locale.gen` or `/etc/default/locale` is changed, the previous file is copied to `/var/log/corebrum/backups/`.

Optional SSH, without rewriting `sshd_config`:

```bash
sudo ./scripts/install.sh --profile base --enable-ssh
```

## Two-pass check

1. Confirm the VM still has a default route: `ip -4 route show default`.
2. Run the install, then `sudo ./scripts/validate/base.sh`.
3. Reboot.
4. Run `sudo ./scripts/validate/base.sh` again and confirm the default route is still present.
5. Run `sudo ./scripts/install.sh --profile base` a second time.
6. Run `sudo ./scripts/validate/base.sh` again.

The second install is successful when validation still passes, no duplicate locale lines are added, and the log says the locale and NTP steps found the existing configuration. Package installation may still run `apt-get install`; APT treats already-installed packages as up to date.

## Removal

`./scripts/uninstall.sh` exits with an error. Phase 1 does not have a product package to remove, and it will not uninstall Ubuntu packages such as `ca-certificates` or `git`.

## What remains

The procedure above is the one to repeat on a fresh Ubuntu Server 24.04 or 26.04 machine, x86-64 or ARM64.

Phase 2 is documented in `docs/installation/desktop.md`. Sway comes from the Ubuntu archive on both releases. Phase 3 workstation services are documented in `docs/installation/services.md`. They leave the existing Netplan Ethernet configuration in place.
