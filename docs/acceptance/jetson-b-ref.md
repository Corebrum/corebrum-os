# Jetson B-ref acceptance (corebrum-os)

Cross-repo software for the reference embodiment ships in Synapse, Cloud, corebrum-os, and corebrum.com.

**Hardware (2026-11-16):** B-ref and C-ref passed on operator Jetson Orin kit (GPIO → L298N, Cloud teleop). See `docs/decisions/0136-jetson-reference-embodiment.md`. D-ref mapping still optional.

## Automated pre-checks (no motion)

On the robot or in CI on a non-Tegra host:

```bash
bash scripts/validate/jetson-b-ref.sh
```

On Tegra without `COREBRUM_B_REF_MOTION=1`, the script runs `synapse doctor` and Synapse motor-backend unit tests. It does not publish `/cmd_vel`.

## Full B-ref checklist

[corebrum-synapse `docs/acceptance/jetson-b-ref.md`](https://github.com/Corebrum/corebrum-synapse/blob/main/docs/acceptance/jetson-b-ref.md)

B-ref/C-ref results live in ADR 0136 and Synapse `docs/acceptance/jetson-b-ref.md` / `jetson-c-ref.md`.