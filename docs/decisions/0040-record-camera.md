# 0040. Screen recording can include a camera and the microphone

Date: 2026-10-24
Status: Accepted

## Context

Super+Print and Super+Alt+P record a selected area with `wf-recorder`. The operator asked to include a camera in the bottom-right of that recording. RealSense stays out of the desktop package list. It is installed from Super+Space, which provides `pyrealsense2`. See `docs/decisions/0013-realsense-menu.md`.

A demo that uses the RealSense camera cannot share it with the preview. A separate webcam, such as the NexiGo N60 on this machine, is a different PipeWire `Video/Source`. The RealSense nodes are named RealSense and are not offered as that webcam. The webcam microphone is the default PipeWire source while it is plugged in. `wf-recorder -a` records that default source into the same `.mp4`.

`wf-recorder` records the rectangle the user selects. A preview window inside that rectangle is part of the video. The desktop already installs GTK 3 and GStreamer. The webcam preview needs the GStreamer typelibs `gir1.2-gstreamer-1.0` and `gir1.2-gst-plugins-base-1.0`.

## Decision

- Super+Print and Super+Alt+P run `/usr/local/bin/corebrum-record start`. Super+Shift+Print and Super+Alt+Shift+P run `corebrum-record stop`.
- The list is Screen, plus Screen and audio when a microphone source exists, Screen and webcam and Screen, webcam, and audio when a non-RealSense camera exists, and Screen and RealSense and Screen, RealSense, and audio when `pyrealsense2` is installed. The RealSense check uses `find_spec` and does not load librealsense. Cancelling the list records nothing. When Screen is the only row, start records the screen immediately.
- Audio passes `-a` to `wf-recorder` with no device name, so the default microphone is used. If that recording produces no file, the same area is recorded again without audio and a notification says the microphone was not recorded.
- Webcam video opens the GTK preview with `--v4l2` and does not open RealSense. The desktop install marks `/usr/local/bin/corebrum-record` and `/usr/local/lib/corebrum/corebrum-camera-preview.py` executable. A later install corrects that mode when an older copy is present but not executable. The recorder also starts the preview with `python3`. RealSense video opens the same window from the RealSense color stream. The window application id is `corebrum-camera`. Hyprland floats it, pins it, and the script moves it to the bottom-right of the selected area. Stop closes that window, including one left open by an earlier recording, and interrupts `wf-recorder`.
- A selection too small for the preview, or a sensor that does not open, shows a notification and records the screen only. The preview does not launch RealSense Viewer or RealSense ROS.

## Consequences

A recording can be the screen, the screen with the default microphone, or the screen with a webcam or RealSense picture. Choosing RealSense occupies that camera. Choosing the webcam or no video leaves it free for a demo. Firefox can still open the `.mp4` in `~/Videos`. A machine that already installed the desktop profile needs that install again before the GStreamer typelibs and the new prompt are present.
