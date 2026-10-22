# 0007. Workstation services on Ubuntu 24.04

Date: 2026-10-22
Status: Accepted

## Context

Phase 3 makes the Hyprland session usable as a daily workstation: networking, audio, Bluetooth, displays, power, polkit, removable media, clipboard, screen capture, and desktop portals. The build plan says to configure NetworkManager without breaking existing Netplan networking.

This machine's Netplan file configures `enp86s0` with DHCP and names no renderer, so systemd-networkd keeps that link. `wlp87s0` is present and is not in Netplan. `ppa:cppiber/hyprland` publishes `xdg-desktop-portal-hyprland` and `hyprpolkitagent`, and `grimshot` depends on `sway`.

The operator continued to Phase 3 after this machine booted to Hyprland and showed Waybar. That is the gate used to start this phase.

## Decision

- Phase 3 is part of `--profile desktop`. It installs only packages from the Ubuntu 24.04 archive, listed in `manifests/packages/services.txt`.
- The installer does not edit existing Netplan files, does not set a global renderer, and does not run `netplan apply`. Ubuntu's NetworkManager integration may add `/etc/netplan/90-NM-*.yaml` for a Wi-Fi profile. That file is limited to the Wi-Fi interface.
- NetworkManager stays on Ubuntu's packaged policy: `unmanaged-devices=*,except:type:wifi,except:type:gsm,except:type:cdma`. Wi-Fi is managed by NetworkManager. Ethernet stays on the existing Netplan renderer. If that policy file is missing or different, the installer stops NetworkManager and leaves Netplan untouched.
- `NetworkManager-wait-online.service` is disabled so boot does not wait for Wi-Fi while Ethernet is still on networkd.
- Audio is PipeWire from Ubuntu (`pipewire-pulse`, `pipewire-alsa`, `wireplumber`), not the PipeWire build in the Hyprland PPA. PulseAudio and TLP are not installed.
- Bluetooth is BlueZ and Blueman, with `libspa-0.2-bluetooth` for PipeWire.
- The polkit agent is `mate-polkit`. `hyprpolkitagent` is not installed.
- Screen capture uses `grim`, `slurp`, and `wf-recorder`. `grimshot` is not installed because it depends on Sway.
- The screen-cast and screenshot portal is `xdg-desktop-portal-wlr`, selected by `/etc/xdg/xdg-desktop-portal/hyprland-portals.conf`. `xdg-desktop-portal-hyprland` is not installed.
- Display settings are `wdisplays` and `wlr-randr`. Power profiles use `power-profiles-daemon`. Removable media uses `udisks2`, `gvfs`, and `thunar-volman`.
- The installer does not suspend the machine. Suspend remains `systemctl suspend` through systemd-logind, for the operator to test.
- Ubuntu Waybar 0.9 reads Hyprland's socket from `/tmp/hypr`. Hyprland 0.56 puts that socket under `$XDG_RUNTIME_DIR/hypr`. The session links the two paths before Waybar starts. Waybar is not taken from the Hyprland PPA.
- `file` is installed because the NetworkManager postinst calls it when migrating connections.

## Consequences

Ethernet configuration stays in the current Netplan file. Wi-Fi is configured with `nm-connection-editor` or `nmtui`. A later change that hands Ethernet to NetworkManager has to be explicit, because it would replace the running renderer. Packages installed here are left in place by desktop uninstall, same as the Phase 2 packages. ROS 2 is still not part of this install.
