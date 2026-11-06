# 0125. Corebrum Synapse battery reporting on ROS

Date: 2026-11-06
Status: Accepted

## Context

Corebrum Synapse runs on Ubuntu Server 24.04 and 26.04 on x86-64 and ARM64 with ROS 2 (Jazzy / Lyrical) and `rmw_zenoh_cpp`. Operators and agents need a portable `sensor_msgs/BatteryState` topic when the host exposes a Linux power supply of type `Battery` under `/sys/class/power_supply` (laptops, many embedded boards). Fixed robots without a battery should not fail `synapse up` or related flows.

## Decision

- Corebrum Synapse ships a small `rclpy` node `linux_sysfs_battery` in the `synapse_bringup` package, launched by `synapse_bringup/launch/linux_battery.launch.py`. It publishes `sensor_msgs/msg/BatteryState` at 1 Hz (default). The topic defaults to `/battery_state`; when `SYNAPSE_ROBOT_NAMESPACE` is set (real robot profile), the default topic is `/<namespace>/battery_state`.
- `scripts/lib/battery.sh` starts that launch in the background when a battery exists and `synapse_bringup` is built; otherwise it logs a skip and exits 0. It is invoked from `scripts/start_demo.sh` (after `synapse up real`) and from `scripts/sim/run_sim.sh` (before the sim `ros2 launch`), so demos report power without a separate command.
- `synapse start battery` / `synapse stop battery` (and `synapse battery start|stop`) call `scripts/start_battery.sh` / `scripts/stop_battery.sh`. `synapse status` lists `battery` under hardware when the node process matches `synapse_bringup.linux_sysfs_battery`. `synapse logs battery` tails `/tmp/synapse-battery.log`. `synapse down` sends SIGTERM to any matching `linux_sysfs_battery` node after other shutdown steps.
- The Corebrum OS Super+Space Corebrum Synapse submenu adds **Battery: Start reporting** and **Battery: Stop reporting**, running the same CLI in a terminal.

## Consequences

Machines without a battery sysfs entry skip the publisher; desktops without `synapse_bringup` in the colcon workspace log instructions to build. Implementations that use a non-sysfs BMS can run a different node on the same topic naming convention; this OS path stays the default for Corebrum installs on Ubuntu.

The canonical implementation lives in the `https://github.com/Corebrum/corebrum-synapse` repository; Corebrum OS documents and menu wiring reference that CLI.
