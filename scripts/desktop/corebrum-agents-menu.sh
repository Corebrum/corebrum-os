#!/usr/bin/env bash
# Super+Space AI Agents entry. Install a CLI, or launch it in a terminal.
set -euo pipefail

COREBRUM_AGENTS_INSTALL_MARK='   install'
COREBRUM_AGENTS_DEFAULT="/etc/corebrum/agents.conf"

corebrum_agents_die() {
  printf 'corebrum-agents-menu: %s\n' "$1" >&2
  exit 1
}

corebrum_agents_catalog() {
  if [[ -n "${COREBRUM_AGENTS_FILE:-}" ]]; then
    printf '%s\n' "$COREBRUM_AGENTS_FILE"
  else
    printf '%s\n' "$COREBRUM_AGENTS_DEFAULT"
  fi
}

corebrum_agents_prepare_path() {
  local here helper
  if [[ "${COREBRUM_AGENTS_STUB:-0}" == 1 ]]; then
    return 0
  fi
  here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  if [[ -f "${here}/corebrum-node-path.sh" ]]; then
    helper="${here}/corebrum-node-path.sh"
  else
    helper=/usr/local/lib/corebrum/node-path.sh
  fi
  if [[ -f "$helper" ]]; then
    # shellcheck disable=SC1090
    source "$helper"
    corebrum_node_prepare_path
  elif [[ -n "${HOME:-}" ]]; then
    export PATH="${HOME}/.local/bin:${PATH}"
  fi
}

# Register installed agents without holding Super+Space. The setup rewrites
# agent config and does not change the desktop entries this refresh writes.
corebrum_agents_couple_async() {
  local lock_dir lock
  if [[ "${COREBRUM_AGENTS_STUB:-0}" == 1 ]]; then
    corebrum_agents_couple
    return 0
  fi
  if [[ ! -x /usr/local/bin/synapse || ! -f "${HOME}/.synapse/config.json" ]]; then
    return 0
  fi
  if ! command -v setsid >/dev/null 2>&1 || ! command -v flock >/dev/null 2>&1; then
    corebrum_agents_couple
    return 0
  fi
  lock_dir="${XDG_RUNTIME_DIR:-/tmp}/corebrum"
  mkdir -p "$lock_dir"
  lock="${lock_dir}/agents-couple.lock"
  setsid --fork flock -n "$lock" /usr/local/bin/synapse mcp setup --installed --quiet \
    </dev/null >/dev/null 2>&1 || true
}

