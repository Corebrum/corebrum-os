# 0062. RealSense on aarch64 beside the x86-64 installer

Date: 2026-10-26
Status: Accepted

## Context

The RealSense menu installer stopped on this Raspberry Pi with `pyrealsense2 wheels used here are x86_64 only`. Decision 0013 installs `pyrealsense2==2.59.1.11053` for the system `python3` on x86-64. That release publishes x86-64 wheels for Python 3.10 through 3.14. Its aarch64 wheels are Python 3.9, 3.10, and 3.12. This machine's `python3` is 3.14.4. Ubuntu 26.04 does not publish another Python in the archive.

The RealSense apt archive's resolute suite lists architectures amd64 and i386. Its noble suite lists arm64, and the arm64 build of 2.59.1 is `2.59.1-0~realsense.9166`, including `librealsense2-utils`. That package depends on `libc6` >= 2.38 and `libssl3t64`. The x86-64 pins stay `2.59.1-0~realsense.20270` on noble and `2.59.1-0~realsense.20271` on resolute. `ros-lyrical-librealsense2` and `ros-lyrical-realsense2-camera` already have arm64 candidates.

librealsense tag `v2.59.1` is commit `625279aa1fe903528a818f48746ee47c1b5fefd3`. Its Python binding builds with `FORCE_RSUSB_BACKEND`, so the Pi does not need the dkms kernel module.

## Decision

- x86-64 still installs the same pinned SDK versions, the noble dkms package, and `pyrealsense2==2.59.1.11053` from PyPI with the system Python. The apt pin list is unchanged.
- aarch64 installs `2.59.1-0~realsense.9166` from the noble suite of the same RealSense archive, for both noble and resolute. It does not install `librealsense2-dkms`. The ROS camera packages are still the unpinned `ros-<distro>-librealsense2` and `ros-<distro>-realsense2-camera` packages.
- On aarch64, Python 3.10 and 3.12 install the published wheel at the same PyPI version. Python 3.11, 3.13, and 3.14 build tag `v2.59.1` after the tag still resolves to `625279aa1fe903528a818f48746ee47c1b5fefd3`. The build installs only the Python module into the system Python platlib. The C++ library install prefix is a temporary directory.
- Other architectures still stop.

## Consequences

An x86-64 RealSense install follows decision 0013. A Raspberry Pi on Ubuntu 26.04 can install the viewer from the noble arm64 packages and a Python 3.14 module built from the matching SDK tag. The source build compiles librealsense and downloads the pybind11 revision that tag's CMake requests. A second install does not compile again when `import pyrealsense2` already succeeds.
