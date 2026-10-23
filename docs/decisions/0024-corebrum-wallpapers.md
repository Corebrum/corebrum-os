# 0024. Corebrum wallpapers replace the Hyprland defaults

Date: 2026-10-23
Status: Accepted

## Context

Ubuntu 26.04 publishes the Hyprland wallpaper as `hyprland-backgrounds`: `/usr/share/hypr/wall0.png`, `wall1.png`, and `wall2.png`. Login and lock use `wall2.png`. The wallpaper menu lists every `wall*.png` in that directory. The operator added four Corebrum images at `config/hypr/wallpapers/wall0.png` through `wall3.png`.

Those packaged paths are not conffiles. A later `hyprland-backgrounds` upgrade would replace a plain copy of `wall0.png`, `wall1.png`, and `wall2.png`. Ubuntu 24.04 does not publish the package, so a copy is the only image those paths have.

## Decision

- The desktop install copies `config/hypr/wallpapers/wall0.png` through `wall3.png` to `/usr/share/hypr`.
- Each path is diverted with `dpkg-divert --local` to `wallN.png.hyprland` before the Corebrum file is installed. A package upgrade writes the upstream image to the diverted name.
- Login, lock, and the wallpaper menu keep using `/usr/share/hypr/wallN.png`. The menu labels them `Corebrum wallN.png`.
- Uninstall removes the Corebrum files and the diversions, which puts the packaged images back when they were diverted.

## Consequences

A new desktop install shows the Corebrum images instead of the Hyprland defaults, including on the login and lock screens. `wall3.png` is an extra image the Hyprland package does not ship. `lockdead.png` and `lockdead2.png` stay as packaged files and are not listed by the wallpaper menu.
