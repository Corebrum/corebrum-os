# 0112. Operators may replace Corebrum-installed apps out of band

Date: 2026-11-02
Status: Accepted

## Context

On an NVIDIA Jetson Thor, `realsense-viewer` from the RealSense apt packages warns that CUDA is installed but the viewer was not built with `-DBUILD_WITH_CUDA=ON`. Decision `0062` installs the same noble arm64 RealSense packages on every aarch64 machine, including Jetson and Raspberry Pi. Corebrum does not add a Jetson-only CUDA source build. An operator may still rebuild librealsense (or another Corebrum-installed tool) under `/usr/local` or another path that shadows the packaged binary.

## Decision

- The RealSense menu installer stays on the pinned apt packages and the aarch64 Python path from `0062`. It does not detect Jetson, does not set `BUILD_WITH_CUDA`, and does not replace the SDK with a Corebrum-owned source build for CUDA.
- An operator may rebuild or overwrite a Corebrum-installed application on their own. That replacement is allowed and unsupported. Updates, the RealSense menu, and desktop uninstall do not manage it. The operator keeps those upgrades and cleanups out of band.
- The same boundary applies to other Corebrum-installed tools the operator replaces: Corebrum continues to install and report its own pinned copies; a shadowed or overwritten binary is the operator's.

## Consequences

The Jetson CUDA warning from the packaged viewer can remain. Getting Started notes that a custom rebuild is outside Corebrum Updates. Uninstall still removes only Corebrum-owned apt wiring and files; it does not hunt for operator builds under `/usr/local`.
