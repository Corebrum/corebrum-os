# 0017. Session tagline replaces the Hyprland splash

Date: 2026-10-22
Status: Accepted

## Context

Hyprland draws a random line from a compiled list at the bottom of the wallpaper. One of those lines is `Save your mercy for someone who needs it more`. The 0.53 config can disable that rendering and change its color and font. It cannot set the text. The operator asked for `Corebrum: The Physical AI Operating System` in that place.

## Decision

- `misc:disable_splash_rendering` is true in the session config. Hyprland does not draw its splash quotes.
- The same Waybar process draws a second bar named `tagline` at the bottom of the wallpaper. It is not exclusive and it passes pointer events through. Its only text is `Corebrum: The Physical AI Operating System`.
- The top bar is unchanged.

## Consequences

The tagline is covered by windows, as the splash quote was. It appears again when the wallpaper is visible. Changing the sentence means editing the Waybar config and restarting Waybar. Hyprland paints the splash into the wallpaper image when that image is first built. A config reload that leaves the monitor size unchanged keeps the old image, quote included. The quote is absent from a new session, and from a running session after the monitor size changes.
