#!/usr/bin/env bash
# Phase 4 command helpers. Source this file; do not execute it.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  echo "source scripts/lib/cli.sh from another script" >&2
  exit 1
fi

# shellcheck source=files.sh
source "${COREBRUM_ROOT}/scripts/lib/files.sh"
# shellcheck source=system.sh
source "${COREBRUM_ROOT}/scripts/lib/system.sh"

COREBRUM_COMMAND_PATH="/usr/local/bin/corebrum"
COREBRUM_LAUNCHER_PATH="/usr/local/share/applications/corebrum-grid.desktop"

corebrum_version_string() {
  local version_file="${COREBRUM_ROOT}/VERSION"
  [[ -f "$version_file" ]] || corebrum_die "missing ${version_file}"
  tr -d '[:space:]' <"$version_file"
}

corebrum_pkg_installed() {
  local status
  status="$(dpkg-query -W -f='${Status}' "$1" 2>/dev/null || true)"
  [[ "$status" == "install ok installed" ]]
}

corebrum_install_command() {
  local src="${COREBRUM_ROOT}/scripts/corebrum.sh"
  local current=""
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    corebrum_log "dry-run: link ${COREBRUM_COMMAND_PATH} to ${src}"
    return 0
  fi
  [[ -f "$src" ]] || corebrum_die "missing ${src}"
  if [[ -L "$COREBRUM_COMMAND_PATH" ]] && current="$(readlink -f "$COREBRUM_COMMAND_PATH")" && [[ "$current" == "$(readlink -f "$src")" ]]; then
    corebrum_log "unchanged: ${COREBRUM_COMMAND_PATH}"
    return 0
  fi
  mkdir -p "$(dirname "$COREBRUM_COMMAND_PATH")"
  if [[ -e "$COREBRUM_COMMAND_PATH" && ! -L "$COREBRUM_COMMAND_PATH" ]]; then
    corebrum_backup_file "$COREBRUM_COMMAND_PATH"
    rm -f "$COREBRUM_COMMAND_PATH"
  fi
  ln -sfn "$src" "$COREBRUM_COMMAND_PATH"
  corebrum_log "installed ${COREBRUM_COMMAND_PATH}"
}

corebrum_cmd_version() {
  printf 'corebrum %s\n' "$(corebrum_version_string)"
}

corebrum_profile_line() {
  local name="$1"
  local installed="$2"
  if [[ "$installed" -eq 1 ]]; then
    printf 'profile %s: installed\n' "$name"
  else
    printf 'profile %s: not installed\n' "$name"
  fi
}

corebrum_cmd_status() {
  local base=0 desktop=0 services=0 ros=0
  corebrum_cmd_version
  printf 'checkout: %s\n' "$COREBRUM_ROOT"
  if corebrum_pkg_installed ca-certificates && corebrum_pkg_installed systemd-timesyncd; then
    base=1
  fi
  if corebrum_pkg_installed hyprland && [[ -f /etc/corebrum/hypr/hyprland.conf ]]; then
    desktop=1
  fi
  if corebrum_pkg_installed network-manager && [[ -f /etc/xdg/xdg-desktop-portal/hyprland-portals.conf ]]; then
    services=1
  fi
  if { corebrum_pkg_installed ros-jazzy-ros-base || corebrum_pkg_installed ros-lyrical-ros-base; } && [[ -f /etc/corebrum/ros/rmw ]]; then
    ros=1
  fi
  corebrum_profile_line base "$base"
  corebrum_profile_line desktop "$desktop"
  corebrum_profile_line services "$services"
  corebrum_profile_line ros "$ros"
  if corebrum_realsense_installed; then
    printf 'realsense: installed\n'
  else
    printf 'realsense: not installed\n'
  fi
  if corebrum_agenticros_installed; then
    printf 'agenticros: installed\n'
  else
    printf 'agenticros: not installed\n'
  fi
  if [[ -x /usr/local/bin/corebrum-skills-approve ]]; then
    printf 'skills helper: installed\n'
  else
    printf 'skills helper: not installed\n'
  fi
  corebrum_speech_status_line
  corebrum_stt_status_line
  if [[ -L /var/log/corebrum/install-latest.log || -f /var/log/corebrum/install-latest.log ]]; then
    printf 'log: /var/log/corebrum/install-latest.log\n'
  else
    printf 'log: none\n'
  fi
}