corebrum_agents_load() {
  local file line id label binary kind install launch
  local -a fields=()
  file="$(corebrum_agents_catalog)"
  [[ -f "$file" ]] || corebrum_agents_die "missing agent list ${file}"
  AGENTS_IDS=()
  AGENTS_LABELS=()
  AGENTS_BINS=()
  AGENTS_KINDS=()
  AGENTS_INSTALLS=()
  AGENTS_LAUNCH=()
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" ]] && continue
    IFS='^' read -r -a fields <<<"$line"
    if [[ "${#fields[@]}" -ne 6 ]]; then
      corebrum_agents_die "invalid agent line: ${line}"
    fi
    id="${fields[0]}"
    label="${fields[1]}"
    binary="${fields[2]}"
    kind="${fields[3]}"
    install="${fields[4]}"
    launch="${fields[5]}"
    [[ "$id" =~ ^[a-z0-9-]+$ ]] || corebrum_agents_die "invalid agent id: ${id}"
    [[ "$binary" =~ ^[a-z0-9-]+$ ]] || corebrum_agents_die "invalid binary for ${id}"
    [[ "$kind" == "script" || "$kind" == "npm" ]] || corebrum_agents_die "invalid install kind for ${id}"
    [[ "$launch" =~ ^[a-z0-9-]+$ ]] || corebrum_agents_die "invalid launch command for ${id}"
    [[ -n "$label" ]] || corebrum_agents_die "missing label for ${id}"
    if [[ "$kind" == "npm" ]]; then
      [[ "$install" =~ ^(@[a-z0-9-]+/)?[a-z0-9][a-z0-9._-]*(@[A-Za-z0-9._+-]+)?$ ]] || corebrum_agents_die "invalid npm package for ${id}"
    else
      [[ "$install" =~ ^curl\ -fsS(L)?\ https://[A-Za-z0-9./_-]+\ \|\ (bash|sh)$ ]] || corebrum_agents_die "invalid install command for ${id}"
    fi
    AGENTS_IDS+=("$id")
    AGENTS_LABELS+=("$label")
    AGENTS_BINS+=("$binary")
    AGENTS_KINDS+=("$kind")
    AGENTS_INSTALLS+=("$install")
    AGENTS_LAUNCH+=("$launch")
  done <"$file"
  [[ "${#AGENTS_IDS[@]}" -gt 0 ]] || corebrum_agents_die "agent list is empty: ${file}"
}

corebrum_agents_cursor_ready() {
  local bin="" resolved=""
  if command -v agent >/dev/null 2>&1; then
    bin="$(command -v agent)"
  elif [[ -x "${HOME}/.local/bin/agent" ]]; then
    bin="${HOME}/.local/bin/agent"
  fi
  [[ -n "$bin" ]] || return 1
  resolved="$(readlink -f "$bin" 2>/dev/null || printf '%s' "$bin")"
  [[ "$resolved" == *cursor-agent* ]]
}

corebrum_agents_ready() {
  local i="$1" binary
  binary="${AGENTS_BINS[$i]}"
  if [[ "${COREBRUM_AGENTS_STUB:-0}" == 1 ]]; then
    [[ " ${COREBRUM_AGENTS_INSTALLED:-} " == *" ${binary} "* ]]
    return
  fi
  if [[ "${AGENTS_IDS[$i]}" == "cursor" ]]; then
    corebrum_agents_cursor_ready
    return
  fi
  command -v "$binary" >/dev/null 2>&1 && return 0
  [[ -x "${HOME}/.local/bin/${binary}" ]]
}

corebrum_agents_choice_label() {
  local i="$1"
  if corebrum_agents_ready "$i"; then
    printf '%s\n' "${AGENTS_LABELS[$i]}"
  else
    printf '%s%s\n' "${AGENTS_LABELS[$i]}" "$COREBRUM_AGENTS_INSTALL_MARK"
  fi
}

corebrum_agents_labels() {
  local i
  corebrum_agents_prepare_path
  corebrum_agents_load
  for i in "${!AGENTS_IDS[@]}"; do
    corebrum_agents_choice_label "$i"
  done
}

corebrum_agents_data_dir() {
  local root="${XDG_RUNTIME_DIR:-/tmp/corebrum-launcher-${UID}}"
  printf '%s\n' "${root}/corebrum"
}

corebrum_agents_mcp_flag() {
  case "$1" in
    antigravity) printf 'agy\n' ;;
    *) printf '%s\n' "$1" ;;
  esac
}

# Write Corebrum Synapse into an agent's config. Idempotent. Order of install does not matter.
corebrum_agents_couple() {
  local flag="${1:-}"
  if [[ "${COREBRUM_AGENTS_STUB:-0}" == 1 ]]; then
    if [[ "${COREBRUM_SYNAPSE_READY:-0}" != 1 ]]; then
      return 0
    fi
    if [[ -n "$flag" ]]; then
      printf 'synapse mcp setup --%s --quiet\n' "$flag"
    else
      printf 'synapse mcp setup --installed --quiet\n'
    fi
    return 0
  fi
  if [[ ! -x /usr/local/bin/synapse || ! -f "${HOME}/.synapse/config.json" ]]; then
    return 0
  fi
  if [[ -n "$flag" ]]; then
    /usr/local/bin/synapse mcp setup "--${flag}" --quiet || true
  else
    /usr/local/bin/synapse mcp setup --installed --quiet || true
  fi
}

