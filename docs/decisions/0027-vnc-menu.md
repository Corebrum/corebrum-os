# 0027. Remote desktop is wayvnc from Super+Space

Date: 2026-10-23
Status: Accepted

## Context

A Mac on the same network needs to see and control the Hyprland desktop. Hyprland is a Wayland session, so an X11 VNC server does not capture it. Ubuntu publishes `wayvnc` for wlroots compositors: 0.7.2 on noble and 0.9.1 on resolute. That package ships `/usr/bin/wayvnc` and does not install a service. It attaches to a Wayland session that is already logged in. It does not replace the greeter.

With authentication off, `wayvnc` 0.9.1 offers only VNC security type None. With `enable_auth` and `relax_encryption`, it offers Apple type 30 and VeNCrypt. macOS Screen Sharing refuses both and reports "Unable to communicate" and a firewall block, with no password prompt, including when the TCP port is open. Screen Sharing does prompt for the classic VNC password, security type 2. When the server offers protocol 3.8, Screen Sharing answers with protocol 3.3 and then waits for one 4-byte security type followed by the challenge. A 3.8 type list leaves that wait running. Ubuntu 26.04's `wayvnc` package has no `allow_broken_crypto` option for type 2, so `corebrum-vnc-proxy` speaks both handshakes. The session is the same one on the local screen.

## Decision

- Super+Space lists `Remote desktop`. The entry says `install` until `wayvnc` is installed. Choosing it installs the Ubuntu package when `apt-cache` has a candidate. The desktop profile does not preinstall `wayvnc`.
- After it is installed, the menu offers Start, Stop, and `How to connect from a Mac`. Start runs `wayvnc` in this session, listening on `0.0.0.0` port 5900, and then opens the Mac steps with each `vnc://` address. The top-level entry says `on` while that process is running. Nothing starts it at login.
- The config is written under the runtime directory and passed with `--config`. `XDG_CONFIG_HOME` for that process is the same directory, so wayvnc does not read `~/.config/wayvnc/config`. The menu does not write `~/.config`.
- `wayvnc` listens on `127.0.0.1` port 5901 and does not require a login there. `corebrum-vnc-proxy` listens on port 5900 and checks an 8-character VNC password before connecting the client to `wayvnc`. Screen Sharing asks for that password and does not ask for a name. The instructions show the password. It is removed when the session ends.
- The proxy asks wayvnc for ZRLE, then raw, and keeps DesktopSize when the Mac asked for a size change. It does not forward Tight, the cursor image, or the extension messages. The first update request is a full frame.
- The connection to wayvnc is given five seconds to open. That limit used to stay on the open connection, so a quiet screen closed it and Screen Sharing drew a new picture a few seconds later. The limit now applies only while connecting.
- Screen Sharing asks for 32 bits per pixel with depth 32. `wayvnc` 0.9 then writes 4 bytes into each ZRLE pixel, and Screen Sharing reads 3, so the Mac window flashes and the desktop never appears. The proxy reports that format as depth 24. That is the 3-byte pixel Screen Sharing draws.
- Screen Sharing sends Command as Alt and Option as Meta, which is what another Mac expects. The proxy forwards Command as Super and Option as Alt.

## Consequences

A Mac uses Finder's Connect to Server, or Screen Sharing, with the address the menu prints. The local monitor shows the same desktop. Ubuntu releases without a `wayvnc` candidate show that the package is absent and do not add another repository. Uninstall removes the menu script and leaves the `wayvnc` package installed. A running server ends when the session ends.
