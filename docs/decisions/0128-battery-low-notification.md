# 0128. Battery low desktop notification

Date: 2026-11-06
Status: Accepted

## Context

Waybar already shows battery percentage and critical styling near empty (`docs/decisions/0124-waybar-battery.md`). Operators on laptops may not watch the bar continuously and asked for a Mako popup when charge is critically low.

## Decision

- `/usr/local/bin/corebrum-battery-notify` runs in the graphical session after Mako starts. It polls the first sysfs supply with `type=Battery` under `COREBRUM_BATTERY_SYSFS` (default `/sys/class/power_supply`).
- While **Discharging** and capacity is **at or below 10%** (default, `COREBRUM_BATTERY_NOTIFY_THRESHOLD`), it runs `notify-send --app-name=Corebrum --urgency=critical` once until the pack is above the threshold again or the machine stops discharging (charging / full / plugged). State is stored under `${XDG_STATE_HOME:-~/.local/state}/corebrum/battery-notify-low`.
- Poll interval defaults to 30 seconds (`COREBRUM_BATTERY_NOTIFY_INTERVAL`). Machines without a battery supply exit the loop after each sleep without error.
- Sway starts this helper after `mako`; Hyprland uses `exec-once` in the same order for sessions that still use that config.

## Consequences

A second drop below 10% after charging above it notifies again. Over-10% discharging does not clear an unrelated prior marker beyond the documented paths. Uninstall removes the script with other Corebrum desktop paths.
