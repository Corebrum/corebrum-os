# 0066. The ROS menu row uses the ROS mark

Date: 2026-10-26
Status: Accepted

## Context

Super+Space lists ROS 2 with the generic `applications-science` icon. A square ROS mark is published for the ROS library logo. Fuzzel already draws desktop icons.

## Decision

- The desktop profile copies that mark to `/usr/share/corebrum/ros.png`. The file in this checkout is `config/brand/ros.png`.
- The ROS row and its tool search entries set `Icon` to that path. `Zenoh network` keeps `network-workgroup`.

## Consequences

The next Super+Space after the desktop files are copied shows the mark. Uninstall removes the file with the other Corebrum desktop files. Zenoh network later uses the Zenoh mark. See `docs/decisions/0068-zenoh-menu-icon.md`.
