# 0092. Install the Firefox snap when the launcher is missing

Date: 2026-10-29
Status: Accepted

## Context

The desktop profile lists Ubuntu's `firefox` package. On noble that package is `1:1snap1-0ubuntu5`, a transitional deb. Its preinst runs `snap install firefox` while the deb is unpacked, and it skips that step when `/run/snapd.socket` is absent. After the deb is configured, installing the same version again does not unpack it, so the preinst does not run.

This NVIDIA Jetson AGX Orin (Ubuntu 24.04, aarch64, kernel `6.8.12-1021-tegra`) already had that deb. `dpkg` reports it installed, `/usr/bin/firefox` is the wrapper that asks for the snap, and `snap list` has no Firefox. `/var/lib/snapd/snaps` has been empty since the image was built. The desktop install on 2026-10-29 included `firefox` in `apt-get install`. Apt left the package as it was. Super+Shift+Return, Getting Started, and Corebrum Cloud all run `firefox`.

`snap find` on this machine lists `firefox` 159.0-1 from Mozilla. The kernel has `squashfs` and `overlay` built in. Decision 0005 keeps Firefox as this Ubuntu package. Decision 0014 leaves Chromium as a separate Super+Space install.

## Decision

- After the desktop package install, `corebrum_install_firefox_snap` runs `snap install firefox` when `/snap/bin/firefox` is missing. Tests may point `COREBRUM_FIREFOX_BIN` at another path.
- When that launcher is already executable, the step logs that the snap is installed and does not run `snap` again.
- A dry-run logs `snap install firefox` and does not contact the store.
- Uninstall still leaves Ubuntu packages and this snap in place.

## Consequences

A desktop install on a Jetson image that shipped only the transitional deb installs the Firefox snap. A machine that already has `/snap/bin/firefox` is unchanged. `scripts/validate/desktop.sh` requires that launcher. The unit tests do not download the snap. On this Orin, `snap install firefox` installed 159.0-1, and `/usr/bin/firefox --version` printed `Mozilla Firefox 159.0`.
