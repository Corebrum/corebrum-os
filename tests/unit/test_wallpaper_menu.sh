#!/usr/bin/env bash
# Wallpaper is a Super+Space image list. The desktop profile installs hyprpaper.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
menu="${ROOT}/scripts/desktop/corebrum-wallpaper-menu.sh"
launcher="${ROOT}/scripts/desktop/corebrum-launcher.sh"
fail=0

assert_grep() {
  local pattern="$1" file="$2" message="$3"
  if ! grep -qE "$pattern" "$file"; then
    echo "FAIL: ${message}" >&2
    fail=1
  fi
}

assert_grep 'corebrum-wallpaper-menu refresh' "$launcher" "launcher does not refresh Wallpaper"
assert_grep 'config/hypr/wallpapers/' "${ROOT}/scripts/lib/desktop.sh" "desktop install does not copy the Corebrum wallpapers"
assert_grep 'wall3.png' "${ROOT}/scripts/lib/desktop.sh" "desktop install does not include wall3.png"
assert_grep 'dpkg-divert --local --rename' "${ROOT}/scripts/lib/desktop.sh" "desktop install does not keep a package upgrade from replacing the wallpapers"
assert_grep 'splash = false' "$menu" "hyprpaper config leaves splash text on"
assert_grep 'monitor = \*' "$menu" "hyprpaper config uses an empty monitor name"
assert_grep 'hyprpaper candidate' "${ROOT}/scripts/phases/02-desktop.sh" "desktop profile does not install Ubuntu hyprpaper"
assert_grep 'installing hyprpaper from ppa:cppiber/hyprland' "${ROOT}/scripts/phases/02-desktop.sh" "Ubuntu 24.04 desktop profile does not install hyprpaper"
assert_grep '^hyprpaper$' "${ROOT}/manifests/packages/hyprland-ppa.txt" "Hyprland PPA pin does not allow hyprpaper"
assert_grep '^libhyprtoolkit6$' "${ROOT}/manifests/packages/hyprland-ppa.txt" "Hyprland PPA pin does not allow hyprpaper's library"
assert_grep 'systemctl --global disable hyprpaper.service' "${ROOT}/scripts/lib/desktop.sh" "desktop install leaves the packaged hyprpaper service enabled"
if grep -q 'apt-get install -y hyprpaper' "$menu"; then
  echo "FAIL: wallpaper menu still installs hyprpaper" >&2
  fail=1
fi
if grep -q 'Wallpaper   install' "$menu"; then
  echo "FAIL: wallpaper menu still offers a separate install" >&2
  fail=1
fi
if grep -q 'corebrum-waypaper-menu refresh' "$launcher"; then
  echo "FAIL: Super+Space still refreshes Waypaper" >&2
  fail=1
fi
if grep -qE '^hyprpaper$' "${ROOT}/manifests/packages/desktop.txt"; then
  echo "FAIL: hyprpaper is listed in the Ubuntu 24.04 archive manifest" >&2
  fail=1
fi
if grep -q 'pipx' "$menu"; then
  echo "FAIL: wallpaper menu installs Waypaper" >&2
  fail=1
fi
if ! grep -q 'ExecStart=/bin/true' "${ROOT}/config/systemd/user/hyprpaper.service.d/corebrum.conf"; then
  echo "FAIL: the packaged hyprpaper service can still draw a wallpaper" >&2
  fail=1
fi

runtime="$(mktemp -d)"
pictures="$(mktemp -d)"
walls="$(mktemp -d)"
state="$(mktemp -d)"
printf 'png\n' >"${walls}/wall2.png"
printf 'png\n' >"${pictures}/Desk.png"
printf 'png\n' >"${pictures}/My Vacation.jpg"
mkdir -p "${pictures}/Wallpapers"
printf 'png\n' >"${pictures}/Wallpapers/extra.webp"
printf 'nope\n' >"${pictures}/notes.txt"

export XDG_RUNTIME_DIR="$runtime"
export XDG_STATE_HOME="$state"
export HOME=/home/corebrum
export COREBRUM_WALLPAPER_STUB=1
export COREBRUM_WALLPAPER_LIB_DIR="$walls"
export COREBRUM_WALLPAPER_PICTURES="$pictures"

name="$(bash "$menu" entry-name)"
if [[ "$name" != "Wallpaper" ]]; then
  echo "FAIL: wallpaper entry is not Wallpaper (got ${name})" >&2
  fail=1
