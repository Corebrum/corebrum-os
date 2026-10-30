# 0051. Creep or Treat closes the Phase 7 skill check

Date: 2026-10-26
Status: Accepted

## Context

Phase 7 asks Corebrum Synapse to discover the local ROS graph, run a supported skill, read the camera, keep cloud optional, and work without a network service in the loop. This machine has a RealSense D435 and no wheel or motor controller, so a driving skill was the wrong check. Creep or Treat (`@corebrum/halloween`) stays still and uses the camera and depth.

## Decision

- Corebrum Synapse 0.7.38 is installed. `~/.synapse/config.json` sets transport mode `local`. `/etc/corebrum/ros/rmw` is `rmw_zenoh_cpp`. Doctor sees ROS 2 Lyrical and the D435. Cloud login is optional. An OpenAI key is not set.
- The operator approved `synapse skills install @corebrum/halloween`. Version 0.2.2 is registered. The first copy failed because `/tmp` is tmpfs and the cache rename could not cross onto the home disk. The package's dev dependencies also point at a relative Corebrum Synapse checkout that is not next to the cache. Runtime dependencies were installed with `npm install --omit=dev`, and the install then registered the skill.
- With the D435 publishing depth, the skill ran for about 12 seconds in depth-only mode. It moved from idle to the bowl zone at 0.68 m, spoke "There you are. The bowl is at my feet." and "There it is. Take one.", then the scream line "Ah! Slow down, little ghost." Status showed one visitor. Stop reported that no velocity command was sent.
- The YOLO person gate did not start in that run (`detect-person --serve` exited 1), so the run used the skill's depth fallback. `paplay`, `aplay`, and `afplay` were absent, so the scream line was spoken.

## Consequences

The Phase 7 acceptance checks are met on this machine without a mobile base. Driving, mapping, and arm skills remain untested here. A later install of this skill on a machine where `/tmp` and the home directory are different filesystems needs the cache copy to tolerate that.
