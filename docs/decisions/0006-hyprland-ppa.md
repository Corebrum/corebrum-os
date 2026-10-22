# 0006. Hyprland from ppa:cppiber/hyprland

Date: 2026-10-22
Status: Accepted

## Context

Decision 0005 found no `hyprland` package in Ubuntu 24.04. The official Ubuntu 26.04 package needs a newer Wayland, libxkbcommon, and libinput than 24.04 ships. The operator asked Corebrum to use `ppa:cppiber/hyprland` anyway.

Launchpad publishes that archive as `~cppiber/+archive/ubuntu/hyprland`. Its signing key fingerprint is `A54D23B62FF3FCC76EFF71E8FDBAAA1CF0CCF48E`, and the keyserver key with that fingerprint is named "Launchpad PPA for Constantin Piber". The noble suite's origin is `LP-PPA-cppiber-hyprland`. On 2026-10-22 it published `hyprland` 0.56.2-1ppa2.

That package depends on `libwayland-server0` >= 1.22.0, which matches this system, and on newer `libinput10` (>= 1.30.0) and `libxkbcommon0` (>= 1.12.3). Ubuntu 24.04 has libinput 1.25.0 and libxkbcommon 1.6.0, so installing Hyprland from this PPA replaces those libraries with the PPA builds. `libxkbcommon-x11-0` and `libxkbregistry0` depend on the exact Ubuntu `libxkbcommon0` version, so they are upgraded from the same PPA together with `libxkbcommon0`. It also installs Hyprland libraries that Ubuntu does not ship: aquamarine, hyprcursor, hyprgraphics, hyprlang, hyprutils, hyprwire, libdisplay-info3, libudis86.1, libxcb-errors1, and hyprland-data. The same PPA publishes newer Waybar, Fuzzel, PipeWire, and wayland-protocols. Those are not required by the Hyprland dependency line that Ubuntu cannot already satisfy.

Launchpad labels personal archives untrusted. This decision accepts that for this one named archive.

## Decision

- When `apt-cache policy` shows no `hyprland` version from `archive.ubuntu.com` or `security.ubuntu.com`, the desktop profile adds `ppa:cppiber/hyprland` for noble.
- The installer downloads the signing key, refuses it unless the fingerprint is `A54D23B62FF3FCC76EFF71E8FDBAAA1CF0CCF48E`, and stores it at `/usr/share/keyrings/corebrum-cppiber-hyprland.gpg`.
- `/etc/apt/preferences.d/corebrum-cppiber-hyprland` sets that origin to priority 100, then sets priority 500 only for the packages in `manifests/packages/hyprland-ppa.txt`. Waybar, Fuzzel, PipeWire, and wayland-protocols stay on the Ubuntu archive.
- The desktop package install uses `--no-install-recommends`, so Hyprland's recommendation of PipeWire and a second notification daemon is not pulled in.
- If Ubuntu later publishes `hyprland`, the installer does not add this PPA.
- Desktop uninstall removes the source, the pin, and the key. It does not remove the packages already installed.

## Consequences

A desktop install on Ubuntu 24.04 upgrades libinput and libxkbcommon to the PPA versions. That is a core input-stack change, accepted here because Hyprland 0.56.2 will not install against the Ubuntu versions. Quickshell is still not part of this phase.
