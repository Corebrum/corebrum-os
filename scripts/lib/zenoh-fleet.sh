#!/usr/bin/env bash
# Apply a zenoh-fleet directory to this Corebrum machine.
# Hub keeps rmw_zenohd. A member stops it and points ROS and Cortex at the hub.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  echo "source scripts/lib/zenoh-fleet.sh from another script" >&2
  exit 1
fi

corebrum_zenoh_etc_root() {
  printf '%s\n' "${COREBRUM_ZENOH_ETC:-/etc}"
}

corebrum_zenoh_systemctl() {
  if [[ -n "${COREBRUM_ZENOH_SYSTEMCTL:-}" ]]; then
    printf 'systemctl'
    printf ' %s' "$@"
    printf '\n'
    return 0
  fi
  systemctl "$@"
}

corebrum_zenoh_tcp_url() {
  local raw="$1"
  raw="${raw#tcp/}"
  raw="${raw#tcp://}"
  printf 'tcp://%s\n' "$raw"
}

corebrum_zenoh_fleet_fields() {
  local fleet="$1"
  python3 - "$fleet" <<'PY'
import json, sys
doc = json.load(open(sys.argv[1], encoding="utf-8"))
endpoints = doc.get("hubEndpoints") or []
print(doc.get("role") or "")
print(endpoints[0] if endpoints else "")
PY
}

corebrum_zenoh_write_router() {
  local url="$1" root dest work
  root="$(corebrum_zenoh_etc_root)"
  dest="${root}/corebrum/zenoh/router"
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    printf 'dry-run: write %s %s\n' "$dest" "$url"
    return 0
  fi
  mkdir -p "${root}/corebrum/zenoh"
  work="$(mktemp)"
  printf '%s\n' "$url" >"$work"
  if [[ "$root" == /etc ]]; then
    corebrum_install_file "$work" "$dest" 644
  else
    mkdir -p "$(dirname "$dest")"
    cp "$work" "$dest"
  fi
  rm -f "$work"
}

corebrum_zenoh_write_session_profile() {
  local root="$1" session="$2" profile work
  profile="${root}/profile.d/corebrum-zenoh-session.sh"
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    printf 'dry-run: write %s\n' "$profile"
    return 0
  fi
  mkdir -p "${root}/profile.d"
  work="$(mktemp)"
  cat >"$work" <<EOF
# shellcheck shell=sh
# Managed by Corebrum OS. Members export the zenoh-fleet client session.
if [ -f ${session} ]; then
  export ZENOH_SESSION_CONFIG_URI=${session}
fi
EOF
  if [[ "$root" == /etc ]]; then
    corebrum_install_file "$work" "$profile" 644
  else
    cp "$work" "$profile"
  fi
  rm -f "$work"
}

corebrum_zenoh_clear_member_session() {
  local root session profile
  root="$(corebrum_zenoh_etc_root)"
  session="${root}/corebrum/zenoh/rmw-session.json5"
  profile="${root}/profile.d/corebrum-zenoh-session.sh"
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    printf 'dry-run: remove member session %s\n' "$session"
    return 0
  fi
  rm -f "$session" "$profile"
}

corebrum_cmd_zenoh_fleet_apply() {
  local dir="${1:-}" fleet role endpoint url root session
  if [[ -z "$dir" ]]; then
    dir="${HOME:-.}/local-fleet"
  fi
  fleet="${dir}/fleet.json"
  [[ -f "$fleet" ]] || corebrum_die "fleet.json is missing in ${dir}"
  if [[ "${DRY_RUN:-0}" != 1 && "$(id -u)" -ne 0 && -z "${COREBRUM_ZENOH_ETC:-}" ]]; then
    corebrum_die "applying a Zenoh fleet requires root"
  fi
  role="$(corebrum_zenoh_fleet_fields "$fleet" | sed -n '1p')"
  endpoint="$(corebrum_zenoh_fleet_fields "$fleet" | sed -n '2p')"
  if [[ -z "$role" ]]; then
    if [[ -f "${dir}/rmw-zenoh-session.json5" ]]; then
      role=member
    else
      role=hub
    fi
  fi
  root="$(corebrum_zenoh_etc_root)"
  case "$role" in
    hub)
      corebrum_zenoh_write_router "tcp://127.0.0.1:7447"
      corebrum_zenoh_clear_member_session
      if [[ -f "${root}/systemd/system/corebrum-zenoh-router.service" || -f /etc/systemd/system/corebrum-zenoh-router.service || -n "${COREBRUM_ZENOH_SYSTEMCTL:-}" ]]; then
        corebrum_zenoh_systemctl enable --now corebrum-zenoh-router.service
      fi
      printf 'hub router: tcp://127.0.0.1:7447\n'
      printf 'cortex daemon --zenoh-router tcp://127.0.0.1:7447\n'
      ;;
    member)
      [[ -n "$endpoint" ]] || corebrum_die "member fleet.json has no hub endpoint"
      [[ -f "${dir}/rmw-zenoh-session.json5" ]] || corebrum_die "member fleet is missing rmw-zenoh-session.json5"
      url="$(corebrum_zenoh_tcp_url "$endpoint")"
      session="${root}/corebrum/zenoh/rmw-session.json5"
      if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
        printf 'dry-run: install %s\n' "$session"
      else
        mkdir -p "${root}/corebrum/zenoh"
        if [[ "$root" == /etc ]]; then
          corebrum_install_file "${dir}/rmw-zenoh-session.json5" "$session" 644
        else
          cp "${dir}/rmw-zenoh-session.json5" "$session"
        fi
      fi
      corebrum_zenoh_write_session_profile "$root" "$session"
      corebrum_zenoh_write_router "$url"
      corebrum_zenoh_systemctl disable --now corebrum-zenoh-router.service || true
      printf 'member router: %s\n' "$url"
      printf 'cortex daemon --zenoh-router %s\n' "$url"
      ;;
    *)
      corebrum_die "unknown fleet role: ${role}"
      ;;
  esac
}
