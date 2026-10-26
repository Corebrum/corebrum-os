# 0057. Phase 11 keeps simulation tools on the ROS menu

Date: 2026-10-26
Status: Accepted

## Context

Phase 11 asks for optional RViz, Gazebo, and MoveIt, launcher entries, Hyprland behavior, and a simulated ROS topic. Those packages must stay out of the default install. Super+Space already installs and launches them. See `docs/decisions/0011-ros-launcher-menu.md`. Phase 6 already opened RViz on the D435 point cloud.

## Decision

- The tool list stays `manifests/packages/ros-tools.conf`. A missing row installs only that apt package. `corebrum install ros` and the desktop profile do not install RViz, Gazebo, Nav2, or MoveIt.
- On 2026-10-26 this machine already had `ros-lyrical-rviz2`, `ros-lyrical-ros-gz`, `ros-lyrical-nav2-bringup`, and `ros-lyrical-moveit`. Gazebo was started headless with `gz_args:=-s -r empty.sdf` through `ros_gz_sim`, on `rmw_zenoh_cpp`. `ros_gz_bridge` published `/clock`. `ros2 topic echo /clock rosgraph_msgs/msg/Clock --once` returned `sec: 65`. The server and the bridge were stopped after that read.
- The same day the operator opened Gazebo, Nav2, and MoveIt from the Super+Space ROS menu. Each window came up. Gazebo and Nav2 set `QT_QPA_PLATFORM=xcb`, the same path RViz used under Hyprland in Phase 6. No simulation workspace template was added.

## Consequences

Super+Space remains the way to open the Gazebo window, the TurtleBot simulation, or MoveIt Setup Assistant. Those launches stay optional.
