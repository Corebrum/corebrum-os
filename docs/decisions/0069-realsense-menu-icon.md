# 0069. The RealSense menu row uses the RealSense mark

Date: 2026-10-26
Status: Accepted

## Context

Super+Space lists RealSense with the generic `camera-video` icon. The operator supplied a RealSense mark at `~/Videos/realsense.png`. Fuzzel already draws desktop icons.

## Decision

- The desktop profile copies that mark to `/usr/share/corebrum/realsense.png`. The file in this checkout is `config/brand/realsense.png`.
- The RealSense row and its Viewer and ROS search entries set `Icon` to that path. The desktop profile does not install RealSense.

## Consequences

The next Super+Space after the desktop files are copied shows the mark. Uninstall removes the file with the other Corebrum desktop files.
