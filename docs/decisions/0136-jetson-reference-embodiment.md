# 0136. Jetson reference embodiment

Date: 2026-11-15
Status: Accepted; B-ref and C-ref passed on physical Jetson Orin kit (2026-11-16); D-ref mapping pending

## Context

Corebrum OS integrates ROS 2, RealSense, Corebrum Synapse, and Corebrum Cloud. Synapse ships differential motor controllers (Pi GPIO, Firmata, Jetson JETGPIO), optional RTAB-Map + Nav2 mapping, and Cloud teleop. Operators need one documented reference kit and OS surfaces that match Synapse defaults.

## Decision

- **Reference kit:** Jetson Tegra + L298N + RealSense, native GPIO via JETGPIO (pins 16,18,22,26), cmd_vel dead-reckon odom, visual odom for mapping.
- **Synapse** auto-selects `jetson` motor backend on Tegra (Cloud portal `motorBackend` and `-b` overrides remain).
- **corebrum-os** optional mapping stack: `corebrum install ros --mapping` and Super+Space ROS → Mapping stack install; not in default `corebrum install ros`.
- **Hardware manifests** under `manifests/hardware/` (`jetson-orin-2wd-jetgpio`, Pi, Firmata alternates).
- **Corebrum Cloud** defaults new robots to Jetson Orin Nano, stores `motorBackend`, and builds remote `start_motors` CLI from the robot record.
- **Acceptance tiers:** B-ref = motors + cmd_vel on Orin; C-ref = Cloud teleop; D-ref = mapping + navigate. Record B-ref results when the physical kit passes (see Synapse `docs/acceptance/jetson-b-ref.md` and `scripts/validate/jetson-b-ref.sh` for non-motion pre-checks).

## Hardware acceptance (2026-11-16)

Operator validation on a Jetson Orin reference build:

- **B-ref (pass):** L298N wired from **native Tegra GPIO** (JETGPIO), **no Arduino**; pins **16,18,22,26**; `synapse start motors` / cmd_vel motion on a differential base.
- **C-ref (pass):** Drive demonstrated via **Corebrum Cloud teleop** after `synapse connect` (operator demo video).
- **D-ref (pending):** RTAB-Map + Nav2 + Cloud navigate mission not recorded on this kit yet.

## Consequences

- Website copy uses **“validated on”** the reference Orin for GPIO drive and Cloud teleop (2026-11-16); mapping remains optional until D-ref.
- Encoder odom stays Firmata-only; Jetson mapping uses RTAB-Map visual odom unless `--wheel-odom` is validated later.
- Embodiment logic remains in Synapse; corebrum-os installs packages and exposes menus/doctor hints.
- Super+Space Synapse **Robot: Drive setup** runs `synapse embodiment setup` (local configstore + optional Cloud PATCH).