corebrum_agents_clear_leaves() {
  local dir="$1" file
  shopt -s nullglob
  for file in "${dir}"/corebrum-agent-*.desktop; do
    rm -f "$file"
  done
  shopt -u nullglob
}

corebrum_agents_refresh() {
  local dir i id label
  corebrum_agents_couple_async
  corebrum_agents_prepare_path
  corebrum_agents_load
  dir="$(corebrum_agents_data_dir)/applications"
  mkdir -p "$dir"
  cat >"${dir}/corebrum-agents.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=AI Agents
GenericName=AI Agents
Comment=Install or launch an AI agent CLI
Exec=/usr/local/bin/corebrum-agents-menu open
Icon=/usr/share/corebrum/agents.png
Terminal=false
Categories=Development;
StartupNotify=false
EOF
  # One desktop file per CLI so Super+Space can match "grok" without opening this menu.
  corebrum_agents_clear_leaves "$dir"
  for i in "${!AGENTS_IDS[@]}"; do
    id="${AGENTS_IDS[$i]}"
    label="$(corebrum_agents_choice_label "$i")"
    cat >"${dir}/corebrum-agent-${id}.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=${label}
GenericName=${AGENTS_LABELS[$i]}
Keywords=${id};${AGENTS_BINS[$i]};${AGENTS_LABELS[$i]};
Comment=AI Agents
Exec=/usr/local/bin/corebrum-agents-menu launch ${id}
Icon=/usr/share/corebrum/agents.png
Terminal=false
Categories=Development;
StartupNotify=false
NoDisplay=true
EOF
  done
}

corebrum_agents_terminal() {
  local script="$1"
  if [[ "${COREBRUM_AGENTS_STUB:-0}" == 1 ]]; then
    printf '%s\n' "$script"
    return 0
  fi
  exec /usr/local/bin/corebrum-terminal bash -c "$script"
}

