#!/usr/bin/env bash
# Install and run the Cortex binary from the sibling checkout.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  echo "source scripts/lib/cortex.sh from another script" >&2
  exit 1
fi

# Private repository. A machine needs a GitHub SSH key that can read it.
COREBRUM_CORTEX_URL="${COREBRUM_CORTEX_URL:-git@github.com:Corebrum/corebrum-cortex.git}"

corebrum_cortex_dest() {
  local parent
  if [[ -n "${COREBRUM_CORTEX_ROOT:-}" ]]; then
    printf '%s\n' "$COREBRUM_CORTEX_ROOT"
    return 0
  fi
  parent="$(dirname "$COREBRUM_ROOT")"
  if [[ -d "$parent" && -w "$parent" ]]; then
    printf '%s\n' "${parent}/corebrum-cortex"
    return 0
  fi
  if [[ -n "${HOME:-}" && -d "$HOME" && -w "$HOME" ]]; then
    printf '%s\n' "${HOME}/corebrum-cortex"
    return 0
  fi
  printf '%s\n' "${parent}/corebrum-cortex"
}

corebrum_cortex_prepare() {
  local root parent
  root="$(corebrum_cortex_dest)"
  if [[ -f "${root}/Cargo.toml" ]]; then
    printf '%s\n' "$root"
    return 0
  fi
  if [[ -e "$root" ]]; then
    corebrum_die "Corebrum Cortex path exists but is not a checkout: ${root}"
  fi
  parent="$(dirname "$root")"
  if [[ ! -d "$parent" || ! -w "$parent" ]]; then
    corebrum_die "cannot clone Corebrum Cortex into ${root}"
  fi
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    corebrum_log "dry-run: git clone --depth 1 ${COREBRUM_CORTEX_URL} ${root}"
    printf '%s\n' "$root"
    return 0
  fi
  command -v git >/dev/null 2>&1 || corebrum_die "git is not installed"
  corebrum_log "Cloning Corebrum Cortex into ${root}"
  if ! GIT_TERMINAL_PROMPT=0 git clone --depth 1 "$COREBRUM_CORTEX_URL" "$root"; then
    corebrum_die "could not clone ${COREBRUM_CORTEX_URL}. The repository is private, so this machine needs a GitHub SSH key that can read Corebrum/corebrum-cortex."
  fi
  if [[ ! -f "${root}/Cargo.toml" ]]; then
    corebrum_die "cloned Corebrum Cortex has no Cargo.toml at ${root}"
  fi
  printf '%s\n' "$root"
}

corebrum_cortex_router_url() {
  local file="${COREBRUM_ZENOH_ROUTER_FILE:-/etc/corebrum/zenoh/router}" url
  if [[ -f "$file" ]]; then
    url="$(tr -d '[:space:]' <"$file")"
    if [[ -n "$url" ]]; then
      printf '%s\n' "$url"
      return 0
    fi
  fi
  printf 'tcp://127.0.0.1:7447\n'
}

corebrum_cmd_cortex_install() {
  local root bin
  root="$(corebrum_cortex_prepare)"
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    corebrum_log "dry-run: cargo build --release --manifest-path ${root}/Cargo.toml"
    corebrum_log "dry-run: install ${root}/target/release/cortex /usr/local/bin/cortex"
    return 0
  fi
  command -v cargo >/dev/null 2>&1 || corebrum_die "cargo is not installed. Install Rust, then run corebrum cortex install again."
  corebrum_log "run: cargo build --release --manifest-path ${root}/Cargo.toml"
  cargo build --release --manifest-path "${root}/Cargo.toml"
  bin="${root}/target/release/cortex"
  [[ -x "$bin" ]] || corebrum_die "cargo did not produce ${bin}"
  if [[ "$(id -u)" -eq 0 ]]; then
    install -m 755 "$bin" /usr/local/bin/cortex
  else
    sudo install -m 755 "$bin" /usr/local/bin/cortex
  fi
  corebrum_log "installed /usr/local/bin/cortex"
}

corebrum_cmd_cortex_daemon() {
  local url bin
  url="$(corebrum_cortex_router_url)"
  if [[ -x /usr/local/bin/cortex ]]; then
    bin=/usr/local/bin/cortex
  else
    bin="$(corebrum_cortex_dest)/target/release/cortex"
  fi
  [[ -x "$bin" ]] || corebrum_die "cortex is not installed; run corebrum cortex install"
  exec "$bin" daemon --zenoh-router "$url" "$@"
}

corebrum_cmd_cortex_elect() {
  local file="${1:-}" bin winner host lan
  if [[ -z "$file" ]]; then
    corebrum_die "usage: corebrum cortex elect workers.json"
  fi
  [[ -f "$file" ]] || corebrum_die "worker list is missing: ${file}"
  if [[ -x /usr/local/bin/cortex ]]; then
    bin=/usr/local/bin/cortex
  else
    bin="$(corebrum_cortex_dest)/target/release/cortex"
  fi
  [[ -x "$bin" ]] || corebrum_die "cortex is not installed; run corebrum cortex install"
  winner="$("$bin" supernode elect --file "$file")"
  printf '%s\n' "$winner"
  host="${winner#tcp://}"
  host="${host%%:*}"
  lan="$(hostname -I 2>/dev/null | awk '{ print $1 }')"
  if [[ -z "$lan" ]]; then
    lan="$(python3 - <<'PY'
import socket
print(socket.gethostbyname(socket.gethostname()))
PY
)"
  fi
  if [[ "$host" == "127.0.0.1" || "$host" == "$lan" ]]; then
    zenoh-fleet init --yes --role hub --hub-ip "$host" --out "${HOME:-.}/local-fleet"
  else
    zenoh-fleet init --yes --role member --hub-ip "$host" --out "${HOME:-.}/local-fleet"
  fi
  corebrum_cmd_zenoh_fleet_apply "${HOME:-.}/local-fleet"
}

corebrum_cmd_cortex() {
  local sub="${1:-}"
  if [[ $# -gt 0 ]]; then
    shift
  fi
  case "$sub" in
    install)
      corebrum_cmd_cortex_install
      ;;
    daemon)
      corebrum_cmd_cortex_daemon "$@"
      ;;
    elect)
      corebrum_cmd_cortex_elect "$@"
      ;;
    "" | -h | --help | help)
      cat <<'EOF'
Usage: corebrum cortex install|daemon|elect <workers.json>

  install    Clone Corebrum/corebrum-cortex when it is missing, then install cortex
  daemon     Run cortex daemon against /etc/corebrum/zenoh/router
  elect      Pick a supernode from a worker JSON list and apply zenoh-fleet

Body control stays on synapse. Fleet compute is cortex compute-stats, submit,
status, and results.
EOF
      ;;
    *)
      corebrum_die "unknown cortex command: ${sub}"
      ;;
  esac
}