corebrum_cmd_config() {
  local path
  corebrum_cmd_version
  printf 'checkout: %s\n' "$COREBRUM_ROOT"
  printf 'system config: /etc/corebrum\n'
  printf 'logs: /var/log/corebrum\n'
  printf 'backups: /var/log/corebrum/backups\n'
  printf 'command: %s\n' "$COREBRUM_COMMAND_PATH"
  printf 'grid: /etc/corebrum/dashboard/tiles.conf\n'
  printf 'launcher: /etc/corebrum/fuzzel/fuzzel.ini\n'
  printf 'menu: %s\n' "$COREBRUM_LAUNCHER_PATH"
  printf 'ros: /etc/corebrum/ros\n'
  printf 'zenoh router: corebrum-zenoh-router.service\n'
  printf 'user home: not written\n'
  printf 'netplan: existing files are not edited\n'
  if [[ -d /etc/corebrum ]]; then
    printf 'files:\n'
    while IFS= read -r path; do
      printf '  %s\n' "$path"
    done < <(find /etc/corebrum -type f | sort)
  fi
}

corebrum_state_duplicates() {
  local state="/etc/corebrum/desktop.state"
  [[ -f "$state" ]] || return 0
  awk -F= 'NF && $1 !~ /^#/ { print $1 }' "$state" | sort | uniq -d
}

corebrum_run_check() {
  local name="$1"
  local script="$2"
  local next="$3"
  corebrum_log "doctor: ${name}"
  if bash "$script"; then
    return 0
  fi
  corebrum_log "doctor: ${name} failed"
  corebrum_log "next: ${next}"
  return 1
}

corebrum_cmd_doctor() {
  local failed=0 duplicates
  if ! corebrum_run_check base "${COREBRUM_ROOT}/scripts/validate/base.sh" \
    "sudo corebrum install base"; then
    failed=1
  fi
  if [[ -f /etc/corebrum/hypr/hyprland.conf ]]; then
    if ! corebrum_run_check desktop "${COREBRUM_ROOT}/scripts/validate/desktop.sh" \
      "sudo corebrum install desktop"; then
      failed=1
    fi
  else
    corebrum_log "doctor: desktop is not installed"
    corebrum_log "next: sudo corebrum install desktop"
    failed=1
  fi
  if [[ -f /etc/xdg/xdg-desktop-portal/hyprland-portals.conf ]]; then
    if ! corebrum_run_check services "${COREBRUM_ROOT}/scripts/validate/services.sh" \
      "sudo corebrum install desktop"; then
      failed=1
    fi
  elif [[ -f /etc/corebrum/hypr/hyprland.conf ]]; then
    corebrum_log "doctor: workstation services are not installed"
    corebrum_log "next: sudo corebrum install desktop"
    failed=1
  fi
  if [[ -f /etc/corebrum/ros/rmw ]] || corebrum_pkg_installed ros-jazzy-ros-base || corebrum_pkg_installed ros-lyrical-ros-base; then
    if ! corebrum_run_check ros "${COREBRUM_ROOT}/scripts/validate/ros.sh" \
      "sudo corebrum install ros"; then
      failed=1
    fi
  else
    corebrum_log "doctor: ros is not installed"
    corebrum_log "optional: sudo corebrum install ros"
  fi
  if corebrum_realsense_installed; then
    corebrum_log "doctor: realsense is installed"
  else
    corebrum_log "doctor: realsense is not installed"
    corebrum_log "optional: Super+Space RealSense"
  fi
  if corebrum_agenticros_installed; then
    corebrum_log "doctor: agenticros is installed"
  else
    corebrum_log "doctor: agenticros is not installed"
    corebrum_log "optional: Super+Space AgenticROS"
  fi
  if [[ -x /usr/local/bin/corebrum-skills-approve ]]; then
    corebrum_log "doctor: skills helper is installed"
  else
    corebrum_log "doctor: skills helper is not installed"
    corebrum_log "optional: sudo corebrum install desktop"
  fi
  if corebrum_speech_bin >/dev/null; then
    corebrum_log "doctor: speech uses espeak"
  else
    corebrum_log "doctor: espeak is not installed"
    corebrum_log "optional: sudo corebrum install desktop"
  fi
  if corebrum_stt_ready; then
    corebrum_log "doctor: speech recognition is installed"
  else
    corebrum_log "doctor: speech recognition is not installed"
    corebrum_log "optional: corebrum voice hear --install"
  fi
  duplicates="$(corebrum_state_duplicates || true)"
  if [[ -n "$duplicates" ]]; then
    corebrum_log "doctor: duplicate state keys: ${duplicates}"
    failed=1
  elif [[ -f /etc/corebrum/desktop.state ]]; then
    corebrum_log "ok: state file has no duplicate keys"
  fi
  if [[ -e "${HOME}/.config/hypr/hyprland.conf" ]]; then
    corebrum_log "note: ${HOME}/.config/hypr/hyprland.conf is not managed by Corebrum"
  fi
  corebrum_log "ok: installer does not write ~/.config"
  if [[ -L /var/log/corebrum/install-latest.log || -f /var/log/corebrum/install-latest.log ]]; then
    corebrum_log "log: /var/log/corebrum/install-latest.log"
  fi
  if [[ "$failed" -eq 0 ]]; then
    corebrum_log "doctor: passed"
    return 0
  fi
  corebrum_log "doctor: failed"
  return 1
}

