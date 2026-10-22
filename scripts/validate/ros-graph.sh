#!/usr/bin/env bash
# Exercise topics, a service, and an action through the Corebrum Zenoh router.
# Not part of make check. A real `corebrum install ros` runs this as root.
set -euo pipefail

COREBRUM_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../lib/log.sh
source "${COREBRUM_ROOT}/scripts/lib/log.sh"

WITH="${COREBRUM_ROOT}/scripts/ros/with-ros.sh"
export COREBRUM_RMW_IMPLEMENTATION=rmw_zenoh_cpp
export ROS_DOMAIN_ID=42

if [[ "$(id -u)" -ne 0 ]]; then
  corebrum_die "the ROS graph check restarts the Zenoh router and requires root"
fi
[[ -x "$WITH" ]] || corebrum_die "missing ${WITH}"

dir="$(mktemp -d)"
talker_pid=""
service_pid=""
action_pid=""

stop_pid() {
  local pid="$1"
  [[ -n "$pid" ]] || return 0
  pkill -P "$pid" 2>/dev/null || true
  kill "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
}

cleanup() {
  stop_pid "$talker_pid"
  stop_pid "$service_pid"
  stop_pid "$action_pid"
  talker_pid=""
  service_pid=""
  action_pid=""
  rm -rf "$dir"
}
trap cleanup EXIT

wait_router() {
  local count
  for _ in $(seq 1 30); do
    count="$(pgrep -c -x rmw_zenohd 2>/dev/null || true)"
    if systemctl is-active --quiet corebrum-zenoh-router.service && [[ "${count:-0}" -eq 1 ]]; then
      return 0
    fi
    sleep 0.5
  done
  journalctl -u corebrum-zenoh-router.service -n 30 --no-pager >&2 || true
  corebrum_die "Zenoh router is not active with one rmw_zenohd process"
}

wait_name() {
  local kind="$1" name="$2" listed
  for _ in $(seq 1 20); do
    listed="$("$WITH" timeout 10 ros2 "$kind" list 2>/dev/null || true)"
    if grep -qx "$name" <<<"$listed"; then
      return 0
    fi
    sleep 1
  done
  return 1
}

start_talker() {
  "$WITH" ros2 run demo_nodes_cpp talker >"${dir}/talker.log" 2>&1 &
  talker_pid=$!
}

wait_router
start_talker
if ! wait_name topic /chatter; then
  corebrum_log "talker log:"
  cat "${dir}/talker.log" >&2 || true
  corebrum_die "talker did not advertise /chatter on rmw_zenoh_cpp"
fi
listener="$("$WITH" timeout 20 ros2 run demo_nodes_cpp listener 2>&1 || true)"
if ! grep -q 'I heard' <<<"$listener"; then
  printf '%s\n' "$listener" >&2
  corebrum_die "listener did not hear the talker"
fi
corebrum_log "ok: Zenoh topic /chatter"

"$WITH" ros2 run demo_nodes_cpp add_two_ints_server >"${dir}/service.log" 2>&1 &
service_pid=$!
if ! wait_name service /add_two_ints; then
  cat "${dir}/service.log" >&2 || true
  corebrum_die "add_two_ints service did not appear"
fi
service_out="$("$WITH" timeout 20 ros2 service call /add_two_ints example_interfaces/srv/AddTwoInts '{a: 1, b: 2}' 2>&1 || true)"
if ! grep -Eq 'sum[=:][[:space:]]*3' <<<"$service_out"; then
  printf '%s\n' "$service_out" >&2
  corebrum_die "add_two_ints did not return 3"
fi
corebrum_log "ok: Zenoh service add_two_ints"

"$WITH" ros2 run action_tutorials_cpp fibonacci_action_server >"${dir}/action.log" 2>&1 &
action_pid=$!
if ! wait_name action /fibonacci; then
  cat "${dir}/action.log" >&2 || true
  corebrum_die "fibonacci action did not appear"
fi
action_out="$("$WITH" timeout 40 ros2 action send_goal /fibonacci action_tutorials_interfaces/action/Fibonacci '{order: 5}' 2>&1 || true)"
if ! grep -q 'SUCCEEDED' <<<"$action_out"; then
  printf '%s\n' "$action_out" >&2
  corebrum_die "fibonacci action did not succeed"
fi
corebrum_log "ok: Zenoh action fibonacci"

cleanup
dir="$(mktemp -d)"
corebrum_log "run: systemctl restart corebrum-zenoh-router.service"
systemctl restart corebrum-zenoh-router.service
wait_router
start_talker
if ! wait_name topic /chatter; then
  journalctl -u corebrum-zenoh-router.service -n 30 --no-pager >&2 || true
  cat "${dir}/talker.log" >&2 || true
  corebrum_die "talker did not advertise /chatter after the Zenoh router restarted"
fi
corebrum_log "ok: Zenoh router restart"
