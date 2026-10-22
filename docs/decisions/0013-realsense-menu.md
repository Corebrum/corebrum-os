# 0013. RealSense installs from the Super+Space menu

Date: 2026-10-22
Status: Accepted

## Context

RealSense is its own Super+Space entry, separate from the ROS submenu. The name is `RealSense   install` until the tools are present, then `RealSense`. Choosing the installed entry opens a submenu. `corebrum install ros` still does not install it.

On 2026-10-22 the ROS apt archive published `ros-jazzy-librealsense2` 2.58.4 and `ros-jazzy-realsense2-camera` 4.58.4 for noble, and `ros-lyrical-librealsense2` 2.58.4 and `ros-lyrical-realsense2-camera` 4.58.4 for resolute. Those are the packaged forms of [librealsense](https://github.com/realsenseai/librealsense) and [realsense-ros](https://github.com/realsenseai/realsense-ros). The Lyrical librealsense deb's binaries are `rs-enumerate-devices` and the other `rs-*` tools. It does not contain `realsense-viewer`.

The viewer is `/usr/bin/realsense-viewer` in `librealsense2-utils` from `https://librealsense.realsenseai.com/Debian/apt-repo`. That archive publishes 2.59.1 for both noble (`2.59.1-0~realsense.20270`) and resolute (`2.59.1-0~realsense.20271`). noble also publishes `librealsense2-dkms` 1.3.33-noble. resolute does not. The signing key fingerprint is `5381411D24E659FB18195FA5FB0B24895113F120`.

PyPI `pyrealsense2` 2.59.1.11053 publishes x86_64 wheels for Python 3.10 through 3.14. This resolute machine's `python3` is 3.14.4, and the `cp314` wheel is in that release.

## Decision

- Choosing `RealSense   install` runs `/usr/local/lib/corebrum/realsense-install.sh` in a terminal. That script adds the RealSense apt archive, checks the key fingerprint, and pins it so only `librealsense2`, `librealsense2-gl`, `librealsense2-utils`, `librealsense2-udev-rules`, and `librealsense2-dkms` can come from there.
- It then installs those SDK packages at the pinned 2.59.1 version, `ros-<distro>-librealsense2`, `ros-<distro>-realsense2-camera`, and `python3-pip` from Ubuntu. noble also installs the pinned dkms package. resolute skips dkms because that archive has no such package.
- `pyrealsense2==2.59.1.11053` is installed for the system `python3` when that interpreter is 3.10, 3.11, 3.12, 3.13, or 3.14. Other Python versions stop the install.
- Super+Space writes that entry beside ROS, under the user runtime directory, not under `~/.config` and not inside the ROS submenu. The name drops `install` only when `librealsense2-utils`, both ROS packages, `realsense-viewer`, and `import pyrealsense2` are all present. Until then, choosing it installs and does not open a submenu.
- After it is installed, choosing `RealSense` opens a Fuzzel submenu with `RealSense Viewer` and `RealSense ROS`. The viewer runs `realsense-viewer` directly. The ROS setup is not sourced for that launch, so the viewer keeps the `/usr` librealsense library it was linked against. `RealSense ROS` opens a terminal and runs `ros2 launch realsense2_camera rs_launch.py`. The launch file is `/opt/ros/<distro>/share/realsense2_camera/launch/rs_launch.py` from `ros-<distro>-realsense2-camera`.
- Desktop uninstall removes the RealSense apt source, pin, and key. It leaves the installed packages in place.

## Consequences

The RealSense apt origin is a third archive, allowed only for those package names and only after the menu installer runs. A ros dry-run still does not list RealSense. A second menu install leaves the pinned packages in place.
