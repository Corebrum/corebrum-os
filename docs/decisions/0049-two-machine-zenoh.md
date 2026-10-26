# 0049. Two machines exchange ROS topics through one Zenoh router

Date: 2026-10-26
Status: Accepted

## Context

Phase 5 still needed a recorded check between two computers. This machine was Ubuntu 26.04 at 192.168.8.100. The ThinkPad was Ubuntu 26.04 at 192.168.8.193. Both ran ROS 2 Lyrical, `ROS_DOMAIN_ID` 0, `RMW_IMPLEMENTATION=rmw_zenoh_cpp`, and a Corebrum Zenoh router on port 7447.

The default session is `mode: "peer"` and listens on `tcp/localhost:0`. Pointing only the listener at `tcp/192.168.8.100:7447` did not deliver messages. The listener discovered the publisher at `tcp/127.0.0.1` and could not open that address.

## Decision

- Shells that exchange messages use a copy of `DEFAULT_RMW_ZENOH_SESSION_CONFIG.json5` with `mode` set to `client` and the connect endpoint set to `tcp/<router-address>:7447`.
- The publisher uses that client file too. A publisher left on the default peer session is not reachable from the other machine.
- Each machine may keep the router installed by `corebrum install ros`. The test shells use one of those routers.
- On 2026-10-26 the ThinkPad received `std_msgs/String` on `/corebrum_link` from this machine about once a second.
- The clocks differed by about 11 seconds. Zenoh replaced timestamps more than 500 ms off. The payload still arrived.

## Consequences

Phase 5's two-machine topic check is recorded. A service or action across the two machines was not part of this run. Local services and actions stay covered by `scripts/validate/ros-graph.sh`. Phase 6 is next: RealSense RGB, depth, ROS topics, RViz, and reconnect.
