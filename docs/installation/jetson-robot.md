# Jetson reference robot (GPIO motors)

The reference Physical AI kit is a **Jetson Orin** on Corebrum OS, an **L298N** dual motor driver, and a **RealSense** depth camera—no Arduino.

## JETGPIO

Native GPIO motors use [JETGPIO](https://github.com/Rubberazer/JETGPIO) (`libjetgpio.so`). The standalone v1.2 release is recommended.

```bash
# Operator-run; not part of corebrum install ros.
git clone https://github.com/Rubberazer/JETGPIO.git
cd JETGPIO
# follow upstream build + sudo make install
```

Optional helper (dry-run first):

```bash
sudo /usr/local/lib/corebrum/install-jetgpio.sh --dry-run
```

JETGPIO often needs **root** or `/dev/mem` access when starting motors. See `synapse doctor` on the robot.

## Wiring and pins

Default BOARD pins **16, 18, 22, 26** to L298N IN1–IN4. ENA/ENB stay jumpered high. Full tables: [Synapse hardware.md](https://github.com/Corebrum/corebrum-synapse/blob/main/docs/hardware.md).

## Synapse

On Tegra, `synapse start motors` selects the **jetson** backend automatically after JETGPIO is installed.

```bash
synapse start motors -p 16,18,22,26 --odom
synapse up real
# Optional mapping (after corebrum install ros --mapping):
synapse up real --map
synapse connect   # Cloud teleop and live map
```

## Mapping packages

RTAB-Map and Nav2 are **not** in the default ROS profile:

```bash
sudo corebrum install ros --mapping
```

Or Super+Space **ROS** → **Mapping stack install**.

## Alternates

Raspberry Pi uses `-b rpi`. x86 or RADXA with an Arduino uses `-b firmata`. See `manifests/hardware/` in corebrum-os.