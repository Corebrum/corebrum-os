#!/usr/bin/env bash
# Autolock, Autodim, and Voice drill in with Right and list pick rows in GTK.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ui="${ROOT}/scripts/desktop/corebrum-launcher.py"
menu_tree="${ROOT}/config/menu/corebrum-menu.json"
bindir="$(mktemp -d)"
tmp="$(mktemp -d)"
home="${tmp}/home"
runtime="${tmp}/runtime"
menu_data="${runtime}/corebrum"
mkdir -p "${home}/applications" "${menu_data}/applications"

write_desktop() {
  local id="$1" name="$2" exec_line="$3"
  cat >"${menu_data}/applications/${id}.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=${name}
Exec=${exec_line}
Icon=preferences-system
Terminal=false
EOF
}

cat >"${bindir}/corebrum-autolock" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  lines)
    printf '%s\n' 'Stay awake' '10 minutes   on' '5 minutes' '30 minutes' '1 hour'
    ;;
  pick) printf 'autolock-pick:%s\n' "${2:-}" ;;
  *) exit 1 ;;
esac
EOF
cat >"${bindir}/corebrum-autodim" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  lines)
    printf '%s\n' 'Off   on' '5 minutes' '10 minutes' '30 minutes' '1 hour'
    ;;
  pick) printf 'autodim-pick:%s\n' "${2:-}" ;;
  *) exit 1 ;;
esac
EOF
cat >"${bindir}/corebrum-voice-menu" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  labels) printf '%s\n' 'Test speak' 'Hear once' 'Microphone' ;;
  pick) printf 'voice-pick:%s\n' "${2:-}" ;;
  *) exit 1 ;;
esac
EOF
chmod +x "${bindir}/corebrum-autolock" "${bindir}/corebrum-autodim" "${bindir}/corebrum-voice-menu"

write_desktop corebrum-autolock "Autolock" /usr/local/bin/corebrum-autolock
write_desktop corebrum-autodim "Autodim" /usr/local/bin/corebrum-autodim
write_desktop corebrum-voice "Voice" /usr/local/bin/corebrum-voice-menu

export XDG_DATA_HOME="$home"
export XDG_RUNTIME_DIR="$runtime"
export XDG_DATA_DIRS="${menu_data}:${home}:/usr/share"
export PATH="${bindir}:${PATH}"
export COREBRUM_MENU_TREE="$menu_tree"
export COREBRUM_LAUNCHER_LIST=1
export HOME="$home"

names() { cut -f1; }

setup="$(COREBRUM_LAUNCHER_ACTIVE=setup python3 "$ui")"
setup_names="$(names <<<"$setup")"
for row in 'Autolock >' 'Autodim >' 'Voice >'; do
  if ! grep -qx "$row" <<<"$setup_names"; then
    echo "FAIL: Setup did not mark ${row% >} as navigable" >&2
    printf '%s\n' "$setup_names" >&2
    exit 1
  fi
done

lock="$(COREBRUM_LAUNCHER_ACTIVE=corebrum-autolock python3 "$ui")"
if ! grep -qx '10 minutes   on' <<<"$(names <<<"$lock")"; then
  echo "FAIL: Autolock submenu did not list timer rows" >&2
  printf '%s\n' "$lock" >&2
  exit 1
fi
if grep -q ' >' <<<"$(names <<<"$lock")"; then
  echo "FAIL: Autolock choice rows should be leaves" >&2
  printf '%s\n' "$lock" >&2
  exit 1
fi

dim="$(COREBRUM_LAUNCHER_ACTIVE=corebrum-autodim python3 "$ui")"
if ! grep -qx 'Off   on' <<<"$(names <<<"$dim")"; then
  echo "FAIL: Autodim submenu did not list timer rows" >&2
  printf '%s\n' "$dim" >&2
  exit 1
fi

voice="$(COREBRUM_LAUNCHER_ACTIVE=corebrum-voice python3 "$ui")"
if ! grep -qx 'Test speak' <<<"$(names <<<"$voice")"; then
  echo "FAIL: Voice submenu did not list labels" >&2
  printf '%s\n' "$voice" >&2
  exit 1
fi

search="$(COREBRUM_LAUNCHER_ACTIVE=setup COREBRUM_LAUNCHER_QUERY='stay awake' python3 "$ui")"
if ! grep -q $'^Stay awake\tSetup / Autolock$' <<<"$search"; then
  echo "FAIL: typing stay awake did not find Autolock choice under Setup" >&2
  printf '%s\n' "$search" >&2
  exit 1
fi

if ! grep -q '"choosers"' "$menu_tree"; then
  echo "FAIL: menu tree has no choosers block" >&2
  exit 1
fi

rm -rf "$tmp" "$bindir"
echo "launcher choosers unit tests passed"