corebrum_cmd_install() {
  local profile="" dry=0 ssh=0
  local -a args=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      base | desktop | ros)
        profile="$1"
        ;;
      headless)
        profile="base"
        corebrum_log "headless profile is the base profile"
        ;;
      --dry-run)
        dry=1
        ;;
      --enable-ssh)
        ssh=1
        ;;
      -h | --help)
        cat <<'EOF'
Usage: corebrum install base|headless|desktop|ros [--dry-run] [--enable-ssh]

  base, headless   Ubuntu Server foundation. headless is the base profile
  desktop          Base, Hyprland session, and workstation services
  ros              Base, ROS 2, and the Zenoh router. Jazzy on noble, Lyrical on resolute. Not the desktop
  --dry-run        Print the plan without changing the system
  --enable-ssh     Optional OpenSSH server

A real install must be run as root. It does not write ~/.config and it does
not edit existing Netplan files.
EOF
        return 0
        ;;
      *)
        corebrum_die "unknown install argument: $1"
        ;;
    esac
    shift
  done
  [[ -n "$profile" ]] || corebrum_die "missing profile (expected: base, headless, desktop, or ros)"
  args=(--profile "$profile")
  if [[ "$dry" -eq 1 ]]; then
    args+=(--dry-run)
  fi
  if [[ "$ssh" -eq 1 ]]; then
    args+=(--enable-ssh)
  fi
  if "${COREBRUM_ROOT}/scripts/install.sh" "${args[@]}"; then
    return 0
  fi
  corebrum_log "install failed"
  if [[ -L /var/log/corebrum/install-latest.log || -f /var/log/corebrum/install-latest.log ]]; then
    corebrum_log "details: /var/log/corebrum/install-latest.log"
  fi
  corebrum_log "next: corebrum doctor"
  return 1
}

corebrum_cmd_uninstall() {
  local profile="" dry=0
  local -a args=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      desktop)
        profile="desktop"
        ;;
      ros)
        profile="ros"
        ;;
      base | headless)
        profile="base"
        ;;
      --dry-run)
        dry=1
        ;;
      -h | --help)
        cat <<'EOF'
Usage: corebrum uninstall desktop|ros [--dry-run]

desktop removes Corebrum desktop files and disables greetd. ros disables the
Zenoh router and removes Corebrum ROS files. Neither command removes apt
packages. corebrum uninstall base refuses, because the base profile is
ordinary Ubuntu packages.
EOF
        return 0
        ;;
      *)
        corebrum_die "unknown uninstall argument: $1"
        ;;
    esac
    shift
  done
  [[ -n "$profile" ]] || corebrum_die "missing profile (expected: desktop or ros)"
  args=(--profile "$profile")
  if [[ "$dry" -eq 1 ]]; then
    args+=(--dry-run)
  fi
  "${COREBRUM_ROOT}/scripts/uninstall.sh" "${args[@]}"
}

corebrum_realsense_installed() {
  corebrum_pkg_installed librealsense2-utils && command -v rs-enumerate-devices >/dev/null 2>&1
}

