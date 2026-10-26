# 0063. Ubuntu 26.04 on x86-64 and ARM64

Date: 2026-10-26
Status: Accepted

## Context

Corebrum OS started on Ubuntu Server 24.04 x86-64. Decision 0010 added Ubuntu 26.04 x86-64. Decision 0060 added an Ubuntu 26.04 aarch64 desktop beside that, and left Ubuntu 24.04 x86-64 in place. On 2026-10-26 a Raspberry Pi 5 on Ubuntu 26.04 ran the desktop, ROS 2 Lyrical, RealSense, AgenticROS, and the AI agents.

Keeping two Ubuntu releases means two Hyprland sources, two ROS distros, and a greeter that exists only on 26.04. The Hyprland personal archive used on 24.04 publishes amd64 packages.

## Decision

- Preflight accepts `VERSION_CODENAME=resolute` only, on `x86_64` and `aarch64`. Ubuntu 24.04 (`noble`) and every other release stop before any package is installed.
- x86-64 and ARM64, including Raspberry Pi, are both supported on Ubuntu Server 26.04. ARM is not a replacement for x86-64.
- Hyprland comes from the Ubuntu 26.04 archive. A new install does not add a Hyprland PPA.
- `corebrum install ros` installs ROS 2 Lyrical Luth.
- The RealSense arm64 packages still come from the `noble` suite of the RealSense apt archive. That suite name is the publisher's pocket. It is not Ubuntu 24.04 support. The x86-64 resolute pin stays `2.59.1-0~realsense.20271`.
- GitHub Actions runs on `ubuntu-26.04`, because dry-run executes the same preflight.
- Older decision records that describe a 24.04 install stay as the history of that work. This decision is the current host target.

## Consequences

A machine on Ubuntu 24.04 cannot install or dry-run Corebrum. An Ubuntu 26.04 x86-64 install still uses the archive Hyprland package, Lyrical, and the same desktop session. A Raspberry Pi on Ubuntu 26.04 uses that same release, with the vc4 display selection from decision 0060 and the RealSense arm64 packages from decision 0062. Jetson and a separate headless ARM profile are not part of this decision.
