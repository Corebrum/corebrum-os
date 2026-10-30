# 0090. Jetson desktop install replaces the L4T display manager alias

Date: 2026-10-29
Status: Accepted. Decision 0096 applies this handoff on every machine, including Ubuntu Desktop, and documents switching back.

## Context

`sudo ./scripts/install.sh --profile desktop` on this NVIDIA Jetson AGX Orin Developer Kit (Ubuntu 24.04, aarch64, L4T R39.2) installed the desktop files, then stopped at `systemctl enable greetd.service`. greetd's unit aliases itself as `display-manager.service`. `/etc/systemd/system/display-manager.service` already pointed at `/lib/systemd/system/gdm3.service`, so systemd refused to create that alias. GDM was not running. The default target was still `multi-user.target`, and Phase 3 had not started.

The device-tree model on this machine is `NVIDIA Jetson AGX Orin Developer Kit`, and `/etc/nv_tegra_release` is present. The same L4T markers cover the other Jetson boards. Jetson Linux R39.2 supports the Orin family and Thor. An Orin Nano developer kit model contains `Jetson`. Thor's compatible string is `nvidia,tegra264`, and Orin's is `nvidia,tegra234`. Ubuntu Server 24.04 and 26.04 on x86-64, and Raspberry Pi images, do not ship that release file, that model, or that compatible string. Their desktop install already enables greetd directly.

`gdm.service` is a static unit. `systemctl disable` does not remove the package symlink. The symlink is what `graphical.target` starts.

## Decision

- A machine is a Jetson when `/etc/nv_tegra_release` exists, when `/proc/device-tree/model` contains `Jetson`, or when `/proc/device-tree/compatible` contains `nvidia,tegra`. That covers AGX Orin, Orin Nano, Orin NX, Thor, and the older Nano and Xavier modules. Tests may point `COREBRUM_TEGRA_RELEASE`, `COREBRUM_DEVICE_TREE_MODEL`, and `COREBRUM_DEVICE_TREE_COMPATIBLE` at other files.
- Before the desktop install, the operator on any of those boards turns off NVIDIA's desktop with `systemctl set-default multi-user.target` and a reboot. That step is written in `README.md`, `docs/installation/ubuntu-server-install.md`, and `docs/installation/ubuntu-server.md`. x86-64 and other ARM machines are not asked to change their boot target.
- Ubuntu 24.04 and 26.04 on x86-64, and on aarch64 machines that are not Jetson, keep the existing greetd steps: enable `greetd.service`, then set the default target to `graphical.target` when it is not already. Those installs do not read or remove `display-manager.service`.
- On a Jetson, before those same steps, the install reads `/etc/systemd/system/display-manager.service`. When that path is a symlink to a unit other than `greetd.service`, it records the symlink target once as `previous_display_manager` in `/etc/corebrum/desktop.state` and removes the symlink.
- A Jetson symlink that already points at `greetd.service` is left in place. A Jetson path that is not a symlink stops the install.
- The install does not stop the display manager that is already running and does not start greetd. The next boot uses greetd.
- Jetson desktop uninstall disables greetd, then restores the recorded symlink when `display-manager.service` is absent. Other machines uninstall greetd as before.

## Consequences

The desktop install was finished on this AGX Orin. The same Jetson steps apply to Orin Nano and Thor. Uninstall puts the GDM symlink back and does not remove the GDM package. An x86-64 or Raspberry Pi install uses the same greetd enable and uninstall sequence it used before this decision. This decision does not change how the Sway session or the greeter starts. Decision 0091 starts that Sway on the proprietary NVIDIA driver.
