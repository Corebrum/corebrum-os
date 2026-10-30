# 0099. Power menu leaves Sway

Date: 2026-10-30
Status: Accepted

## Context

Super+Space Power asks again, then logs out, reboots, or powers off. Decision 0044 logged out with `hyprctl dispatch exit`, the same exit as Super+Shift+E on Hyprland. Decision 0080 replaced that session with Sway. Super+Shift+E is `bindsym $mod+Shift+e exit`. The Power menu still called `hyprctl`. On this machine that command is not installed, so Log out showed “hyprctl is not available” and stayed in the session.

## Decision

- Log out runs `swaymsg exit`. That is the same exit as Super+Shift+E. The greeter returns. Super+Shift+E stays immediate and does not ask.
- When `swaymsg` is missing, the menu reports that and does not reboot or power off.
- Reboot still runs `systemctl reboot`. Power off still runs `systemctl poweroff`.

## Consequences

After the Power menu script is installed, Log out returns to the greeter. A menu copied by an earlier desktop install keeps calling `hyprctl` until that script is replaced.
