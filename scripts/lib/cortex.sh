#!/usr/bin/env bash
# Install and run the Cortex binary from the sibling checkout.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  echo "source scripts/lib/cortex.sh from another script" >&2
  exit 1
fi

corebrum_cortex_checkout() {
  local parent candidate
  if [[ -n "${COREBRUM_CORTEX_ROOT:-}" ]]; then
    printf '%s\n' "$COREBRUM_CORTEX_ROOT"
    return 0
  fi
  parent="$(dirname "$COREBRUM_ROOT")"
  candidate="${parent}/corebrum-cortex"
  if [[ -f "${candidate}/Cargo.toml" ]]; then
    printf '%s\n' "$candidate"
    return 0
  fi
  corebrum_die "Corebrum Cortex checkout is missing at ${candidate}"
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
  root="$(corebrum_cortex_checkout)"
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    corebrum_log "dry-run: cargo build --release --manifest-path ${root}/Cargo.toml"
    corebrum_log "dry-run: install ${root}/target/release/cortex /usr/local/bin/cortex"
    return 0
  fi
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
    bin="$(corebrum_cortex_checkout)/target/release/cortex"
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
    bin="$(corebrum_cortex_checkout)/target/release/cortex"
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

  install    Build the sibling corebrum-cortex checkout and install cortex
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
