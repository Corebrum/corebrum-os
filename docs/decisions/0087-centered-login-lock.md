# 0087. Centered login and lock fields

Date: 2026-10-28
Status: Accepted

## Context

wlgreet 0.5.0-4 draws one 1024×128 surface. The word Login is DejaVu Sans Mono at 72px, placed 32px from the left. The username prompt is 32px and starts at x=256. The config file can change colors. It cannot change the text, the size, or the position. On this screen the word is taller than the fields, and the fields sit in the left half of the bar.

gtklock's password form was a grid: the Password label in the first column and the entry in the second. The logo behind that form is 759px wide and centered. The label-plus-entry row was left-aligned in that width, and Unlock was aligned to the end of the row.

## Decision

- The greeter Sway runs `/usr/local/bin/corebrum-login`. That client speaks the greetd socket protocol and draws one layer-shell surface: the Corebrum logo at 759×220, then a centered card with a username field and a password field. There is no Login title. Enter in the username field moves to the password. Enter in the password field submits both. Sway centers the surface because it is not anchored to an edge.
- The same command is installed from `scripts/desktop/corebrum-login.py`. Its style is `/etc/corebrum/greetd/login.css`. A missing `GREETD_SOCK`, display, or layer shell exits, and `/usr/local/bin/corebrum-greeter` then starts the logo helper and `wlgreet`.
- The lock layout keeps every widget id gtklock looks up. The password field is 380px, centered under the logo, with the placeholder Password. The Password label stays in the layout and is not shown. Unlock is centered under the field. The clock stays in the top right.

## Consequences

The next boot shows the centered login card. A greeter that is already running keeps the wlgreet bar until greetd starts again. Super+Escape picks up the centered lock form when the gtklock layout and style are installed, without a reboot. A failed `corebrum-login` still reaches wlgreet, whose Login word and left-aligned prompt are unchanged.