corebrum_agents_npm_package() {
  local spec="$1"
  if [[ "$spec" == @*/*@* ]]; then
    printf '%s\n' "${spec%@*}"
  elif [[ "$spec" == @* ]]; then
    printf '%s\n' "$spec"
  else
    printf '%s\n' "${spec%%@*}"
  fi
}

corebrum_agents_find() {
  local id="$1" i
  [[ "$id" =~ ^[a-z0-9-]+$ ]] || corebrum_agents_die "invalid agent id"
  for i in "${!AGENTS_IDS[@]}"; do
    if [[ "${AGENTS_IDS[$i]}" == "$id" ]]; then
      printf '%s\n' "$i"
      return 0
    fi
  done
  corebrum_agents_die "unknown agent ${id}"
}

# Shell command that installs one agent. The setup wizard runs this in its
# own terminal. Super+Space still wraps it with a pause and the MCP setup.
corebrum_agents_install_action() {
  local i="$1" kind install action allow npm_bin node_bin node_dir path_value
  kind="${AGENTS_KINDS[$i]}"
  install="${AGENTS_INSTALLS[$i]}"
  if [[ "$kind" == "npm" ]]; then
    allow="$(corebrum_agents_npm_package "$install")"
    if [[ "${COREBRUM_AGENTS_STUB:-0}" == 1 ]]; then
      printf 'sudo env PATH="$node_dir:$PATH" node npm install -g --allow-scripts=%s %s\n' "$allow" "$install"
      return 0
    fi
    # sudo's default PATH does not include nvm. npm is a script whose shebang
    # is "#!/usr/bin/env node", so sudo npm exits 127 unless node is named here.
    node_bin="$(command -v node || true)"
    npm_bin="$(command -v npm || true)"
    [[ -n "$node_bin" && -x "$node_bin" ]] || corebrum_agents_die "node is not installed"
    [[ -n "$npm_bin" && -x "$npm_bin" ]] || corebrum_agents_die "npm is not installed"
    node_dir="$(dirname "$node_bin")"
    path_value="${node_dir}:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
    action="sudo env PATH=$(printf '%q' "$path_value") $(printf '%q' "$node_bin") $(printf '%q' "$npm_bin") install -g --allow-scripts=$(printf '%q' "$allow") $(printf '%q' "$install")"
    printf '%s\n' "$action"
    return 0
  fi
  printf '%s\n' "$install"
}

corebrum_agents_rows() {
  local i ready
  corebrum_agents_prepare_path
  corebrum_agents_load
  for i in "${!AGENTS_IDS[@]}"; do
    if corebrum_agents_ready "$i"; then
      ready=1
    else
      ready=0
    fi
    printf '%s\t%s\t%s\t%s\n' "${AGENTS_IDS[$i]}" "${AGENTS_LABELS[$i]}" "$ready" "${AGENTS_BINS[$i]}"
  done
}

corebrum_agents_install() {
  local i="$1" action couple_flag
  if [[ "${COREBRUM_AGENTS_STUB:-0}" == 1 && "${AGENTS_KINDS[$i]}" == "npm" ]]; then
    corebrum_agents_install_action "$i"
    if [[ "${COREBRUM_SYNAPSE_READY:-0}" == 1 ]]; then
      corebrum_agents_couple "$(corebrum_agents_mcp_flag "${AGENTS_IDS[$i]}")"
    fi
    return 0
  fi
  action="$(corebrum_agents_install_action "$i")"
  couple_flag="$(corebrum_agents_mcp_flag "${AGENTS_IDS[$i]}")"
  corebrum_agents_terminal "$(cat <<EOF
set +e
export PATH="\$HOME/.local/bin:\$PATH"
${action}
ec=\$?
set -e
printf '\\n'
if [ "\$ec" -eq 0 ]; then
  if [ -x /usr/local/bin/synapse ] && [ -f "\$HOME/.synapse/config.json" ]; then
    /usr/local/bin/synapse mcp setup --${couple_flag} || true
  fi
  printf '%s\\n' "${AGENTS_LABELS[$i]} is installed. Press Super+Space, choose AI Agents, and select it again to launch."
else
  printf 'Install failed (%s).\\n' "\$ec"
fi
read -r -p 'Press Enter to close. '
EOF
)"
}

corebrum_agents_launch() {
  local i="$1" command run
  command="${AGENTS_LAUNCH[$i]}"
  run="$command"
  if [[ "${COREBRUM_AGENTS_STUB:-0}" != 1 ]]; then
    if [[ "${AGENTS_IDS[$i]}" == "cursor" && -x "${HOME}/.local/bin/agent" ]]; then
      run="$(readlink -f "${HOME}/.local/bin/agent")"
    elif [[ -x "${HOME}/.local/bin/${command}" ]]; then
      run="${HOME}/.local/bin/${command}"
    fi
  fi
  if [[ "${COREBRUM_AGENTS_STUB:-0}" == 1 ]]; then
    if [[ "${COREBRUM_SYNAPSE_READY:-0}" == 1 ]]; then
      corebrum_agents_couple "$(corebrum_agents_mcp_flag "${AGENTS_IDS[$i]}")"
    fi
    printf '%s\n' "$run"
    return 0
  fi
  local flag
  flag="$(corebrum_agents_mcp_flag "${AGENTS_IDS[$i]}")"
  if [[ "$flag" == "openclaw" ]]; then
    exec /usr/local/bin/corebrum-terminal bash --login -c "export PATH=\"\$HOME/.local/bin:\$PATH\"; /usr/local/bin/synapse mcp setup --openclaw || true; exec $(printf '%q' "$run")"
  fi
  corebrum_agents_couple "$flag"
  exec /usr/local/bin/corebrum-terminal bash --login -c "export PATH=\"\$HOME/.local/bin:\$PATH\"; exec $(printf '%q' "$run")"
}

corebrum_agents_run() {
  local choice="$1" i
  for i in "${!AGENTS_IDS[@]}"; do
    if [[ "$choice" == "$(corebrum_agents_choice_label "$i")" ]]; then
      if corebrum_agents_ready "$i"; then
        corebrum_agents_launch "$i"
      else
        corebrum_agents_install "$i"
      fi
      return 0
    fi
  done
  corebrum_agents_die "unknown AI Agents menu choice"
}

corebrum_agents_launch_id() {
  local id="$1" i
  [[ "$id" =~ ^[a-z0-9-]+$ ]] || corebrum_agents_die "invalid agent id"
  corebrum_agents_prepare_path
  corebrum_agents_load
  for i in "${!AGENTS_IDS[@]}"; do
    if [[ "${AGENTS_IDS[$i]}" == "$id" ]]; then
      if corebrum_agents_ready "$i"; then
        corebrum_agents_launch "$i"
      else
        corebrum_agents_install "$i"
      fi
      return 0
    fi
  done
  corebrum_agents_die "unknown agent ${id}"
}

corebrum_agents_open() {
  local choice="" i line
  local -a lines=()
  corebrum_agents_prepare_path
  corebrum_agents_load
  for i in "${!AGENTS_IDS[@]}"; do
    line="$(corebrum_agents_choice_label "$i")"
    lines+=("$line")
  done
  if [[ "${COREBRUM_AGENTS_STUB:-0}" == 1 ]]; then
    if [[ -n "${COREBRUM_AGENTS_CHOICE:-}" ]]; then
      corebrum_agents_run "$COREBRUM_AGENTS_CHOICE"
      return 0
    fi
    printf '%s\n' "${lines[@]}"
    return 0
  fi
  choice="$(printf '%s\n' "${lines[@]}" | fuzzel \
    --config /etc/corebrum/fuzzel/fuzzel.ini \
    --dmenu \
    --prompt 'Agents  ' \
    --width 48 \
    --lines 12)" || return 0
  [[ -n "$choice" ]] || return 0
  corebrum_agents_run "$choice"
}

# Reinstall CLIs that are already on PATH, then couple each one when Corebrum Synapse is configured.
corebrum_agents_update_installed() {
  local i action found=0
  corebrum_agents_prepare_path
  corebrum_agents_load
  for i in "${!AGENTS_IDS[@]}"; do
    corebrum_agents_ready "$i" || continue
    found=1
    action="$(corebrum_agents_install_action "$i")"
    if [[ "${COREBRUM_AGENTS_STUB:-0}" == 1 ]]; then
      printf '%s\n' "$action"
    else
      bash -c "$action"
    fi
    corebrum_agents_couple "$(corebrum_agents_mcp_flag "${AGENTS_IDS[$i]}")"
  done
  if [[ "$found" -eq 0 ]]; then
    printf 'No AI agents are installed.\n'
  fi
}

usage() {
  cat <<'EOF'
Usage: corebrum-agents-menu refresh|open|launch ID|labels|rows|command ID|couple ID|update-installed|data-dir
EOF
}

cmd="${1:-}"
case "$cmd" in
  refresh) corebrum_agents_refresh ;;
  open) corebrum_agents_open ;;
  launch) corebrum_agents_launch_id "${2:-}" ;;
  labels) corebrum_agents_labels ;;
  rows)
    corebrum_agents_rows
    ;;
  command)
    corebrum_agents_prepare_path
    corebrum_agents_load
    corebrum_agents_install_action "$(corebrum_agents_find "${2:-}")"
    ;;
  couple)
    corebrum_agents_prepare_path
    corebrum_agents_load
    i="$(corebrum_agents_find "${2:-}")"
    corebrum_agents_couple "$(corebrum_agents_mcp_flag "${AGENTS_IDS[$i]}")"
    ;;
  update-installed) corebrum_agents_update_installed ;;
  data-dir) corebrum_agents_data_dir ;;
  -h | --help | help) usage ;;
  *)
    usage >&2
    exit 1
    ;;
esac
