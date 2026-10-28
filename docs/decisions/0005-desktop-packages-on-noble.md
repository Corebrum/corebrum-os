# 0005. Desktop packages on Ubuntu 24.04

Date: 2026-10-22
Status: Accepted

## Context

Phase 2 needs a Hyprland session. Decision 0002 prefers Quickshell and requires a check against Ubuntu 24.04 before it is installed. The build plan also names Waybar, Fuzzel, Kitty, greetd, tuigreet, Thunar, Firefox, Mako, and a theme. It forbids unverified third-party repositories and replacing core graphical libraries.

On this Ubuntu 24.04 system the enabled archive is noble, noble-updates, noble-backports, and noble-security, with main, restricted, universe, and multiverse. `apt-cache policy` on 2026-10-22 returned no candidate for `hyprland`, `quickshell`, `tuigreet`, `hyprpaper`, or `xdg-desktop-portal-hyprland`.

The same lookup found archive candidates for Waybar 0.9.24, Kitty 0.32.2, Fuzzel 1.9.2, wofi 1.4.1, greetd 0.9.0 (which includes `agreety`), wlgreet 0.4.1, mako-notifier 1.8.0, Thunar, and the Ubuntu Firefox transitional package. Public Ubuntu package listings show `hyprland` in later releases, including 25.10 and 26.04 LTS, and `quickshell` in 26.04 LTS. Those packages are not installable from this 24.04 archive. The Hyprland wiki tells Ubuntu users not to build the stack by hand, because that replaces Wayland libraries and breaks.

The official Ubuntu 26.04 package `hyprland` 0.53.3+ds-4 was downloaded from Launchpad and inspected. Its `Depends` line requires `libwayland-server0` >= 1.23.0, `libxkbcommon0` >= 1.12.3, and `libinput10` >= 1.28.0, plus `libaquamarine9`, `libhyprcursor0`, `libhyprlang2`, and `libhyprutils10`. This system has `libwayland-server0` 1.22.0, `libxkbcommon0` 1.6.0, and an archive candidate of `libinput10` 1.25.0. Installing that deb here would replace those libraries. `ppa:cppiber/hyprland` publishes a noble build of Hyprland and also publishes its own `libinput`, `libxkbcommon`, and PipeWire. Launchpad labels that archive untrusted. It is not a Corebrum package source.

## Decision

- Phase 2 installs only packages from the Ubuntu 24.04 archive. It does not add a PPA and it does not build Hyprland or Quickshell from source.
- The installer asks `apt-cache` whether `quickshell` has a candidate. It does not, so the session uses Waybar, Fuzzel, and a Corebrum app grid. wofi draws that grid from `apps/dashboard/tiles.conf`. If a later archive publishes Quickshell and this repository ships a Quickshell config, the probe can select it. A candidate alone does not install an empty shell.
- The installer asks `apt-cache` whether `hyprland` has a candidate. A real `--profile desktop` run stops before it creates a log file, installs packages, copies configuration, or changes services when it does not. `--dry-run` still prints the intended actions and exits 0.
- tuigreet is not in the archive. The greeter is `agreety` from the Ubuntu `greetd` package. It runs on VT 7. VT 1 stays a getty so a failed Hyprland session still has a text console. wlgreet is not used, because that package depends on Sway.
- Firefox is the Ubuntu `firefox` package, which is the transitional snap. Mako's package name is `mako-notifier`.
- Configuration is installed under `/etc/corebrum` and passed on the command line. The installer does not write `~/.config`. `/etc/greetd/config.toml` is the one packaged file it replaces, after a backup under `/var/log/corebrum/backups`.
- `scripts/uninstall.sh --profile desktop` disables greetd and removes Corebrum-owned files. It does not remove Ubuntu packages.

## Consequences

Decision 0006 names `ppa:cppiber/hyprland` as that source. The pin in that decision is what keeps the rest of the PPA from replacing Ubuntu packages such as Waybar, Fuzzel, and PipeWire. Robotics packages stay out of this phase. Decision 0080 uses the archive Sway packages, including wlgreet, and does not add that PPA.
