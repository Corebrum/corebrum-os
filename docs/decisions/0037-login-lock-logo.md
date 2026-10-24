# 0037. Corebrum logo on login and lock

Date: 2026-10-23
Status: Accepted

## Context

Login and lock already use `/usr/share/hypr/wall2.png`. `gtkgreet` 0.8 draws a clock and a box named `body` for the username and password. It has no image widget. That clock and card live in a box named `window`, and the stylesheet can paint a background there. `hyprlock` 0.9.2 has an image widget. Its `size` value is the length of the shorter side. The default rounding is `-1`, which crops the image to a circle, and the default border is 4px.

The artwork stores the white circuit mark in the color channels. Most of those pixels have an alpha near 0, so a compositor drops them. `wall2.png` is bright through the center, so the mark needs a dark plate behind it.

## Decision

- The desktop install copies `config/brand/logo.png` to `/usr/share/corebrum/logo.png`. The file is 1104×320. It is the circuit wordmark with alpha rebuilt from the color, on a rounded plate of `rgba(28, 28, 28, 0.88)`. Uninstall removes the file and the directory.
- `gtkgreet.css` paints that file at the top of `box#window`, at 759×220, which keeps the file's aspect. The clock and the login card follow it. The wallpaper stays on the window.
- `hyprlock.conf` adds an image widget for `/usr/share/corebrum/logo.png` with `size = 220`, `rounding = 0`, and `border_size = 0`. The widget is centered above the password field.
- Ubuntu 24.04 still has no `gtkgreet` or `hyprlock`. The file is installed with the desktop profile and unused on that release.

## Consequences

A 26.04 login and a Super+Escape lock show the Corebrum logo above the prompt. The login copy is stretched if the PNG is replaced with a different aspect, because the stylesheet sets both width and height. hyprlock scales the shorter side to 220px and keeps the file's aspect. A running greeter keeps the previous screen until the next time it starts.
