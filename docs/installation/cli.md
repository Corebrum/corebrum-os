# Corebrum command

Phase 4 is the `corebrum` command. It installs the profiles from Phases 1–3, reports what is present, and diagnoses a broken install. The decision is `docs/decisions/0008-corebrum-command.md`. `corebrum install ros`, `corebrum ros`, and `corebrum zenoh` came with Phase 5. `camera list`, `agents list`, and `update status` report the Super+Space menus and do not install or upgrade. `speak` and `voice` use the desktop `espeak-ng` package and do not call a cloud speech API. `voice hear` transcribes the default microphone with Ubuntu `pocketsphinx` after `voice hear --install`. The desktop profile does not install that package. See `docs/decisions/0048-cli-catch-up.md`, `docs/decisions/0052-local-speech.md`, and `docs/installation/ros.md`.

From a checkout:

```bash
./scripts/corebrum.sh version
./scripts/corebrum.sh install desktop --dry-run
sudo ./scripts/corebrum.sh install desktop
```

After that install, `/usr/local/bin/corebrum` points at `scripts/corebrum.sh` in this checkout.

| Command | Effect |
| --- | --- |
| `corebrum version` | Print the version from `VERSION` |
| `corebrum status` | Say whether base, desktop, services, and ROS are installed, plus RealSense, AgenticROS, and the Skills helper |
| `corebrum doctor` | Run the validators and print the next command if one fails. A missing RealSense install, AgenticROS install, or Skills helper does not fail it |
| `corebrum config` | List `/etc/corebrum`, logs, and backups |
| `corebrum install base` | Headless Ubuntu foundation |
| `corebrum install headless` | Same as `base` |
| `corebrum install desktop` | Base, Sway, workstation services, and Node.js 26.x with npm and pnpm |
| `corebrum install desktop --enable-ssh` | Also install OpenSSH |
| `corebrum install ros` | Base profile, ROS 2, and the Zenoh router |
| `corebrum ros status` | Distro, selected RMW, and router state |
| `corebrum ros topics` | `ros2 topic list` with the selected RMW |
| `corebrum ros rmw zenoh` | New shells use Zenoh |
| `corebrum ros rmw fastrtps` | New shells use Fast DDS |
| `corebrum zenoh status` | Router unit and listen address |
| `corebrum zenoh peers` | Router address and this machine's IPv4 addresses |
| `corebrum camera list` | List RealSense devices, or point at Super+Space |
| `corebrum agents list` | Show which catalog CLIs are on `PATH`, with a version when the CLI prints one |
| `corebrum agents update` | Point at Super+Space Updates. Does not run a publisher installer |
| `corebrum update status` | List the Updates rows. Does not run apt or git |
| `corebrum speak "text"` | Say the text with `espeak-ng`. A missing cloud key is ignored |
| `corebrum speak listen` | Say each `std_msgs/String` published on `/corebrum/say` |
| `corebrum voice list` | List `espeak-ng` voices |
| `corebrum voice test` | Say “Hello from Corebrum.” |
| `corebrum voice set espeak` | Keep local speech on `espeak-ng` |
| `corebrum voice disable` | Stop speech until `corebrum voice enable` |
| `corebrum voice hear` | Transcribe the default microphone for 5 seconds |
| `corebrum voice hear --install` | Install Ubuntu `pocketsphinx` and `pocketsphinx-en-us`, then transcribe |
| `corebrum uninstall desktop` | Remove Corebrum desktop files, not Ubuntu packages |

`--dry-run` prints the plan and does not change the system. A real install must be root. It does not write `~/.config` and it does not edit existing Netplan files. A second install copies a file again only when the checkout copy differs, and it keeps the first recorded state value.

Super+Space installs each AI agent on its own. The first launch asks that publisher to sign in. Corebrum does not store the token. Choosing the same agent again opens it. Super+Space Updates runs that publisher's installer again. `corebrum agents update` only names that row.

Super+Space opens Fuzzel with a blank search field. The app grid opens with Super+Alt+Space, and that grid's prompt is Corebrum. The grid's desktop entry is `/usr/local/share/applications/corebrum-grid.desktop`, and `NoDisplay=true` keeps that entry out of the Super+Space list.

Logs and backups:

```text
/var/log/corebrum/install-latest.log
/var/log/corebrum/backups/
```

If an install stops, read that log and run `corebrum doctor`.

## Fresh virtual machine

`make check` does not install Corebrum onto the machine that runs it. To accept Phase 4 on a clean Ubuntu Server 26.04 VM:

1. Install Ubuntu Server 26.04, x86-64 or ARM64, and clone this checkout.
2. Run `./scripts/corebrum.sh install desktop --dry-run` and confirm it exits 0.
3. Run `sudo ./scripts/corebrum.sh install desktop`.
4. Reboot, log in on VT 7, and run `corebrum doctor`.
5. Run `sudo ./scripts/corebrum.sh install desktop` again. `corebrum doctor` should still pass, and `/etc/corebrum/desktop.state` should not gain a second copy of an existing key.
6. Confirm `corebrum config` lists `/etc/corebrum` and that the user home has no Corebrum Sway config.

## Removal

```bash
sudo corebrum uninstall desktop
```

This is the desktop uninstall from `docs/installation/desktop.md`. `corebrum uninstall base` refuses to remove Ubuntu packages.
