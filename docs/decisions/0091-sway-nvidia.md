# 0091. Sway starts on the proprietary NVIDIA driver

Date: 2026-10-29
Status: Accepted

## Context

The desktop install on this NVIDIA Jetson AGX Orin Developer Kit (Ubuntu 24.04, aarch64, kernel `6.8.12-1021-tegra`) enabled greetd. After reboot, greetd opened a session for `_greetd` and that session exited at once. systemd hit the start limit and left the display on the Sway error. Sway 1.9 logs it from `sway/main.c:62`: proprietary NVIDIA drivers are not supported, and the launch switch is `--unsupported-gpu`. The check reads `/proc/modules` for a line starting with `nvidia `. This machine has that line. `nvidia_drm` modeset is `Y`. wlroots ignores `/dev/dri/card1` (host1x, not a KMS device) and uses `/dev/dri/card2` (`nvidia-drm`). DisplayPort `DP-1` is connected.

A probe of `sway --unsupported-gpu` as root passed that check, modeset `DP-1` at 1920x1080 @ 60 Hz, and allocated a GBM buffer with the NVIDIA EGL driver. The hardware cursor could not pick a format, and wlroots used a software cursor. The same command as this account, which is in `video` and `render`, also modeset and exited cleanly. greetd runs Sway as `_greetd`, whose only group is `_greetd`. `/dev/dri/card2` and `/dev/nvhost-*` are group `video`. `/dev/dri/renderD128` is group `render`. `/dev/nvmap` is group `video` and has no logind `uaccess` tag, so the active session never receives it. Sway then logged `NvRmMemMgrInit failed` and exited, and greetd hit its start limit. Decision 0090 left this GPU path alone.

## Decision

- `corebrum-greetd` and `corebrum-session` call `corebrum_prepare_nvidia_sway` before they start Sway. When `/proc/modules` has a line starting with `nvidia `, they export `WLR_NO_HARDWARE_CURSORS=1` and run `sway --unsupported-gpu --config` with the same config path as before. Tests may point `COREBRUM_PROC_MODULES` at another file.
- A modules list that has `nvidia_drm` or `nouveau`, or no readable modules file, keeps `sway --config` and does not set that cursor variable. A Raspberry Pi still uses the vc4 helper.
- The installer does not change the kernel command line. On this Orin, `nvidia_drm` modeset was already enabled.
- The desktop install adds `_greetd` to `video` and `render` when that user and those groups exist and the user is not already a member. A dry-run only logs that step. Uninstall leaves the groups in place.

## Consequences

The greeter and the session on this Orin start Sway. The same launch covers any machine where the proprietary `nvidia` module is loaded, including a discrete GPU. `_greetd` can open the DRM and NVIDIA nodes on the next greetd login. Sway still logs that the driver is unsupported. That is the upstream switch, and Corebrum does not patch Sway.
