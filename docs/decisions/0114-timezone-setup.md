# 0114. Setup Timezone uses Fuzzel and timedatectl

Date: 2026-11-02
Status: Accepted

## Context

Omarchy lists Timezone and Time under its Update menu. Corebrum Updates stays software-only (`0045`). Operators still need a way to fix a wrong zone on images that default to UTC. Ubuntu’s `gnome-control-center system datetime` panel exits outside GNOME and Unity, so it cannot run under the Corebrum Sway session. The base profile already enables NTP and does not set a timezone.

## Decision

- Super+Space Setup lists Timezone after Autolock. The row name includes the current zone when `timedatectl` reports one.
- Choosing it opens a Fuzzel list of `timedatectl list-timezones`, with the current zone first. Escape cancels.
- Applying a zone runs `pkexec timedatectl set-timezone`. When `pkexec` is missing, a Kitty terminal runs `sudo timedatectl set-timezone` instead.
- There is no manual set-time row. NTP remains the clock source from the base profile.
- GNOME Control Center is not installed or launched for this.

## Consequences

Waybar and the login/lock clocks follow the new zone without a Sway reload. A successful change sends a Mako notification. Typing timezone or tz at Super+Space finds the row.
