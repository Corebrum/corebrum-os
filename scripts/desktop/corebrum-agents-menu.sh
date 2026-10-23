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
  if [[ "${COREBRUM_AGENTS_STUB:-0}" == 1 ]]; then
    return 0
  fi
  if [[ -f /etc/profile.d/corebrum-node.sh ]]; then
    set +u
    # shellcheck disable=SC1091
    source /etc/profile.d/corebrum-node.sh || true
    set -u
  fi
  export PATH="${HOME}/.local/bin:${PATH}"
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

# Write AgenticROS into an agent's config. Idempotent. Order of install does not matter.
corebrum_agents_couple() {
  local flag="${1:-}"
  if [[ "${COREBRUM_AGENTS_STUB:-0}" == 1 ]]; then
    if [[ "${COREBRUM_AGENTICROS_READY:-0}" != 1 ]]; then
      return 0
    fi
    if [[ -n "$flag" ]]; then
      printf 'agenticros mcp setup --%s --quiet\n' "$flag"
    else
      printf 'agenticros mcp setup --installed --quiet\n'
    fi
    return 0
  fi
  if [[ ! -x /usr/local/bin/agenticros || ! -f "${HOME}/.agenticros/config.json" ]]; then
    return 0
  fi
  if [[ -n "$flag" ]]; then
    /usr/local/bin/agenticros mcp setup "--${flag}" --quiet || true
  else
    /usr/local/bin/agenticros mcp setup --installed --quiet || true
  fi
}

corebrum_agents_refresh() {
  local dir
  corebrum_agents_couple
  dir="$(corebrum_agents_data_dir)/applications"
  mkdir -p "$dir"
  cat >"${dir}/corebrum-agents.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=AI Agents
GenericName=AI Agents
Comment=Install or launch an AI agent CLI
Exec=/usr/local/bin/corebrum-agents-menu open
Icon=utilities-terminal
Terminal=false
Categories=Development;
StartupNotify=false
EOF
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

corebrum_agents_install() {
  local i="$1" kind install action allow npm_bin node_bin node_dir path_value
  kind="${AGENTS_KINDS[$i]}"
  install="${AGENTS_INSTALLS[$i]}"
  if [[ "$kind" == "npm" ]]; then
    allow="$(corebrum_agents_npm_package "$install")"
    if [[ "${COREBRUM_AGENTS_STUB:-0}" == 1 ]]; then
      printf 'sudo env PATH="$node_dir:$PATH" node npm install -g --allow-scripts=%s %s\n' "$allow" "$install"
      if [[ "${COREBRUM_AGENTICROS_READY:-0}" == 1 ]]; then
        corebrum_agents_couple "$(corebrum_agents_mcp_flag "${AGENTS_IDS[$i]}")"
      fi
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
  else
    action="$install"
  fi
  local couple_flag
  couple_flag="$(corebrum_agents_mcp_flag "${AGENTS_IDS[$i]}")"
  corebrum_agents_terminal "$(cat <<EOF
set +e
export PATH="\$HOME/.local/bin:\$PATH"
${action}
ec=\$?
set -e
printf '\\n'
if [ "\$ec" -eq 0 ]; then
  if [ -x /usr/local/bin/agenticros ] && [ -f "\$HOME/.agenticros/config.json" ]; then
    /usr/local/bin/agenticros mcp setup --${couple_flag} || true
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
    if [[ "${COREBRUM_AGENTICROS_READY:-0}" == 1 ]]; then
      corebrum_agents_couple "$(corebrum_agents_mcp_flag "${AGENTS_IDS[$i]}")"
    fi
    printf '%s\n' "$run"
    return 0
  fi
  local flag
  flag="$(corebrum_agents_mcp_flag "${AGENTS_IDS[$i]}")"
  if [[ "$flag" == "openclaw" ]]; then
    exec /usr/local/bin/corebrum-terminal bash --login -c "export PATH=\"\$HOME/.local/bin:\$PATH\"; /usr/local/bin/agenticros mcp setup --openclaw || true; exec $(printf '%q' "$run")"
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

usage() {
  cat <<'EOF'
Usage: corebrum-agents-menu refresh|open|labels|data-dir
EOF
}

cmd="${1:-}"
case "$cmd" in
  refresh) corebrum_agents_refresh ;;
  open) corebrum_agents_open ;;
  labels) corebrum_agents_labels ;;
  data-dir) corebrum_agents_data_dir ;;
  -h | --help | help) usage ;;
  *)
    usage >&2
    exit 1
    ;;
esac
