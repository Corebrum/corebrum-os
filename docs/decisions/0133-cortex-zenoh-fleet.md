# 0133. Cortex joins the Zenoh fleet router

Date: 2026-11-09
Status: Accepted

## Context

Corebrum, Synapse, ROS 2, and Cortex need one Zenoh version and one router. The Python client was pinned at `eclipse-zenoh` 1.9.0 because the recorded `rmw_zenohd` vendored 1.8.0. Eclipse Zenoh 1.10.2 is the current release. Zenoh fleet 0.1.4 wrote an Eclipse `zenohd` config and a `corebrum daemon` line, and the Super+Space menu left those files unapplied. Corebrum OS already runs `rmw_zenohd` on port 7447.

## Decision

- `corebrum install ros` installs `eclipse-zenoh` 1.10.2 with `zenoh-cli` 0.7.0. The 1.9 pin is gone.
- `@corebrum/zenoh-fleet` 0.1.6 is the menu pin. The package and repository are Corebrum, not AgenticROS. A Corebrum OS hub does not get `zenohd.json5`. Members get an `rmw_zenoh` client session. The deploy line is `cortex daemon --zenoh-router`. WebSocket port 10000 is only when AgenticROS is selected. The DDS bridge is off unless requested.
- After the wizard, the menu runs `corebrum zenoh fleet apply`. A hub writes `/etc/corebrum/zenoh/router` as `tcp://127.0.0.1:7447` and leaves `corebrum-zenoh-router.service` running. A member installs the session as `ZENOH_SESSION_CONFIG_URI`, points the router file at the hub, and stops the local router.
- `corebrum cortex install` builds the sibling `corebrum-cortex` checkout. `corebrum cortex daemon` uses the router file. The desktop profile does not start the daemon and Super+Space has no Cortex row.
- Cortex workers announce uptime, LAN addresses, battery, and whether they will route. `cortex supernode elect` picks one supernode: the current hub when it is still eligible, otherwise the longest uptime that is not on battery. `corebrum cortex elect` writes the same zenoh-fleet hub or member files and applies them.
- Placement labels `gpu`, `cpu`, and `camera` are not auto-installed. A detection task that depends on `gpu` stays off a worker that does not advertise it.
- `synapse cortex` runs `compute-stats`, `submit`, `status`, and `results`. The standing instruction tells agents that motion stays on the Synapse tools. Synapse pins `@eclipse-zenoh/zenoh-ts` 1.10.2.

## Consequences

The official `rmw_zenoh` debs still vendor Zenoh 1.10.1 plus fixes, and the 2026-10-22 record was 1.8.0. This change does not rebuild that package. The router binary moves to 1.10.2 when the deb does, or when `zenoh_cpp_vendor` is built with `USE_SYSTEM_ZENOH`. Until then clients are 1.10.2 and `rmw_zenohd` is the apt package.
