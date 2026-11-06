# 0124. Waybar battery module

Date: 2026-11-06
Status: Accepted

## Context

`config/waybar/config.json` lists `battery` in `modules-right` with `format` and charging states so low charge can show warning and critical styling. `docs/installation/desktop.md` described the top bar as ending at network and clock, without volume, battery, Cloud, or tray, which did not match the shipped config or `docs/installation/services.md`.

Bluetooth status stays off the bar module list because Blueman provides a tray icon; see `tests/unit/test_services_config.sh`.

## Decision

- The desktop docs describe the Waybar top bar in the same order as `modules-right`: CPU, memory, network, volume (`pulseaudio`), battery, Corebrum Cloud (`custom/cloud`), tray, and clock.
- Laptops and other systems with a power supply show the battery segment; Waybar omits the module when there is no battery device.

## Consequences

Operators reading `docs/installation/desktop.md` see the same modules as on screen. Unit tests continue to require `battery` in `config/waybar/config.json`.
