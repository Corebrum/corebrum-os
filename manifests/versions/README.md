# Version pinning

Each installable component has two files:

- `manifests/packages/<name>.txt` lists Ubuntu package names, one per line.
- `manifests/versions/<name>.txt` records the constraint that selected those packages.

`versions` files are `key: value` records. Required keys are `component`, `ubuntu`, `arch`, `source`, `packages`, and `pin`.

New installs target Ubuntu Server 26.04 on x86-64 and ARM64. The base profile is pinned by that archive, not by individual package versions. Older records in this directory still name Ubuntu 24.04 pins from earlier work. Later robotics components must name the upstream repository, the distro (ROS 2 Lyrical), and any version floor that keeps Zenoh, RViz, and Gazebo compatible. Do not float those constraints across unrelated updates.

Package lists accept blank lines and `#` comments. A package token must match `^[a-z0-9][a-z0-9+.-]*$`. The installer rejects anything else.
