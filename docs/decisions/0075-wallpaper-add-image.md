# 0075. Wallpaper can add an image

Date: 2026-10-27
Status: Accepted

## Context

Super+Space Wallpaper lists the Corebrum images in `/usr/share/hypr` and the PNG, JPEG, and WebP files already in `~/Pictures` and `~/Pictures/Wallpapers`. An image kept somewhere else, such as Downloads, does not appear until it is copied into one of those folders.

## Decision

- The wallpaper list starts with Add image.
- Choosing it opens the GTK file chooser. A PNG, JPEG, or WebP is copied into `~/Pictures/Wallpapers`. A name that is already there gets a numeric suffix. The copy is then set with the existing hyprpaper path.
- The copy stays in the home directory. Login and lock stay on `/usr/share/hypr/wall2.png`.
- The menu does not install a package and does not write `~/.config`.

## Consequences

The next Super+Space after the wallpaper menu script is copied can add an image that was not already in the picture folders.
