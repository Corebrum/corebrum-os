# 0044. Power menu

Date: 2026-10-25
Status: Accepted

## Context

Super+Escape locks the screen. Super+Shift+E exits Hyprland, and greetd shows the greeter again. Super+Space has no row for that exit, and the session has no row for reboot or power off. The desktop notes tell the operator to run `sudo reboot` or switch to the text console.

The person at the keyboard can reboot and power off. `org.freedesktop.login1.reboot` and `org.freedesktop.login1.power-off` allow the active session.

## Decision

- Super+Space lists Power. The rows are Log out, Reboot, and Power off. Choosing a row asks for that action again. Cancel, or closing the list, leaves the session running.
- Log out runs `hyprctl dispatch exit`, the same exit as Super+Shift+E. The greeter returns. Super+Shift+E stays immediate and does not ask.
- Reboot runs `systemctl reboot`. Power off runs `systemctl poweroff`. Neither action has a key binding.
- The three actions stay inside the Power menu. They are not separate desktop files, so the idle list does not show them and choosing a search hit opens Power rather than running the action. The Power entry's comment and keywords match log out, reboot, power off, shutdown, and sign out.
- The menu has no suspend row. A machine with cameras, Zenoh, and agents stays up until it is powered off.

## Consequences

A desktop install that already ran needs `sudo ./scripts/corebrum.sh install desktop` again so Super+Space lists Power. Uninstall removes the menu script. Log out, reboot, and power off still work from a terminal.
