# 0072. arm64 Ubuntu packages come from ports.ubuntu.com

Date: 2026-10-27
Status: Accepted

## Context

Desktop install on an ArmSoM Sige7, Ubuntu 26.04 resolute, `aarch64`, stopped with:

`hyprland is not in the Ubuntu archive on resolute; ppa:cppiber/hyprland is only used on noble`

`apt-cache policy hyprland` on that machine shows `0.53.3+ds-4` from `http://ports.ubuntu.com resolute/universe arm64 Packages`. The same host publishes `hyprpaper`, `hyprlock`, `hypridle`, `gtkgreet`, `cage`, `waybar`, `fuzzel`, `greetd`, and `hyprland-qtutils`. Decision 0060 recorded those versions on a Raspberry Pi. Decision 0063 says a new install takes Hyprland from the Ubuntu 26.04 archive and does not add a Hyprland PPA.

`corebrum_policy_ubuntu_version` treated only `archive.ubuntu.com` and `security.ubuntu.com` as Ubuntu. Official arm64 indexes are published on `ports.ubuntu.com`, including the `resolute-security` pocket. The empty result made the desktop profile plan the noble PPA, then refuse it because the codename is resolute. Phase 3 uses the same check and would have stopped on the first workstation package.

## Decision

- A package version whose `apt-cache policy` line names `archive.ubuntu.com`, `security.ubuntu.com`, or `ports.ubuntu.com` is an Ubuntu archive version.
- A personal archive is still ignored. When a PPA line is listed before a ports line, the ports version is the one that counts.
- resolute still does not add `ppa:cppiber/hyprland`.

## Consequences

An aarch64 resolute desktop install can see Hyprland and the workstation packages that are already in the ports archive. x86-64 policy lines are unchanged. A resolute machine whose apt indexes do not include `hyprland` still stops instead of adding the noble PPA.
