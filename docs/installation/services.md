# Workstation services

Phase 3 adds daily-use services to the desktop profile: NetworkManager for Wi-Fi, PipeWire, Bluetooth, a polkit prompt, removable disks in Thunar, a clipboard history, screenshots, and the wlr screen-cast portal.

The installer does not edit existing Netplan files and does not run `netplan apply`. Ubuntu's NetworkManager package manages Wi-Fi only. Ethernet stays on the Netplan renderer that was already in place. When NetworkManager saves a Wi-Fi profile, Ubuntu may add `/etc/netplan/90-NM-*.yaml` for that interface. The decision is `docs/decisions/0007-workstation-services.md`.

Preview it without changing the system:

```bash
./scripts/install.sh --profile desktop --dry-run
```

The dry-run prints the package list and says it is not changing existing Netplan files. It exits 0.

Apply it with:

```bash
sudo ./scripts/install.sh --profile desktop
```

That command also installs the base profile and the Hyprland session if they are not already present. It enables NetworkManager, Bluetooth, and power-profiles-daemon. It disables `NetworkManager-wait-online.service` so boot does not wait for Wi-Fi. It does not suspend the machine.

## After a successful install

Log in again if the bar and tray did not refresh. Waybar adds volume, Bluetooth, battery, and a tray. Waybar 0.9 needs a link from `/tmp/hypr` to Hyprland's runtime socket; the session creates that link before starting the bar. The app grid adds Audio, Network, Bluetooth, and Display.

| Key | Action |
| --- | --- |
| Print | Copy a selected area |
| Shift+Print | Copy the whole screen |
| Super+Print | Record a selected area to `~/Videos` |
| Super+Shift+Print | Stop the recording |
| Super+C | Clipboard history |

Wi-Fi is configured with Network (`nm-connection-editor`) or `nmtui`. Ethernet remains the existing Netplan connection. Volume is `pavucontrol` or the volume keys. Bluetooth is `blueman-manager`. Displays are `wdisplays`. A USB disk should show up in Thunar; mounting asks for the polkit prompt from `mate-polkit`.

Firefox screen sharing uses `xdg-desktop-portal-wlr`. The portal choice is `/etc/xdg/xdg-desktop-portal/hyprland-portals.conf`.

```bash
./scripts/validate/services.sh
```

That script checks packages, the Netplan directory, the NetworkManager policy, the portal file, the default route, and that Wi-Fi is not unmanaged. It does not join a network, play audio, mount a disk, or share a browser tab.

## Removal

```bash
sudo ./scripts/uninstall.sh --profile desktop
```

Desktop uninstall removes the portal config and disables units this installer enabled. It does not remove the Ubuntu packages and it does not edit Netplan.

## What is not done

Phase 3 is not accepted until Wi-Fi and Ethernet can be managed, playback and recording work, a USB drive appears in Thunar, `wdisplays` can change the display, and a browser screen share works where the hardware allows it. The installer does not run `systemctl suspend`. ROS 2, Zenoh, RViz, Gazebo, RealSense, AgenticROS, and Corebrum Mesh are not part of this install.