corebrum_agenticros_installed() {
  [[ -x /usr/local/bin/agenticros && -f "${HOME}/.agenticros/config.json" ]]
}

corebrum_agents_catalog() {
  if [[ -n "${COREBRUM_AGENTS_FILE:-}" ]]; then
    printf '%s\n' "$COREBRUM_AGENTS_FILE"
  elif [[ -f /etc/corebrum/agents.conf ]]; then
    printf '%s\n' /etc/corebrum/agents.conf
  else
    printf '%s\n' "${COREBRUM_ROOT}/manifests/packages/agents.conf"
  fi
}

corebrum_cmd_camera() {
  local sub="${1:-}"
  case "$sub" in
    list)
      if ! corebrum_realsense_installed; then
        printf '%s\n' "RealSense is not installed. Press Super+Space and choose RealSense."
        return 0
      fi
      timeout 15 rs-enumerate-devices
      ;;
    "" | -h | --help | help)
      cat <<'EOF'
Usage: corebrum camera list

  list    Show RealSense devices when the SDK is installed

This command does not install RealSense.
EOF
      [[ -n "$sub" ]] || return 1
      ;;
    *)
      corebrum_die "unknown camera command: ${sub}"
      ;;
  esac
}

corebrum_cmd_agents() {
  local sub="${1:-}" file line binary
  local -a fields=()
  case "$sub" in
    list)
      file="$(corebrum_agents_catalog)"
      [[ -f "$file" ]] || corebrum_die "missing agent list ${file}"
      while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%%#*}"
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"
        [[ -z "$line" ]] && continue
        IFS='^' read -r -a fields <<<"$line"
        [[ "${#fields[@]}" -eq 6 ]] || corebrum_die "invalid agent line: ${line}"
        binary="${fields[2]}"
        if command -v "$binary" >/dev/null 2>&1; then
          printf '%s: installed\n' "$binary"
        else
          printf '%s: not installed\n' "$binary"
        fi
      done <"$file"
      ;;
    "" | -h | --help | help)
      cat <<'EOF'
Usage: corebrum agents list

  list    Show which AI agent CLIs from the catalog are on PATH

This command does not install an agent.
EOF
      [[ -n "$sub" ]] || return 1
      ;;
    *)
      corebrum_die "unknown agents command: ${sub}"
      ;;
  esac
}

corebrum_cmd_update() {
  local sub="${1:-}"
  case "$sub" in
    status)
      cat <<'EOF'
Updates stay in Super+Space. This command does not upgrade anything.

  Ubuntu
  Corebrum
  ROS 2
  Zenoh
  AgenticROS
  AI Agents
EOF
      ;;
    "" | -h | --help | help)
      cat <<'EOF'
Usage: corebrum update status

  status    List the Super+Space Updates rows

This command does not run apt or git.
EOF
      [[ -n "$sub" ]] || return 1
      ;;
    *)
      corebrum_die "corebrum update ${sub} is not available. Super+Space Updates runs that step."
      ;;
  esac
}

corebrum_speech_conf() {
  printf '%s/corebrum/speech.conf\n' "${XDG_STATE_HOME:-${HOME}/.local/state}"
}

