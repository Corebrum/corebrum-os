# 0060. ARM64 desktop beside x86-64

Date: 2026-10-26
Status: Accepted

## Context

Preflight accepted Ubuntu noble and resolute on x86-64 only. Decision 0010 records that limit. Phase 14 is the ARM64 expansion, and its ROS 2, RealSense, Jetson, and headless work is still open.

This machine is a Raspberry Pi 5 Model B, Ubuntu 26.04 resolute, kernel `7.0.0-1020-raspi`, `uname -m` `aarch64`. HDMI-A-1 is connected. The kernel exposes two DRM devices: `/dev/dri/card0` is `v3d` and has no connector, and `/dev/dri/card1` is `vc4-drm` and owns HDMI. The firmware overlay is `dtoverlay=vc4-kms-v3d`.

`apt-cache` on this machine offers the same desktop candidates the x86-64 resolute path uses: `hyprland` 0.53.3+ds-4, `hyprpaper` 0.8.3-1, `hyprlock` 0.9.2-1build4, `gtkgreet` 0.8-2, `cage` 0.2.1-1, `hyprland-qtutils` 0.1.5-1build1, `hypridle` 0.1.7-2, `waybar` 0.15.0-1, `fuzzel` 1.12.0+ds-1build1, and `greetd` 0.10.3-5. Node.js publishes `node-v26.12.1-linux-arm64.tar.xz`. The pinned nvm tag is unchanged.

`ppa:cppiber/hyprland` publishes `hyprland` 0.56.2-1ppa2 for amd64. Its noble `binary-arm64` package index does not publish that package. Ubuntu 24.04 still has no archive `hyprland`.

PyPI `pyrealsense2` wheels used by the RealSense menu remain x86-64. That menu is not part of the desktop profile.

## Decision

- Preflight accepts `x86_64` and `aarch64` on noble and resolute. Other architectures still stop.
- x86-64 noble still adds the pinned Hyprland PPA when the Ubuntu archive has no `hyprland`. x86-64 resolute still uses the archive package and does not add the PPA.
- aarch64 resolute uses that same archive package list and does not add the PPA.
- aarch64 noble stops before the PPA is added. The message says the ARM desktop install uses Ubuntu 26.04.
- The shared Hyprland config is not given a card path or `no_hardware_cursors`. When `/sys/class/drm` has a `vc4-drm` device, the greeter exports `WLR_DRM_DEVICES` for cage, and the session and lock screen export `AQ_DRM_DEVICES`. The session also writes a runtime copy of the system config that selects that device and sets `cursor:no_hardware_cursors`. A machine without vc4, including x86-64, keeps the previous cage flags and the system config path.
- RealSense, ROS 2, and the AI agent installers are unchanged.

## Consequences

An x86-64 desktop install follows the same archive and PPA rules as before. A Raspberry Pi on Ubuntu 26.04 can install the desktop profile. Ubuntu 24.04 ARM is not a desktop target until `hyprland` is in that archive or the PPA publishes an arm64 build. Logging in still has to be checked on the HDMI display: package installation does not prove the compositor started. ROS 2, RealSense, and Jetson remain future Phase 14 work.
