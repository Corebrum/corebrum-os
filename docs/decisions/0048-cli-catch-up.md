# 0048. The corebrum command reports menus that already shipped

Date: 2026-10-26
Status: Accepted

## Context

Phases 6, 7, and 10 through 13 shipped as Super+Space menus. `corebrum status` and `corebrum doctor` still stopped at the base, desktop, services, and ROS profiles. The build plan still listed Corebrum Mesh as Phase 8. That product is not being built. Later phase numbers stay as written, because existing decisions cite them.

## Decision

- `corebrum status` and `corebrum doctor` also report RealSense, AgenticROS, and the Skills helper. A missing optional piece is reported and does not fail `doctor`.
- `corebrum camera list` prints RealSense devices when `librealsense2-utils` and `rs-enumerate-devices` are present. Otherwise it points at Super+Space RealSense and exits 0.
- `corebrum agents list` reads the agent catalog and says which CLIs are on `PATH`. It does not install one.
- `corebrum update status` lists Ubuntu, Corebrum, ROS 2, Zenoh, AgenticROS, and AI Agents. It does not run apt or git. Super+Space Updates remains the way to upgrade.
- Corebrum Mesh is removed from the living build plan, the current boundary, and the install overviews. Historical decisions stay as written.

## Consequences

`docs/decisions/0008-corebrum-command.md` still describes the Phase 4 command. This decision is the later catch-up. A two-machine Zenoh test and the Phase 6 camera acceptance check remain open. Neither starts from these report commands.
