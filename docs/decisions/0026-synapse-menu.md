# 0026. Corebrum Synapse joins the Zenoh graph from Super+Space

Date: 2026-10-23
Status: Accepted

## Context

The operator cloned Corebrum Synapse beside this checkout and asked for it as a Super+Space app. The CLI already speaks to ROS through one MCP server. On this OS the ROS graph uses `rmw_zenoh_cpp` and one `rmw_zenohd` on `tcp/localhost:7447`. Corebrum Synapse's Zenoh transport only opens a WebSocket to `zenoh-plugin-remote-api`, which this machine does not run.

An agent should use Corebrum Synapse for what it sees and for missions on this machine whether the agent or Corebrum Synapse was installed first.

## Decision

- Super+Space lists Corebrum Synapse only after `ros-<distro>-ros-base` is installed. The desktop profile does not preinstall Corebrum Synapse.
- The first choice uses the sibling clone (or `COREBRUM_SYNAPSE_ROOT`). When that directory is missing it clones `https://github.com/Corebrum/corebrum-synapse.git` there. See `docs/decisions/0041-synapse-clone.md`. It then builds that checkout, links `/usr/local/bin/synapse`, and runs `synapse init --yes`. That init writes a real-robot config with local ROS transport, skips cloud login and an OpenAI key, and registers every agent CLI already on `PATH`.
- Before that build, the installer installs `build-essential` and `python3` when either package is missing. `pnpm install --ignore-scripts` skips native install scripts. `rclnodejs` has no Lyrical prebuilt, so the same script compiles it with ROS sourced and then regenerates its JavaScript messages. `node-datachannel` does have an N-API prebuild, so the script runs `prebuild-install -r napi` for that package. `synapse connect` loads it before opening the ARC socket. The desktop and ROS profiles do not install that toolchain. On Lyrical those messages have to match the wider primitive sequence (`is_rosidl_buffer` and `owns_rosidl_buffer`). The Corebrum Synapse patch does that for `string[]`, `byte[]`, and the other primitive arrays, and leaves sequences of whole messages unchanged. Generating the messages without `ROS_DISTRO=lyrical` keeps the older layout and the first ROS publish segfaults.
- `/usr/local/lib/corebrum/synapse-with-ros.sh` sources ROS and forces `RMW_IMPLEMENTATION=rmw_zenoh_cpp`. The CLI wrapper and each agent's MCP server start through it. `synapse doctor` warns when `/etc/corebrum/ros/rmw` is not `rmw_zenoh_cpp`.
- After init, the same menu starts and stops ARC, RealSense, the 2D camera, motors, eyes, and the real or simulated stack. The top bar shows that status and can connect or disconnect ARC.
- Installing an agent later runs `synapse mcp setup` for that agent. Opening Super+Space runs it again for every agent already installed. Each agent gets the MCP server, a standing instruction, and an allow rule where that agent would otherwise prompt on every tool call. The catalog is Claude, Codex, Hermes, Antigravity, OpenClaw, Cursor, and Grok.

## Consequences

The menu does not add an apt repository and does not start a second Zenoh router. Cloud sign-in stays optional. Cursor and Grok receive the same MCP entry as the other agents. A second desktop install leaves the clone and `~/.synapse` in place and removes the menu scripts.
