# 0098. Login screen glitch

Date: 2026-10-30
Status: Accepted

## Context

`corebrum-login` draws the Corebrum logo and a centered username and password card. The wallpaper is the Sway background behind that window. The window was only as large as the card, and Sway centered it because it was not anchored to an edge. See `docs/decisions/0087-centered-login-lock.md`.

The lock screen already glitches about every 40 seconds. That effect needs a surface that covers the wallpaper: the logo shifts inside its own box, and scan lines, a short tint, and four colored bars cross the screen. The fields stay still. See `docs/decisions/0097-lock-glitch.md`.

The login client loads GTK 3, the same toolkit as gtklock 4.0.0. GTK 3 has no `transform` property, and a keyframe rule cannot list two percentages in one block.

## Decision

- `corebrum-login` anchors its layer-shell surface to every edge, so the window covers the output. The background stays transparent and the wallpaper remains the Sway image.
- The logo is a box named `login-logo`. Its image is the CSS background, at 759×220. The username and password card is the sibling below that box and is not part of the animation.
- The same 40 second burst as the lock screen plays on the logo, the scan lines, the tint, and the four bars. Login has no clock, so the clock and date shifts stay on the lock screen.
- The glitch widgets are overlay children with pass-through set. Clicks and keystrokes reach the fields.
- The style is `/etc/corebrum/greetd/login.css`. It uses only GTK 3.24 CSS. The `wlgreet` fallback stays the still logo, because that client cannot host these overlays.

## Consequences

After `sudo corebrum install desktop`, the next greetd start plays the glitch on the login screen. A greeter that is already up keeps the previous client until greetd starts again. Enter still submits the username and password.