fi

bash "$menu" refresh
desktop="${runtime}/corebrum/applications/corebrum-wallpaper.desktop"
if ! grep -q '^Name=Wallpaper$' "$desktop"; then
  echo "FAIL: desktop entry name is not Wallpaper" >&2
  fail=1
fi
if ! grep -q '^Exec=/usr/local/bin/corebrum-wallpaper-menu open$' "$desktop"; then
  echo "FAIL: desktop entry does not open the wallpaper menu" >&2
  fail=1
fi
printf 'old\n' >"${runtime}/corebrum/applications/corebrum-waypaper.desktop"
bash "$menu" refresh
if [[ -e "${runtime}/corebrum/applications/corebrum-waypaper.desktop" ]]; then
  echo "FAIL: refresh leaves the Waypaper desktop entry" >&2
  fail=1
fi

output="$(bash "$menu" open)"
if [[ "$output" == *'apt-get install'* ]]; then
  echo "FAIL: selecting Wallpaper still installs a package" >&2
  fail=1
fi
if [[ "$output" == *'waypaper'* ]]; then
  echo "FAIL: selecting Wallpaper still installs Waypaper" >&2
  fail=1
fi

output="$(bash "$menu" open)"
if [[ "$output" != $'Add image\nCorebrum wall2.png\nDesk.png\nMy Vacation.jpg\nextra.webp' ]]; then
  echo "FAIL: wallpaper list was ${output}" >&2
  fail=1
fi

output="$(COREBRUM_WALLPAPER_CHOICE='My Vacation.jpg' bash "$menu" open)"
if [[ "$output" != "${pictures}/My Vacation.jpg" ]]; then
  echo "FAIL: choice did not select the picture (got ${output})" >&2
  fail=1
fi
cfg="${state}/corebrum/hyprpaper.conf"
if ! grep -q 'splash = false' "$cfg"; then
  echo "FAIL: saved hyprpaper config leaves splash on" >&2
  fail=1
fi
if ! grep -F "monitor = *" "$cfg" >/dev/null; then
  echo "FAIL: saved hyprpaper config has no monitor wildcard" >&2
  fail=1
fi
if ! grep -F "path = ${pictures}/My Vacation.jpg" "$cfg" >/dev/null; then
  echo "FAIL: saved hyprpaper config does not use the chosen image" >&2
  fail=1
fi

added="$(mktemp -d)"
printf 'png\n' >"${added}/room.png"
output="$(COREBRUM_WALLPAPER_CHOICE='Add image' COREBRUM_WALLPAPER_ADD="${added}/room.png" bash "$menu" open)"
if [[ "$output" != "${pictures}/Wallpapers/room.png" ]]; then
  echo "FAIL: add image did not copy into Wallpapers (got ${output})" >&2
  fail=1
fi
if ! grep -F "path = ${pictures}/Wallpapers/room.png" "$cfg" >/dev/null; then
  echo "FAIL: add image did not set the copied wallpaper" >&2
  fail=1
fi

printf 'png\n' >"${added}/extra.webp"
output="$(COREBRUM_WALLPAPER_CHOICE='Add image' COREBRUM_WALLPAPER_ADD="${added}/extra.webp" bash "$menu" open)"
if [[ "$output" != "${pictures}/Wallpapers/extra-2.webp" ]]; then
  echo "FAIL: add image replaced an existing file (got ${output})" >&2
  fail=1
fi
if [[ "$(cat "${pictures}/Wallpapers/extra.webp")" != "png" ]]; then
  echo "FAIL: add image overwrote the existing wallpaper file" >&2
  fail=1
fi

if COREBRUM_WALLPAPER_CHOICE='Add image' COREBRUM_WALLPAPER_ADD="${pictures}/notes.txt" bash "$menu" open >/dev/null 2>&1; then
  echo "FAIL: add image accepted a file that is not an image" >&2
  fail=1
fi

output="$(COREBRUM_WALLPAPER_CHOICE='Add image' bash "$menu" open)"
if [[ -n "$output" ]]; then
  echo "FAIL: cancelling add image still changed the wallpaper (got ${output})" >&2
  fail=1
fi

rm -rf "$runtime" "$pictures" "$walls" "$state" "$added"
if [[ "$fail" -ne 0 ]]; then
  exit 1
fi
echo "wallpaper menu unit tests passed"
