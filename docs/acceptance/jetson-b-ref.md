# Jetson B-ref acceptance (corebrum-os)

Cross-repo software for the reference embodiment ships in Synapse, Cloud, corebrum-os, and corebrum.com. **Motion B-ref** still runs only on a physical Orin kit with motors wired.

## Automated pre-checks (no motion)

On the robot or in CI on a non-Tegra host:

```bash
bash scripts/validate/jetson-b-ref.sh
```

On Tegra without `COREBRUM_B_REF_MOTION=1`, the script runs `synapse doctor` and Synapse motor-backend unit tests. It does not publish `/cmd_vel`.

## Full B-ref checklist

[corebrum-synapse `docs/acceptance/jetson-b-ref.md`](https://github.com/Corebrum/corebrum-synapse/blob/main/docs/acceptance/jetson-b-ref.md)

When B-ref passes on hardware, update `docs/decisions/0136-jetson-reference-embodiment.md` with the date and machine details, then adjust corebrum.com copy from “designed for” to “validated on” the reference kit.