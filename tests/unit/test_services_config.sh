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
loaded = json.load(open(sys.argv[1], encoding="utf-8"))
bars = loaded if isinstance(loaded, list) else [loaded]
cfg = next((bar for bar in bars if "modules-right" in bar), None)
if cfg is None:
    raise SystemExit("FAIL: waybar has no top bar")
right = cfg.get("modules-right", [])
for name in ("network", "pulseaudio", "battery", "tray"):
    if name not in right:
        raise SystemExit(f"FAIL: waybar modules-right missing {name}")
    if name not in cfg:
        raise SystemExit(f"FAIL: waybar missing {name} settings")
if "bluetooth" in right or "bluetooth" in cfg:
    raise SystemExit("FAIL: waybar still shows a Bluetooth status beside the Blueman tray icon")
tagline = next((bar for bar in bars if bar.get("name") == "tagline"), None)
if tagline is None:
    raise SystemExit("FAIL: waybar has no tagline bar")
text = tagline.get("custom/tagline", {}).get("format", "")
if text != "Corebrum: The Physical AI Operating System":
    raise SystemExit(f"FAIL: tagline text is {text!r}")
PY

echo "ok: services-config"