corebrum_speech_get() {
  local key="$1" fallback="$2" file line
  file="$(corebrum_speech_conf)"
  if [[ -f "$file" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
      case "$line" in
        "${key}="*)
          printf '%s\n' "${line#*=}"
          return 0
          ;;
      esac
    done <"$file"
  fi
  printf '%s\n' "$fallback"
}

corebrum_speech_set() {
  local key="$1" value="$2" file dir tmp
  file="$(corebrum_speech_conf)"
  dir="$(dirname "$file")"
  mkdir -p "$dir"
  tmp="$(mktemp "${dir}/speech.conf.XXXXXX")"
  if [[ -f "$file" ]]; then
    grep -v -e "^${key}=" "$file" >"$tmp" || true
  fi
  printf '%s=%s\n' "$key" "$value" >>"$tmp"
  mv "$tmp" "$file"
}

corebrum_speech_bin() {
  if [[ -n "${COREBRUM_SPEECH_BIN:-}" ]]; then
    if [[ -x "$COREBRUM_SPEECH_BIN" ]]; then
      printf '%s\n' "$COREBRUM_SPEECH_BIN"
      return 0
    fi
    return 1
  fi
  if command -v espeak-ng >/dev/null 2>&1; then
    command -v espeak-ng
    return 0
  fi
  if command -v espeak >/dev/null 2>&1; then
    command -v espeak
    return 0
  fi
  return 1
}

corebrum_speech_pidfile() {
  printf '%s/corebrum-speech-%s.pid\n' "${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}" "$(id -u)"
}

corebrum_speech_stop() {
  local pidfile pid
  pidfile="$(corebrum_speech_pidfile)"
  [[ -f "$pidfile" ]] || return 0
  pid="$(<"$pidfile")"
  rm -f "$pidfile"
  if [[ "$pid" =~ ^[0-9]+$ ]]; then
    kill "$pid" 2>/dev/null || true
  fi
}

corebrum_speech_status_line() {
  local enabled
  if ! corebrum_speech_bin >/dev/null; then
    printf 'speech: not installed\n'
    return 0
  fi
  enabled="$(corebrum_speech_get enabled 1)"
  if [[ "$enabled" == "0" ]]; then
    printf 'speech: disabled\n'
    return 0
  fi
  printf 'speech: espeak\n'
}

corebrum_stt_model_dir() {
  printf '%s\n' "${COREBRUM_STT_MODEL_DIR:-/usr/share/pocketsphinx/model/en-us}"
}

corebrum_stt_bin() {
  if [[ -n "${COREBRUM_STT_BIN:-}" && -x "${COREBRUM_STT_BIN}" ]]; then
    printf '%s\n' "$COREBRUM_STT_BIN"
    return 0
  fi
  if command -v pocketsphinx >/dev/null 2>&1; then
    command -v pocketsphinx
    return 0
  fi
  if command -v pocketsphinx_continuous >/dev/null 2>&1; then
    command -v pocketsphinx_continuous
    return 0
  fi
  return 1
}

corebrum_stt_ready() {
  local bin
  bin="$(corebrum_stt_bin)" || return 1
  if [[ -n "${COREBRUM_STT_BIN:-}" ]]; then
    return 0
  fi
  [[ -d "$(corebrum_stt_model_dir)/en-us" ]]
}

corebrum_stt_status_line() {
  if corebrum_stt_ready; then
    printf 'speech recognition: installed\n'
  else
    printf 'speech recognition: not installed\n'
  fi
}

corebrum_record_bin() {
  if [[ -n "${COREBRUM_RECORD_BIN:-}" && -x "${COREBRUM_RECORD_BIN}" ]]; then
    printf '%s\n' "$COREBRUM_RECORD_BIN"
    return 0
  fi
  command -v pw-record
}

corebrum_apt_candidate() {
  local policy
  policy="$(apt-cache policy "$1" 2>/dev/null || true)"
  awk '/Candidate:/ { print $2; exit }' <<<"$policy"
}

corebrum_stt_install() {
  local candidate model
  candidate="$(corebrum_apt_candidate pocketsphinx)"
  model="$(corebrum_apt_candidate pocketsphinx-en-us)"
  if [[ -z "$candidate" || "$candidate" == "(none)" || -z "$model" || "$model" == "(none)" ]]; then
    corebrum_die "pocketsphinx is not in the Ubuntu archive on this release."
  fi
  if [[ "$(id -u)" -eq 0 ]]; then
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends pocketsphinx pocketsphinx-en-us
  else
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends pocketsphinx pocketsphinx-en-us
  fi
  hash -r
  if ! corebrum_stt_bin >/dev/null; then
    corebrum_die "pocketsphinx installed but the recognizer is not on PATH"
  fi
  corebrum_stt_ready || corebrum_die "pocketsphinx-en-us is not installed"
}

corebrum_stt_text() {
  local bin="$1" wav="$2" name json text hmm lm dict
  hmm="$(corebrum_stt_model_dir)/en-us"
  lm="$(corebrum_stt_model_dir)/en-us.lm.bin"
  dict="$(corebrum_stt_model_dir)/cmudict-en-us.dict"
  name="$(basename "$bin")"
  if [[ "$name" == "pocketsphinx_continuous" ]]; then
    text="$("$bin" -infile "$wav" -hmm "$hmm" -lm "$lm" -dict "$dict" -logfn /dev/null)" \
      || return 1
    text="$(printf '%s\n' "$text" | awk 'NF { line=$0 } END { print line }')"
    text="${text//<s>/}"
    text="${text//<\/s>/}"
    printf '%s' "$text" | awk '{$1=$1; print}'
    return 0
  fi
  json="$("$bin" -hmm "$hmm" -lm "$lm" -dict "$dict" single "$wav")" \
    || return 1
  printf '%s\n' "$json" | python3 -c 'import json,sys
raw=sys.stdin.read().strip()
try:
    obj=json.loads(raw)
except json.JSONDecodeError:
    sys.exit(2)
sys.stdout.write((obj.get("t") or "").strip())'
}

corebrum_cmd_voice_hear() {
  local install=0 seconds=5 rec wav bytes text bin
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --install)
        install=1
        ;;
      *)
        if [[ "$1" =~ ^[0-9]+$ ]]; then
          seconds="$1"
        else
          corebrum_die "usage: corebrum voice hear [--install] [seconds]"
        fi
        ;;
    esac
    shift
  done
  if [[ "$seconds" -lt 1 || "$seconds" -gt 30 ]]; then
    corebrum_die "record between 1 and 30 seconds"
  fi
  if ! corebrum_stt_ready; then
    if [[ "$install" -eq 1 ]]; then
      corebrum_stt_install
    else
      corebrum_die "Speech recognition is not installed. corebrum speak still works. Install it with: corebrum voice hear --install"
    fi
  fi
  rec="$(corebrum_record_bin)" || corebrum_die "pw-record is not installed. sudo corebrum install desktop"
  wav="$(mktemp "${TMPDIR:-/tmp}/corebrum-hear.XXXXXX.wav")"
  "$rec" --rate 16000 --channels 1 --format s16 -n "$((seconds * 16000))" "$wav" >/dev/null 2>&1 || true
  bytes=0
  if [[ -f "$wav" ]]; then
    bytes="$(wc -c <"$wav")"
  fi
  if [[ "$bytes" -le 44 ]]; then
    rm -f "$wav"
    corebrum_die "could not record the default microphone"
  fi
  bin="$(corebrum_stt_bin)"
  if ! text="$(corebrum_stt_text "$bin" "$wav")"; then
    rm -f "$wav"
    corebrum_die "speech recognition failed"
  fi
  rm -f "$wav"
  if [[ -z "$text" ]]; then
    corebrum_die "no speech recognized"
  fi
  printf '%s\n' "$text"
}

