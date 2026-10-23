# 0015. hyprlock and a gtkgreet login

Date: 2026-10-22
Status: Accepted

## Context

The desktop login is `agreety` on VT 7, a text prompt. There is no screen locker. `hyprpaper` only draws a background inside a running Hyprland session, so it cannot lock the screen or run before login.

On 2026-10-22 the Ubuntu 26.04 archive published `hyprlock` 0.9.2-1build4, `gtkgreet` 0.8-2, and `cage` 0.2.1-1. The `hyprlock` package ships `/usr/share/hypr/hyprlock.conf` and a PAM file that includes `login`. Its manual names `general:immediate_render` and a background widget. `gtkgreet` requires a Wayland compositor and exits after a successful login; its manual says `cage gtkgreet` is the setup, and the compositor must exit when gtkgreet exits. `cage -s` allows VT switching. Ubuntu 24.04's universe archive published `cage` 0.1.5 and did not publish `hyprlock` or `gtkgreet`.

The default wallpaper file on 26.04 is `/usr/share/hypr/wall2.png` from `hyprland-backgrounds`. Super+L already moves focus right.

## Decision

- When `apt-cache` has candidates for `hyprlock`, `gtkgreet`, and `cage`, the desktop profile installs them from the Ubuntu archive. Ubuntu 24.04 skips `hyprlock` and `gtkgreet` and keeps the `agreety` greeter.
- The 26.04 greeter command is `cage -s -d` running `/usr/local/bin/corebrum-greeter`. That script runs `gtkgreet --command /usr/local/bin/corebrum-session --disable-custom-commands`. The stylesheet is `/etc/corebrum/greetd/gtkgreet.css`, and it uses `wall2.png` as the login background. The command dropdown is hidden because that session command is the only choice. gtkgreet still asks for the username, then replaces that form with the password prompt. VT 7 stays the greeter. VT 1 stays a text console because cage is started with `-s`.
- Super+Escape runs `/usr/local/bin/corebrum-lock`, which runs `hyprlock --config /etc/corebrum/hypr/hyprlock.conf`. The lock screen uses the same `wall2.png`. The installer does not write `~/.config/hypr/hyprlock.conf`.
- A running session is left alone. greetd is not restarted by this change. The new login screen appears the next time the greeter starts.

## Consequences

Ubuntu 24.04 still logs in through `agreety`. A 26.04 desktop install replaces the text greeter with gtkgreet. If that greeter fails, VT 1 is still a text console. Uninstall restores the previous greetd config from the recorded backup and removes the Corebrum lock and greeter files. It does not remove the `hyprlock`, `gtkgreet`, or `cage` packages.
