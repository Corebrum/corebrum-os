# 0011. ROS 2 installs from the Super+Space menu

Date: 2026-10-22
Status: Accepted

## Context

The desktop is usable without the robotics stack. Phase 5 installs ROS 2 and one Zenoh router through `corebrum install ros`, and it leaves RViz, Gazebo, and RealSense out of that profile. Phase 11 asks for RViz, Gazebo, and MoveIt as optional launcher entries, and it says not to install the heavy simulation packages by default.

On 2026-10-22 the official ROS apt indexes for noble and resolute both published the tool packages below. Classic `gazebo-ros-pkgs` was not in either index. Gazebo is the `ros-gz` metapackage, which depends on `ros-gz-sim`. Both `gz_sim.launch.py` files were unpacked and contain that launch file. The Lyrical Nav2 and MoveIt debs were unpacked as well. `nav2-bringup` ships `tb3_simulation_launch.py`, whose `headless` argument defaults to true, so a desktop launch has to pass `headless:=False` to open the Gazebo window. `moveit` depends on `moveit-setup-assistant`, which ships `setup_assistant.launch.py`. `rviz2` ships `/opt/ros/<distro>/bin/rviz2`.

| Tool | Package suffix | Launch |
| --- | --- | --- |
| RViz | `rviz2` | `env QT_QPA_PLATFORM=xcb rviz2` |
| Gazebo | `ros-gz` | `env QT_QPA_PLATFORM=xcb ros2 launch ros_gz_sim gz_sim.launch.py gz_args:=empty.sdf` |
| Nav2 | `nav2-bringup` | `env QT_QPA_PLATFORM=xcb ros2 launch nav2_bringup tb3_simulation_launch.py headless:=False` |
| MoveIt | `moveit` | `ros2 launch moveit_setup_assistant setup_assistant.launch.py` |

The apt name is `ros-jazzy-<suffix>` on noble and `ros-lyrical-<suffix>` on resolute. Jazzy versions seen that day included `rviz2` 14.1.24, `ros-gz` 1.0.24, `navigation2` 1.3.13, and `moveit` 2.12.4. Lyrical versions included `rviz2` 15.2.6, `ros-gz` 3.0.10, `navigation2` 1.5.2, and `moveit` 2.15.2. `nav2-bringup` is the installed package because it depends on `navigation2` and the launch files.

## Decision

- ROS 2 is not preinstalled with the desktop profile. Gazebo, Nav2, and MoveIt are not preinstalled either.
- Super+Space still opens Fuzzel. Before Fuzzel starts, the session writes a desktop entry under the user runtime directory, not under `~/.config`. The entry is `ROS 2   install` until `ros-<distro>-ros-base` is installed, then `ROS`.
- Choosing that entry before ROS 2 is installed opens a terminal and runs `sudo corebrum install ros`.
- Choosing `ROS` after that opens a Fuzzel submenu. Each missing tool is labeled with `install`. Choosing it installs only that package with apt, after the ROS apt source from the ros profile is already present. Choosing an installed tool launches it directly. `with-ros.sh` sources the ROS environment, so no terminal window is opened beside the GUI. Installing still opens a terminal, because that is where apt runs and where the password prompt appears. RViz, Gazebo, and Nav2 set `QT_QPA_PLATFORM=xcb`. RViz and Gazebo render with GLX. Under the Wayland session, Qt otherwise creates a Wayland window and Ogre aborts with `Invalid parentWindowHandle` after the splash screen. XWayland is already part of the desktop profile.
- The tool list is `manifests/packages/ros-tools.conf`, installed to `/etc/corebrum/ros-tools.conf`. RealSense is a separate Super+Space entry. AgenticROS and Corebrum Mesh are not on the ROS list.

## Consequences

A new desktop install shows the ROS entry without adding the ROS apt repository. Installing ROS 2 from the menu is the same profile as `sudo corebrum install ros`, including the Zenoh router. Tool packages stay out of that profile, so a ros dry-run still does not list RViz. Nav2's menu package pulls the TurtleBot simulation it launches. The next Super+Space after an install refreshes the label.
