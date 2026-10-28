# 0081. wlgreet runs in Sway

Date: 2026-10-28
Status: Accepted

## Context

`sudo corebrum install desktop` on this resolute workstation enabled greetd and set the default target to `graphical.target`. After reboot the display stayed on the boot screen. Ctrl+Alt+F1 reached a text console. `greetd.service` was failed with `start-limit-hit`. Each attempt logged `check_children: greeter exited without creating a session` and the greeter session closed in under a second.

The greeter command was `cage -s -d` running wlgreet 0.5.0-4. That wlgreet panics with `server didn't advertise zwlr_layer_shell_v1` when the compositor has no layer-shell. Ubuntu `cage` 0.2.1-1 does not implement that protocol. The wlgreet readme says cage is unsupported for this reason. The `wlgreet` package ships `/etc/greetd/sway-config`, which runs wlgreet and then `swaymsg exit`.

## Decision

- greetd still runs `/usr/local/bin/corebrum-greetd` as `_greetd` on VT 7.
- That wrapper starts `sway --config /etc/corebrum/greetd/sway-config` after the existing Pi DRM helper. It does not start cage.
- The greeter Sway config runs `/usr/local/bin/corebrum-greeter` and then `swaymsg exit`. The greeter script still runs `/usr/sbin/wlgreet` with `/etc/corebrum/greetd/wlgreet.toml`. The session command stays `/usr/local/bin/corebrum-session`. The greeter background is `/usr/share/hypr/wall2.png`.
- The desktop profile still installs `wlgreet` when the archive has a candidate. It does not install `cage` for the login screen. A missing `wlgreet` keeps agreety. VT 1 stays a text console.

## Consequences

A desktop install shows the login screen on the next boot. A machine that already installed the cage greeter picks this up when these files are replaced and greetd is restarted. A cage package left from the earlier install is unused.
