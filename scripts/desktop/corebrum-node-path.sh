#!/usr/bin/env bash
# Put the nvm default Node bin directory on PATH without sourcing nvm.sh.
# Source this file; do not execute it.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  echo "source scripts/desktop/corebrum-node-path.sh from another script" >&2
  exit 1
fi

# nvm's alias file holds a name such as "26" or "v26.12.1". Login shells still
# source nvm.sh, so the nvm function stays available in a terminal.
corebrum_node_prepend_path() {
  local nvm_dir="${COREBRUM_NVM_DIR:-/usr/local/nvm}"
  local alias_file="${nvm_dir}/alias/default"
  local name="" dir="" match=""
  local -a matches=()
  [[ -f "$alias_file" ]] || return 0
  name="$(tr -d '[:space:]' <"$alias_file")"
  [[ "$name" =~ ^[A-Za-z0-9._+-]+$ ]] || return 0
  if [[ -x "${nvm_dir}/versions/node/${name}/bin/node" ]]; then
    dir="${nvm_dir}/versions/node/${name}/bin"
  else
    shopt -s nullglob
    matches=("${nvm_dir}/versions/node/v${name}."*/bin/node)
    shopt -u nullglob
    if [[ "${#matches[@]}" -gt 0 ]]; then
      match="$(printf '%s\n' "${matches[@]}" | sort -V | tail -n 1)"
      dir="$(dirname "$match")"
    fi
  fi
  [[ -n "${dir:-}" && -d "$dir" ]] || return 0
  case ":${PATH}:" in
    *":${dir}:"*) return 0 ;;
  esac
  export PATH="${dir}:${PATH}"
}

corebrum_node_prepare_path() {
  corebrum_node_prepend_path
  if [[ -n "${HOME:-}" ]]; then
    case ":${PATH}:" in
      *":${HOME}/.local/bin:"*) ;;
      *) export PATH="${HOME}/.local/bin:${PATH}" ;;
    esac
  fi
}
