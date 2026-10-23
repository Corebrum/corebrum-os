#!/usr/bin/env bash
# Super+Space Ollama entry. Install the official binary, or run a local model.
set -euo pipefail

COREBRUM_OLLAMA_INSTALL_MARK='   install'
COREBRUM_OLLAMA_OTHER='Run another model'

corebrum_ollama_die() {
  printf 'corebrum-ollama-menu: %s\n' "$1" >&2
  exit 1
}

corebrum_ollama_ready() {
  if [[ "${COREBRUM_OLLAMA_STUB:-0}" == 1 ]]; then
    [[ "${COREBRUM_OLLAMA_READY:-0}" == 1 ]]
    return
  fi
  command -v ollama >/dev/null 2>&1
}

corebrum_ollama_entry_name() {
  if corebrum_ollama_ready; then
    printf 'Ollama\n'
  else
    printf 'Ollama%s\n' "$COREBRUM_OLLAMA_INSTALL_MARK"
  fi
}

corebrum_ollama_data_dir() {
  local root="${XDG_RUNTIME_DIR:-/tmp/corebrum-launcher-${UID}}"
  printf '%s\n' "${root}/corebrum"
}

corebrum_ollama_refresh() {
  local dir name
  dir="$(corebrum_ollama_data_dir)/applications"
  name="$(corebrum_ollama_entry_name)"
  mkdir -p "$dir"
  cat >"${dir}/corebrum-ollama.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=${name}
GenericName=${name}
Comment=Local AI models
Keywords=ollama;local;llm
Exec=/usr/local/bin/corebrum-ollama-menu open
Icon=applications-science
Terminal=false
Categories=Utility;
StartupNotify=false
EOF
}

corebrum_ollama_valid_name() {
  local name="$1"
  [[ "$name" =~ ^[A-Za-z0-9][A-Za-z0-9._:/-]{0,127}$ ]] || return 1
  [[ "$name" == *..* ]] && return 1
  return 0
}

corebrum_ollama_models() {
  if [[ "${COREBRUM_OLLAMA_STUB:-0}" == 1 ]]; then
    if [[ -n "${COREBRUM_OLLAMA_MODELS:-}" ]]; then
      printf '%s\n' "$COREBRUM_OLLAMA_MODELS"
    fi
    return 0
  fi
  ollama list 2>/dev/null | awk 'NR > 1 && $1 != "" { print $1 }'
}

corebrum_ollama_labels() {
  corebrum_ollama_models
  printf '%s\n' "$COREBRUM_OLLAMA_OTHER"
}

corebrum_ollama_install_script() {
  cat <<'EOF'
set +e
set -o pipefail
if ! command -v zstd >/dev/null 2>&1; then
  sudo apt-get update && sudo apt-get install -y --no-install-recommends zstd
fi
if ! command -v zstd >/dev/null 2>&1; then
  printf '%s\n' "zstd is required to unpack Ollama."
  read -r -p 'Press Enter to close. '
  exit 1
fi
curl -fsSL https://ollama.com/install.sh | sh
ec=$?
set -e
printf '\n'
if [ "$ec" -eq 0 ]; then
  printf '%s\n' "Ollama is installed. Press Super+Space and choose Ollama to run a model."
else
  printf 'Install failed (%s).\n' "$ec"
fi
read -r -p 'Press Enter to close. '
EOF
}

corebrum_ollama_install() {
  local script
  script="$(corebrum_ollama_install_script)"
  if [[ "${COREBRUM_OLLAMA_STUB:-0}" == 1 ]]; then
    printf '%s\n' "$script"
    return 0
  fi
  exec /usr/local/bin/corebrum-terminal bash -c "$script"
}

corebrum_ollama_run() {
  local name="$1"
  if ! corebrum_ollama_valid_name "$name"; then
    corebrum_ollama_die "model name must be letters, numbers, and . _ : / -"
  fi
  if [[ "${COREBRUM_OLLAMA_STUB:-0}" == 1 ]]; then
    printf 'ollama run %s\n' "$name"
    return 0
  fi
  exec /usr/local/bin/corebrum-terminal -- ollama run "$name"
}

corebrum_ollama_prompt_name() {
  local name=""
  if [[ "${COREBRUM_OLLAMA_STUB:-0}" == 1 ]]; then
    name="${COREBRUM_OLLAMA_MODEL:-}"
  else
    name="$(printf '\n' | fuzzel \
      --config /etc/corebrum/fuzzel/fuzzel.ini \
      --dmenu \
      --prompt 'Model  ' \
      --width 48 \
      --lines 1)" || return 0
  fi
  [[ -n "$name" ]] || return 0
  corebrum_ollama_run "$name"
}

corebrum_ollama_run_choice() {
  local choice="$1"
  if [[ "$choice" == "$COREBRUM_OLLAMA_OTHER" ]]; then
    corebrum_ollama_prompt_name
    return 0
  fi
  corebrum_ollama_run "$choice"
}

corebrum_ollama_open() {
  local choice=""
  if ! corebrum_ollama_ready; then
    corebrum_ollama_install
    return 0
  fi
  if [[ "${COREBRUM_OLLAMA_STUB:-0}" == 1 ]]; then
    if [[ -n "${COREBRUM_OLLAMA_CHOICE:-}" ]]; then
      corebrum_ollama_run_choice "$COREBRUM_OLLAMA_CHOICE"
      return 0
    fi
    corebrum_ollama_labels
    return 0
  fi
  choice="$(corebrum_ollama_labels | fuzzel \
    --config /etc/corebrum/fuzzel/fuzzel.ini \
    --dmenu \
    --prompt 'Ollama  ' \
    --width 48 \
    --lines 12)" || return 0
  [[ -n "$choice" ]] || return 0
  corebrum_ollama_run_choice "$choice"
}

usage() {
  cat <<'EOF'
Usage: corebrum-ollama-menu refresh|open|entry-name|labels|data-dir
EOF
}

cmd="${1:-}"
case "$cmd" in
  refresh) corebrum_ollama_refresh ;;
  open) corebrum_ollama_open ;;
  entry-name) corebrum_ollama_entry_name ;;
  labels) corebrum_ollama_labels ;;
  data-dir) corebrum_ollama_data_dir ;;
  -h | --help | help) usage ;;
  *)
    usage >&2
    exit 1
    ;;
esac
