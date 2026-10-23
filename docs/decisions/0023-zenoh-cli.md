# 0023. Zenoh client CLI

Date: 2026-10-23
Status: Accepted

## Context

`corebrum install ros` installs `rmw_zenoh_cpp` and one router, `rmw_zenohd`, as decided in `docs/decisions/0009-ros-jazzy-zenoh.md`. That package has no `zenoh` command. The Eclipse `zenoh` apt package is a metapackage for `zenohd` plus plugins, and its repository is not one this project adds. The command named `zenoh` comes from the PyPI package `zenoh-cli`.

On this machine the ROS library is Zenoh 1.8.0 under `/opt/ros/lyrical/opt/zenoh_cpp_vendor`. `eclipse-zenoh` 1.8.0 publishes only a Python 3.8 wheel. Ubuntu 24.04 and 26.04 need the 1.9.0 abi3 wheel. Zenoh documents 1.x sessions as compatible, and a 1.9.0 client opened a session to the running 1.8.0 router without changing `librmw_zenoh_cpp.so` or the `rmw_zenohd` process.

## Decision

- `corebrum install ros` installs `zenoh-cli` 0.7.0 and `eclipse-zenoh` 1.9.0 into `/opt/corebrum/zenoh-cli`. It installs `python3-venv` from Ubuntu when that package is missing. It does not install the Eclipse `zenoh` or `zenohd` packages.
- `/usr/local/bin/zenoh` runs that client. With no `--mode`, `--connect`, `--listen`, or `--config`, it connects to `tcp/127.0.0.1:7447` and disables multicast scouting. Those flags leave the session configuration to the caller.
- The same command on a machine that already has ROS is `sudo corebrum install ros`. The profile install is idempotent. It still runs the existing graph check, which restarts the router once.
- Uninstall removes `/usr/local/bin/zenoh` and `/opt/corebrum/zenoh-cli`. It leaves the ROS apt packages installed.
- Super+Space lists `Zenoh network` only when `ros-base` and `/usr/local/bin/zenoh` are both installed. Choosing it runs `zenoh network`. The row is omitted before that, including while Super+Space still shows `ROS 2   install`.

## Consequences

`zenoh info` and `zenoh subscribe` talk to the existing router. `zenoh --mode router` can still start a router inside that process, so the default command does not do that. The Python library stays inside the virtualenv and is not the `libzenohc.so` loaded by `rmw_zenoh_cpp`.
