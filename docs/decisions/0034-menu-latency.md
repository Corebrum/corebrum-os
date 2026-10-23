# 0034. Super key launches do not wait on setup

Date: 2026-10-23
Status: Accepted

## Context

Super+Space felt about a second late. Timing the launcher on this machine, a 13th-gen Intel Core i7, showed the key itself is immediate. `/usr/local/bin/corebrum-launcher` refreshed every menu entry before drawing the window. In series that took about 4.1 seconds. `corebrum-agents-menu refresh` was 3.2 seconds of that because it runs `agenticros mcp setup --installed` and waits. Sourcing `nvm.sh` for the Zenoh fleet and AI Agents checks added about 200ms each. A plain Super+Return also sourced nvm and the ROS profile, about 370ms, before Kitty's login shell sourced them again.

Focus, workspace, and close shortcuts run inside Hyprland and were not part of this pause.

## Decision

- Menu refreshes run together, and the window opens after they finish. Each script still writes its own desktop files.
- Super+Space still runs `agenticros mcp setup --installed` when AgenticROS is configured. A second press does not start another setup while one is running. The setup is detached with `setsid --fork` and `flock -n`, so the menu does not wait. Installing or launching an agent still runs setup for that agent before that agent starts. Tests that stub the menu still print the setup command from refresh.
- AI Agents and Zenoh fleet find Node by reading `/usr/local/nvm/alias/default` and prepending that version's `bin` directory. They do not source `nvm.sh` on the menu path. Login shells still source nvm, so the `nvm` function remains available in a terminal.
- A Super+Return terminal starts Kitty immediately. Kitty is `bash --login`, which loads the node and ROS profiles. `corebrum-terminal` still sources those profiles when it is given a command, because `bash -c` is not a login shell.
- ROS and RealSense package checks for one refresh share one `dpkg-query`. RealSense checks that `pyrealsense2` can be found without importing the native module during refresh.

## Consequences

`0026` still registers agents on Super+Space, and that registration no longer blocks the menu. A desktop install that already ran needs the updated launcher, terminal, and menu scripts before the keys are faster. The next `corebrum install desktop` copies them into place.
