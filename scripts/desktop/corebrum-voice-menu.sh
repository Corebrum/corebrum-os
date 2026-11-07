#!/usr/bin/env bash
# Super+Space Setup → Voice. Test speech, pick a mic, hear, install recognition.
set -euo pipefail

if [[ -z "${HOME:-}" ]]; then
  HOME="$(getent passwd "$(id -u)" | cut -d: -f6)"
  export HOME
fi

corebrum_voice_die() {
  printf 'corebrum-voice-menu: %s\n' "$1" >&2
  exit 1
}

corebrum_voice_data_dir() {
  local root="${XDG_RUNTIME_DIR:-/tmp/corebrum-launcher-${UID}}"
  printf '%s\n' "${root}/corebrum"
}

corebrum_voice_corebrum() {
  if [[ -n "${COREBRUM_VOICE_BIN:-}" && -x "${COREBRUM_VOICE_BIN}" ]]; then
    printf '%s\n' "$COREBRUM_VOICE_BIN"
    return 0
  fi
  if [[ -x /usr/local/bin/corebrum ]]; then
    printf '%s\n' /usr/local/bin/corebrum
    return 0
  fi
  command -v corebrum
}

corebrum_voice_refresh() {
  local dir
  dir="$(corebrum_voice_data_dir)/applications"
  mkdir -p "$dir"
  cat >"${dir}/corebrum-voice.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Voice
GenericName=Voice
Comment=Speech, microphone, and transcription
Keywords=voice;speech;microphone;mic;transcribe;espeak;pocketsphinx;
Exec=/usr/local/bin/corebrum-voice-menu open
Icon=audio-input-microphone
Terminal=false
Categories=Settings;AudioVideo;
StartupNotify=false
EOF
}

corebrum_voice_labels() {
  printf '%s\n' \
    "Test speak" \
    "Hear once" \
    "Microphone" \
    "Install recognition" \
    "Enable speech" \
    "Disable speech"
}

corebrum_voice_notify() {
  local title="$1" body="$2"
  if [[ "${COREBRUM_VOICE_STUB:-0}" == 1 ]]; then
    printf '%s: %s\n' "$title" "$body"
    return 0
  fi
  if command -v notify-send >/dev/null 2>&1; then
    notify-send --app-name=Corebrum "$title" "$body" || true
  fi
}

corebrum_voice_terminal() {
  local script="$1"
  if [[ "${COREBRUM_VOICE_STUB:-0}" == 1 ]]; then
    printf '%s\n' "$script"
    return 0
  fi
  exec /usr/local/bin/corebrum-terminal bash --login -c "$script"
}

corebrum_voice_mic_rows() {
  local bin
  bin="$(corebrum_voice_corebrum)" || return 0
  if [[ "${COREBRUM_VOICE_STUB:-0}" == 1 ]]; then
    printf '%s\n' "${COREBRUM_VOICE_MIC_LINES:-default	PipeWire default}"
    return 0
  fi
  # Reuse CLI listing; strip the current: header.
  "$bin" voice mic list 2>/dev/null | awk -F '\t' '
    $0 ~ /^current:/ { next }
    $0 ~ /^No PipeWire/ { next }
    {
      line=$0
      sub(/^\* /, "", line)
      sub(/^  /, "", line)
      if (line ~ /\t/) print line
    }
  '
}

corebrum_voice_current_mic() {
  local bin
  bin="$(corebrum_voice_corebrum)" || return 0
  if [[ "${COREBRUM_VOICE_STUB:-0}" == 1 ]]; then
    printf '%s\n' "${COREBRUM_VOICE_MIC_CURRENT:-default}"
    return 0
  fi
  "$bin" voice mic list 2>/dev/null | awk -F': ' '/^current:/{print $2; exit}'
}

