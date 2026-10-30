# 0096. Corebrum installs beside Ubuntu Desktop and can hand the display back

Date: 2026-10-30
Status: Accepted

## Context

Decision 0090 records the GDM symlink on a Jetson, removes it so greetd can be enabled, and puts it back on uninstall. The operator reaches that install by selecting `multi-user.target` and rebooting, which is how Corebrum was installed on this NVIDIA Jetson AGX Orin. Ubuntu Desktop uses the same GDM greeter. On x86-64 and on other ARM machines the desktop install left that symlink in place, so `systemctl enable greetd.service` failed the same way the Jetson install failed before decision 0090.

Operators also want the previous desktop again. Uninstall restores the greeter symlink and the boot target recorded at install time. That recorded target is `multi-user.target` when the operator followed the prepare step, so uninstall alone returns to a text console. GNOME is still installed.

## Decision

- Before `corebrum install desktop` on Ubuntu Desktop, and on every NVIDIA Jetson, the operator runs `systemctl set-default multi-user.target` and reboots. Ubuntu Server keeps its existing boot target. The steps are in `README.md`, `docs/installation/desktop.md`, `docs/installation/ubuntu-server-install.md`, and `docs/installation/ubuntu-server.md`.
- On every machine, the desktop install reads `/etc/systemd/system/display-manager.service`. When that path is a symlink to a unit other than `greetd.service`, it records the symlink target once as `previous_display_manager` in `/etc/corebrum/desktop.state` and removes the symlink. A symlink that already points at `greetd.service` stays. A path that is not a symlink stops the install. A missing path is left alone.
- The install does not stop a greeter that is already running and does not start greetd. The next boot uses greetd. GNOME packages stay installed.
- Desktop uninstall restores the recorded symlink when `display-manager.service` is absent, on every machine. It still restores `previous_default_target`.
- Switching desktops keeps Corebrum installed. The Ubuntu or NVIDIA desktop is `systemctl disable greetd.service`, a symlink from `previous_display_manager` to `display-manager.service`, `systemctl set-default graphical.target`, and a reboot. Corebrum is removing that symlink, `systemctl enable greetd.service`, the same graphical target, and a reboot. The state file stays so the switch can be repeated.
- A later `corebrum install desktop`, including Super+Space Updates on the Corebrum row, selects the Corebrum greeter again.
- Returning to the previous desktop is `corebrum uninstall desktop`, then `systemctl set-default graphical.target`, then a reboot. Uninstall runs first because it restores the text-console target from the prepare step.
- The Getting Started Desktop page lists the same commands.

## Consequences

Ubuntu Desktop and the NVIDIA Jetson desktop can host Corebrum, and the operator can boot either greeter. Ubuntu Server behavior is unchanged when no other greeter symlink is present. Decision 0090 still describes the Jetson failure that prompted the handoff. This decision is the one that applies that handoff on every machine and writes the switch steps.
