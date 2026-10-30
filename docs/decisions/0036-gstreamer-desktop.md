# 0036. The desktop profile installs GStreamer

Date: 2026-10-23
Status: Accepted

## Context

`synapse desktop` captures the Hyprland session for Corebrum Cloud. The capture process runs `gst-launch-1.0` with `pipewiresrc` and encodes H.264 with `x264enc`. On this machine that command was missing, and the cloud page reported that GStreamer needed to be installed.

The Corebrum Synapse desktop readme also lists PipeWire, WirePlumber, `xdg-desktop-portal`, and `xdg-desktop-portal-hyprland`. PipeWire, WirePlumber, and `xdg-desktop-portal` are already installed by the desktop profile. `0007` keeps screen capture on Ubuntu `xdg-desktop-portal-wlr`. On 2026-10-22 noble had no `xdg-desktop-portal-hyprland` package. On 2026-10-23 resolute publishes `xdg-desktop-portal-hyprland` 1.3.11-1build2, and the session still selects the wlr portal.

On 2026-10-23 Launchpad published these Ubuntu archive packages for noble: `gstreamer1.0-tools` 1.24.2-1ubuntu0.1, `gstreamer1.0-plugins-base` 1.24.2-1ubuntu0.5, `gstreamer1.0-plugins-good` 1.24.2-1ubuntu1.8, `gstreamer1.0-plugins-ugly` 1.24.1-1build1, and `gstreamer1.0-pipewire` 1.0.5-1ubuntu3.3. Resolute apt selected 1.28.2-1, 1.28.2-1ubuntu0.1, 1.28.2-2ubuntu0.4, 1.28.2-1, and 1.6.2-1ubuntu1.2. The ugly package is in universe and depends on `libx264`, which provides `x264enc`.

## Decision

- `corebrum install desktop` installs those five GStreamer packages from the Ubuntu archive with the rest of `manifests/packages/desktop.txt`.
- The installer does not add a repository. It does not install `xdg-desktop-portal-hyprland`. Screen capture stays on `xdg-desktop-portal-wlr`.

## Consequences

A later desktop install provides `gst-launch-1.0`, `pipewiresrc`, and `x264enc` for `synapse desktop`. Uninstall leaves the packages in place, as it does for the other Ubuntu desktop packages. A machine that already installed the desktop profile needs that install again before the new packages are present.
