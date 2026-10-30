#!/usr/bin/env bash
# Super+Space Skills entry. Lists, searches, installs, and removes Corebrum Synapse skills.
# Refresh only writes the desktop row. It does not install a skill.
set -euo pipefail

corebrum_skills_ready() {
  if [[ "${COREBRUM_SKILLS_STUB:-0}" == 1 ]]; then
    [[ "${COREBRUM_SKILLS_READY:-0}" == 1 ]]
    return
  fi
  [[ -x /usr/local/bin/synapse && -f "${HOME}/.synapse/config.json" ]]
}

corebrum_skills_data_dir() {
  local root="${XDG_RUNTIME_DIR:-/tmp/corebrum-launcher-${UID}}"
  printf '%s\n' "${root}/corebrum"
}

corebrum_skills_refresh() {
  local dir dest
  dir="$(corebrum_skills_data_dir)/applications"
  dest="${dir}/corebrum-skills.desktop"
  mkdir -p "$dir"
  if ! corebrum_skills_ready; then
    rm -f "$dest"
    return 0
  fi
  cat >"$dest" <<'EOF'
[Desktop Entry]
Type=Application
Name=Corebrum Skills
GenericName=Corebrum Skills
Comment=Corebrum Synapse skills on this machine
Keywords=skills;synapse
Exec=/usr/local/bin/corebrum-skills-menu open
Icon=/usr/share/corebrum/icon.png
Terminal=false
Categories=Science;Development;
StartupNotify=false
EOF
}

corebrum_skills_labels() {
  printf '%s\n' "List" "Search" "Install" "Remove"
}

corebrum_skills_command() {
  local choice="$1" ref
  case "$choice" in
    List)
      printf '%s\n' "synapse skills list"
      ;;
    Search)
      if [[ "${COREBRUM_SKILLS_STUB:-0}" == 1 ]]; then
        ref="${COREBRUM_SKILLS_QUERY:-}"
        [[ -n "$ref" ]] || return 0
        printf 'synapse skills search %q\n' "$ref"
        return 0
      fi
      printf '%s\n' 'read -r -p "Search skills: " q && synapse skills search "$q"'
      ;;
    Install)
      if [[ "${COREBRUM_SKILLS_STUB:-0}" == 1 ]]; then
        ref="${COREBRUM_SKILLS_QUERY:-}"
        [[ -n "$ref" ]] || return 0
        printf 'synapse skills install %q\n' "$ref"
        return 0
      fi
      printf '%s\n' 'read -r -p "Install skill: " ref && synapse skills install "$ref"'
      ;;
    Remove)
      if [[ "${COREBRUM_SKILLS_STUB:-0}" == 1 ]]; then
        ref="${COREBRUM_SKILLS_QUERY:-}"
        [[ -n "$ref" ]] || return 0
        printf 'synapse skills remove %q\n' "$ref"
        return 0
      fi
      printf '%s\n' 'read -r -p "Remove skill: " ref && synapse skills remove "$ref"'
      ;;
    *)
      return 0
      ;;
  esac
}

corebrum_skills_hold() {
  local script="$1"
  cat <<EOF
set +e
${script}
ec=\$?
set -e
printf '\\n'
read -r -p 'Press Enter to close. '
exit "\$ec"
EOF
}

corebrum_skills_terminal() {
  local script
  script="$(corebrum_skills_hold "$1")"
  if [[ "${COREBRUM_SKILLS_STUB:-0}" == 1 ]]; then
    printf '%s\n' "$script"
    return 0
  fi
  exec /usr/local/bin/corebrum-terminal bash --login -c "$script"
}

corebrum_skills_open() {
  local choice="" script
  if ! corebrum_skills_ready; then
    return 0
  fi
  if [[ "${COREBRUM_SKILLS_STUB:-0}" == 1 ]]; then
    if [[ -n "${COREBRUM_SKILLS_CHOICE:-}" ]]; then
      script="$(corebrum_skills_command "$COREBRUM_SKILLS_CHOICE")"
      [[ -n "$script" ]] || return 0
      corebrum_skills_terminal "$script"
      return 0
    fi
    corebrum_skills_labels
    return 0
  fi
  choice="$(corebrum_skills_labels | fuzzel \
    --config /etc/corebrum/fuzzel/fuzzel.ini \
    --dmenu \
    --prompt 'Corebrum Skills  ' \
    --width 48 \
    --lines 8)" || return 0
  [[ -n "$choice" ]] || return 0
  script="$(corebrum_skills_command "$choice")"
  [[ -n "$script" ]] || return 0
  corebrum_skills_terminal "$script"
}

usage() {
  cat <<'EOF'
Usage: corebrum-skills-menu refresh|open|data-dir
EOF
}

cmd="${1:-}"
case "$cmd" in
  refresh) corebrum_skills_refresh ;;
  open) corebrum_skills_open ;;
  data-dir) corebrum_skills_data_dir ;;
  -h | --help | help) usage ;;
  *)
    usage >&2
    exit 1
    ;;
esac
