# 0135. Mac display and Touch Bar brightness

Date: 2026-11-14
Status: Accepted

## Context

MacBook models with a Touch Bar expose two `backlight` devices: `appletb_backlight` for the strip and `intel_backlight`, `apple-panel-bl`, or similar for the main panel. `brightnessctl -c backlight` is ambiguous on those machines. Operators reported that Touch Bar brightness responded while display dimming did not.

Omarchy separates the devices in `omarchy-brightness-display` and binds Shift with the multimedia brightness keys for the Touch Bar.

## Decision

- `scripts/lib/backlight.sh` picks a **display** device with the same order as Omarchy (`amdgpu_bl*`, `intel_backlight`, `apple-panel-bl`, `acpi_video*`, then any other backlight except `appletb_backlight`).
- `corebrum-osd` uses that device for `brightness-up` and `brightness-down`. `touchbar-brightness-up` and `touchbar-brightness-down` use `appletb_backlight` when it is present.
- `corebrum-display-dim` saves and restores brightness on the display device only.
- Sway and Hyprland bind Shift+`XF86MonBrightnessUp` and Shift+`XF86MonBrightnessDown`, and `XF86KbdBrightnessUp` and `XF86KbdBrightnessDown`, to the Touch Bar helpers. Unmodified `XF86MonBrightness*` stays on the main panel.

## Consequences

Machines with a single backlight are unchanged. Touch Bar keys without a strip show a short Mako line that Touch Bar control is unavailable. The library is installed to `/usr/local/lib/corebrum/backlight.sh`.

Brightness keys need the `brightness-udev` package and membership in the `video` group. The desktop install adds `SUDO_USER` to `video` and `input` when those groups exist. A running session keeps its old group list until the user logs out and signs in again; `swaymsg reload` is not enough for that.