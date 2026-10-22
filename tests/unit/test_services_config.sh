#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
portal="${ROOT}/config/xdg/hyprland-portals.conf"
waybar="${ROOT}/config/waybar/config.json"

if ! grep -q 'Managed by Corebrum OS' "$portal"; then
  echo "FAIL: portal config is not marked as Corebrum-owned" >&2
  exit 1
fi
if ! grep -q 'org.freedesktop.impl.portal.ScreenCast=wlr' "$portal"; then
  echo "FAIL: portal config does not select the wlr screen cast" >&2
  exit 1
fi
if grep -Eq '^(default=hyprland|[A-Za-z.]+=hyprland)$' "$portal"; then
  echo "FAIL: portal config must not prefer the PPA hyprland portal" >&2
  exit 1
fi

python3 - "$waybar" <<'PY'
import json, sys
cfg = json.load(open(sys.argv[1], encoding="utf-8"))
right = cfg.get("modules-right", [])
for name in ("network", "pulseaudio", "bluetooth", "battery", "tray"):
    if name not in right:
        raise SystemExit(f"FAIL: waybar modules-right missing {name}")
    if name not in cfg:
        raise SystemExit(f"FAIL: waybar missing {name} settings")
PY

echo "ok: services-config"