corebrum_speak_now() {
  local text="$1" enabled bin voice pidfile pid
  local -a args=()
  enabled="$(corebrum_speech_get enabled 1)"
  if [[ "$enabled" == "0" ]]; then
    printf '%s\n' "speech is disabled"
    return 0
  fi
  bin="$(corebrum_speech_bin)" || corebrum_die "espeak-ng is not installed. sudo corebrum install desktop"
  voice="$(corebrum_speech_get voice "")"
  if [[ -n "$voice" ]]; then
    args+=(-v "$voice")
  fi
  corebrum_speech_stop
  pidfile="$(corebrum_speech_pidfile)"
  "$bin" "${args[@]}" -- "$text" &
  pid=$!
  printf '%s\n' "$pid" >"$pidfile"
  if ! wait "$pid"; then
    if [[ ! -f "$pidfile" ]] || [[ "$(<"$pidfile")" != "$pid" ]]; then
      return 0
    fi
    rm -f "$pidfile"
    corebrum_die "speech failed"
  fi
  if [[ -f "$pidfile" ]] && [[ "$(<"$pidfile")" == "$pid" ]]; then
    rm -f "$pidfile"
  fi
}

corebrum_cmd_speak() {
  local once=0 setup text
  if [[ "${1:-}" == "--" ]]; then
    shift
    [[ $# -gt 0 ]] || corebrum_die "usage: corebrum speak \"text\""
    corebrum_speak_now "$*"
    return 0
  fi
  case "${1:-}" in
    "" | -h | --help | help)
      cat <<'EOF'
Usage: corebrum speak "text"
       corebrum speak listen [--once]

  speak "text"     Say the text with espeak-ng
  speak listen     Say each std_msgs/String on /corebrum/say

listen reads ROS 2. It does not call a cloud speech API.
corebrum voice disable stops speech on a headless machine.
EOF
      [[ -n "${1:-}" ]] || return 1
      ;;
    listen)
      shift
      while [[ $# -gt 0 ]]; do
        case "$1" in
          --once)
            once=1
            ;;
          *)
            corebrum_die "unknown speak listen option: ${1}"
            ;;
        esac
        shift
      done
      if [[ -n "${COREBRUM_ROS_SETUP:-}" ]]; then
        setup="$COREBRUM_ROS_SETUP"
      else
        setup="$(corebrum_ros_setup_file || true)"
      fi
      if [[ -z "$setup" || ! -f "$setup" ]]; then
        corebrum_die "ROS 2 is not installed"
      fi
      set +u
      # shellcheck disable=SC1090
      source "$setup"
      set -u
      if [[ -n "${COREBRUM_RMW_IMPLEMENTATION:-}" ]]; then
        export RMW_IMPLEMENTATION="$COREBRUM_RMW_IMPLEMENTATION"
      elif [[ -f /etc/corebrum/ros/rmw ]]; then
        RMW_IMPLEMENTATION="$(tr -d '[:space:]' < /etc/corebrum/ros/rmw)"
        export RMW_IMPLEMENTATION
      else
        export RMW_IMPLEMENTATION=rmw_zenoh_cpp
      fi
      export ROS_DOMAIN_ID="${ROS_DOMAIN_ID:-0}"
      command -v ros2 >/dev/null 2>&1 || corebrum_die "ROS 2 is not installed"
      while true; do
        text="$(ros2 topic echo /corebrum/say std_msgs/msg/String --once --field data --no-daemon)" \
          || corebrum_die "could not read /corebrum/say"
        text="$(printf '%s\n' "$text" | grep -v -e '^---$' || true)"
        text="${text%"${text##*[![:space:]]}"}"
        if [[ "$text" == \'*\' || "$text" == \"*\" ]]; then
          text="${text:1:${#text}-2}"
        fi
        if [[ -n "$text" ]]; then
          corebrum_speak_now "$text"
        fi
        [[ "$once" -eq 1 ]] && break
      done
      ;;
    *)
      corebrum_speak_now "$*"
      ;;
  esac
}

corebrum_cmd_voice() {
  local sub="${1:-}" bin
  case "$sub" in
    list)
      bin="$(corebrum_speech_bin)" || corebrum_die "espeak-ng is not installed. sudo corebrum install desktop"
      "$bin" --voices
      ;;
    test)
      corebrum_speak_now "Hello from Corebrum."
      ;;
    hear)
      shift
      corebrum_cmd_voice_hear "$@"
      ;;
    enable)
      corebrum_speech_set enabled 1
      printf 'speech: enabled\n'
      ;;
    disable)
      corebrum_speech_stop
      corebrum_speech_set enabled 0
      printf 'speech: disabled\n'
      ;;
    set)
      shift
      case "${1:-}" in
        espeak)
          corebrum_speech_set engine espeak
          if [[ -n "${2:-}" ]]; then
            corebrum_speech_set voice "$2"
            printf 'speech engine: espeak\nvoice: %s\n' "$2"
          else
            printf 'speech engine: espeak\n'
          fi
          ;;
        "")
          corebrum_die "usage: corebrum voice set espeak [voice]"
          ;;
        *)
          corebrum_die "corebrum voice set ${1} is not available. Local speech uses espeak."
          ;;
      esac
      ;;
    "" | -h | --help | help)
      cat <<'EOF'
Usage: corebrum voice list|test|set|enable|disable|hear

  list              List espeak-ng voices
  test              Say "Hello from Corebrum."
  set espeak        Use espeak-ng
  set espeak <name> Use one voice from voice list
  enable            Turn local speech on
  disable           Turn local speech off
  hear [seconds]    Transcribe the default microphone
  hear --install    Install Ubuntu pocketsphinx, then transcribe

hear records up to 30 seconds. The desktop profile does not install it.
These commands do not call a cloud speech API.
EOF
      [[ -n "$sub" ]] || return 1
      ;;
    *)
      corebrum_die "unknown voice command: ${sub}"
      ;;
  esac
}
