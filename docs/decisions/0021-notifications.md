# 0021. Notifications are Mako popups

Date: 2026-10-22
Status: Accepted

## Context

The desktop profile already installs `mako-notifier` and starts it with the session. Mako owns `org.freedesktop.Notifications`. The volume and brightness keys changed the level and showed nothing, and `notify-send` was not installed, so applications had no command to raise a popup.

## Decision

- The desktop profile also installs `libnotify-bin`, which provides `notify-send`.
- Volume, mute, microphone mute, and brightness keys run `corebrum-osd`. That command changes the level and sends one Mako notification with a progress value. A repeated press replaces the previous popup.
- Mako draws on the overlay layer at the top right, above the bar and above a fullscreen window. The history buffer keeps the last 20 expired notifications.

## Consequences

Brightness uses only a display backlight. A machine without one still shows a popup that says there is no display brightness control, and the keys do not change keyboard LEDs. Uninstall removes the helper script and leaves the `mako-notifier` and `libnotify-bin` packages installed.