corebrum_voice_pick_mic() {
  local rows choice target desc current current_label prompt bin
  current="$(corebrum_voice_current_mic || true)"
  current="${current:-default}"
  rows="$(corebrum_voice_mic_rows || true)"
  if [[ -z "$rows" ]]; then
    rows=$'default\tPipeWire default'
  else
    rows=$'default\tPipeWire default\n'"$rows"
  fi
  current_label="PipeWire default"
  if [[ "$current" != "default" ]]; then
    current_label="$(printf '%s\n' "$rows" | awk -F '\t' -v c="$current" '$1 == c { print $2; exit }')"
    [[ -z "$current_label" ]] && current_label="$current"
  fi
  prompt="Microphone  [now: ${current_label}]"
  if [[ "${COREBRUM_VOICE_STUB:-0}" == 1 ]]; then
    choice="${COREBRUM_VOICE_MIC_CHOICE:-}"
    if [[ -z "$choice" ]]; then
      printf '%s\n' "$rows" | while IFS=$'\t' read -r row_target row_desc; do
        [[ -n "$row_target" ]] || continue
        if [[ "$row_target" == "$current" ]]; then
          printf '★ %s  (%s)\n' "$row_desc" "$row_target"
        else
          printf '%s  (%s)\n' "$row_desc" "$row_target"
        fi
      done
      return 0
    fi
  else
    choice="$(printf '%s\n' "$rows" | while IFS=$'\t' read -r row_target row_desc; do
      [[ -n "$row_target" ]] || continue
      if [[ "$row_target" == "$current" ]]; then
        printf '★ %s  (%s)\n' "$row_desc" "$row_target"
      else
        printf '%s  (%s)\n' "$row_desc" "$row_target"
      fi
    done | fuzzel \
      --config /etc/corebrum/fuzzel/fuzzel.ini \
      --dmenu \
      --prompt "$prompt" \
      --width 56 \
      --lines 12)" || return 0
  fi
  [[ -n "$choice" ]] || return 0
  choice="${choice#★ }"
  target="$(printf '%s\n' "$choice" | sed -n 's/.*(\([^)]*\))$/\1/p')"
  [[ -n "$target" ]] || return 0
  desc="$(printf '%s\n' "$rows" | awk -F '\t' -v t="$target" '$1 == t { print $2; exit }')"
  [[ -z "$desc" ]] && desc="$target"
  bin="$(corebrum_voice_corebrum)" || corebrum_voice_die "corebrum is not installed"
  if [[ "${COREBRUM_VOICE_STUB:-0}" == 1 ]]; then
    printf 'corebrum voice mic set %s\n' "$target"
    return 0
  fi
  "$bin" voice mic set "$target"
  corebrum_voice_notify "Voice" "Microphone set to ${desc}"
}

corebrum_voice_run() {
  local choice="$1" bin script
  bin="$(corebrum_voice_corebrum)" || corebrum_voice_die "corebrum is not installed"
  case "$choice" in
    "Test speak")
      if [[ "${COREBRUM_VOICE_STUB:-0}" == 1 ]]; then
        printf 'corebrum voice test\n'
        return 0
      fi
      "$bin" voice test
      ;;
    "Hear once")
      script="$(cat <<EOF
set +e
$(printf '%q' "$bin") voice hear 5
ec=\$?
printf '\\n'
if [ "\$ec" -ne 0 ]; then
  printf '%s\\n' "If nothing was heard, pick a microphone under Voice → Microphone."
fi
read -r -p 'Press Enter to close. '
exit "\$ec"
EOF
)"
      corebrum_voice_terminal "$script"
      ;;
    "Microphone")
      corebrum_voice_pick_mic
      ;;
    "Install recognition")
      script="$(cat <<EOF
set +e
$(printf '%q' "$bin") voice hear --install 1
ec=\$?
printf '\\n'
read -r -p 'Press Enter to close. '
exit "\$ec"
EOF
)"
      corebrum_voice_terminal "$script"
      ;;
    "Enable speech")
      if [[ "${COREBRUM_VOICE_STUB:-0}" == 1 ]]; then
        printf 'corebrum voice enable\n'
        return 0
      fi
      "$bin" voice enable
      corebrum_voice_notify "Voice" "Speech enabled"
      ;;
    "Disable speech")
      if [[ "${COREBRUM_VOICE_STUB:-0}" == 1 ]]; then
        printf 'corebrum voice disable\n'
        return 0
      fi
      "$bin" voice disable
      corebrum_voice_notify "Voice" "Speech disabled"
      ;;
    *)
      corebrum_voice_die "unknown Voice menu choice"
      ;;
  esac
}

corebrum_voice_open() {
  local choice
  if [[ "${COREBRUM_VOICE_STUB:-0}" == 1 && -z "${COREBRUM_VOICE_CHOICE:-}" ]]; then
    corebrum_voice_labels
    return 0
  fi
  if [[ "${COREBRUM_VOICE_STUB:-0}" == 1 ]]; then
    choice="$COREBRUM_VOICE_CHOICE"
  else
    choice="$(corebrum_voice_labels | fuzzel \
      --config /etc/corebrum/fuzzel/fuzzel.ini \
      --dmenu \
      --prompt 'Voice  ' \
      --width 40 \
      --lines 8)" || return 0
  fi
  [[ -n "$choice" ]] || return 0
  corebrum_voice_run "$choice"
}

usage() {
  cat <<'EOF'
Usage: corebrum-voice-menu refresh|open|labels|data-dir
EOF
}

cmd="${1:-}"
case "$cmd" in
  refresh) corebrum_voice_refresh ;;
  open) corebrum_voice_open ;;
  labels) corebrum_voice_labels ;;
  data-dir) corebrum_voice_data_dir ;;
  -h | --help | help) usage ;;
  *)
    usage >&2
    exit 1
    ;;
esac
