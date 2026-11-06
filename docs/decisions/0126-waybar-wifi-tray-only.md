# 0126. Waybar Wi-Fi only in the tray

Date: 2026-11-06
Status: Accepted

## Context

The desktop profile runs Blueman’s applet in the Waybar tray. Its menu shows the current Wi‑Fi network and controls. The Waybar `network` module also drew a Wi‑Fi indicator (including a compact 📶 glyph), so operators saw two Wi‑Fi icons (often described as the orange Blueman icon and a separate bar segment).

## Decision

- Remove the `network` module from `config/waybar/config.json` `modules-right` and drop the `network` block from that config. Ethernet and Wi‑Fi status remain available from the tray applet and the app grid Network row; this change only removes the duplicate on-bar indicator.
- Drop `#network` from `config/waybar/style.css` padding rules since the module is absent.
- `tests/unit/test_services_config.sh` no longer requires a `network` block in the Waybar JSON.

## Consequences

Waybar shows a single Wi‑Fi affordance in the tray. Machines that relied on the bar for interface names or IP addresses should use Blueman, `nmcli`, or `ip` instead.
