# 0083. Corebrum logo on the Sway login and lock screens

Date: 2026-10-28
Status: Accepted

## Context

Decision 0037 drew `/usr/share/corebrum/logo.png` on gtkgreet and hyprlock. The file is 1104×320, with the circuit wordmark on a dark plate. Decision 0081 replaced the greeter with wlgreet 0.5.0-4. That greeter draws a 1024×128 card and has no image widget. Decision 0082 replaced the lock with gtklock, which can paint a CSS background. The login wallpaper is still `/usr/share/hypr/wall2.png`.

## Decision

- The greeter Sway starts `/usr/local/bin/corebrum-login-logo` beside wlgreet. The helper is `scripts/desktop/corebrum-login-logo.py`. It shows the logo at 759×220, centered, with its bottom 24px above the login card. It uses the layer shell on the top layer, so wlgreet's overlay card stays in front and keeps the keyboard. A missing logo file or a missing layer shell leaves the login card alone.
- gtklock paints the same file at the top of the centered card, at 759×220, with 244px of padding so the password field sits below it. The clock is in the top right. See `docs/decisions/0084-lock-clock-corner.md`.
- The desktop install still copies `config/brand/logo.png` to `/usr/share/corebrum/logo.png`. Neither screen writes `~/.config`.

## Consequences

After `sudo corebrum install desktop`, the next login and the next Super+Escape show the Corebrum logo above the prompt. A greeter that is already running keeps the previous screen until the next boot. The lock command picks up the logo when the gtklock style file is replaced, without a reboot.
