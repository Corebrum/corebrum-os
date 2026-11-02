# 0110. Super+Space About

Date: 2026-11-02
Status: Accepted

## Context

Omarchy’s Super+Space About opens a floating fastfetch card with hardware, software, OS age, uptime, and last package upgrade. Corebrum’s idle menu is the seven groups from `0108`. Ubuntu 24.04 has no archive `fastfetch`. Ubuntu 26.04 does. Corebrum does not add a Fastfetch PPA.

## Decision

- Super+Space System lists About before Log out, Reboot, and Power off.
- Choosing About opens a floating Kitty window (`app_id` `org.corebrum.about`) that prints a Corebrum-owned card and closes on any key.
- The card reports PC, CPU, GPU, Display when Sway is active, Disk, Memory, Swap when present, Corebrum version from `VERSION`, Corebrum Synapse from `synapse --version` or `not installed`, Ubuntu `PRETTY_NAME`, Kernel, WM, Terminal, OS Age from `/var/log` birth time, Uptime, and the last `apt upgrade` or `full-upgrade` `Start-Date` in `/var/log/apt/history.log`.
- `corebrum about` prints the same card and exits. It does not wait for a key.
- The desktop profile does not install `fastfetch` or `neofetch`.

## Consequences

Typing about at Super+Space finds the row. A machine without Synapse still shows the Synapse line. Last update is the apt history stamp, not the weekly Updates reminder. Uninstall removes the About scripts with the other desktop files.
