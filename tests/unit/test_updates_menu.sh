#!/usr/bin/env bash
# Super+Space Updates prints each step and skips software that is not installed.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
menu="${ROOT}/scripts/desktop/corebrum-updates-menu.sh"
agents="${ROOT}/scripts/desktop/corebrum-agents-menu.sh"
fleet="${ROOT}/scripts/desktop/corebrum-zenoh-fleet-menu.sh"
catalog="${ROOT}/manifests/packages/agents.conf"
ros_lib="${ROOT}/scripts/lib/ros.sh"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

line_of() {
  local needle="$1" file="$2"
  grep -n -F -- "$needle" "$file" | head -n 1 | cut -d: -f1
}

run_menu() {
  COREBRUM_UPDATES_STUB=1 \
    COREBRUM_UPDATES_AGENTS_MENU="$agents" \
    COREBRUM_UPDATES_FLEET_MENU="$fleet" \
    COREBRUM_AGENTS_FILE="$catalog" \
    COREBRUM_AGENTS_INSTALLED="${COREBRUM_AGENTS_INSTALLED:-}" \
    "$menu" "$@"
}

lib_pin="$(sed -n 's/^COREBRUM_ZENOH_CLI_LIB="\(.*\)"/\1/p' "$ros_lib")"
tool_pin="$(sed -n 's/^COREBRUM_ZENOH_CLI_TOOL="\(.*\)"/\1/p' "$ros_lib")"
[[ -n "$lib_pin" && -n "$tool_pin" ]] || fail "Zenoh client pins are missing from ros.sh"

labels="$(run_menu labels)"
for row in Ubuntu Corebrum "ROS 2" Zenoh AgenticROS "AI Agents" All; do
  printf '%s\n' "$labels" | grep -F -x -- "$row" >/dev/null || fail "missing row ${row}"
done

ubuntu="$(run_menu apply Ubuntu)"
printf '%s\n' "$ubuntu" | grep -F 'apt-get update' >/dev/null || fail "Ubuntu does not update apt"
printf '%s\n' "$ubuntu" | grep -F 'apt-get upgrade -y' >/dev/null || fail "Ubuntu does not upgrade apt"

corebrum="$(run_menu apply Corebrum)"
printf '%s\n' "$corebrum" | grep -F 'git -C checkout pull --ff-only' >/dev/null || fail "Corebrum does not fast-forward"
printf '%s\n' "$corebrum" | grep -F 'sudo corebrum install desktop' >/dev/null || fail "Corebrum does not reinstall the desktop"
printf '%s\n' "$corebrum" | grep -F 'Log out' >/dev/null || fail "Corebrum does not ask for a logout"

set +e
dirty="$(COREBRUM_UPDATES_DIRTY=corebrum run_menu apply All 2>&1)"
dirty_ec=$?
set -e
[[ "$dirty_ec" -ne 0 ]] || fail "a dirty Corebrum checkout continued"
printf '%s\n' "$dirty" | grep -F 'local changes' >/dev/null || fail "a dirty Corebrum checkout did not say why it stopped"
printf '%s\n' "$dirty" | grep -F 'pull --ff-only' >/dev/null && fail "a dirty Corebrum checkout still pulled"
printf '%s\n' "$dirty" | grep -F '== ROS 2 ==' >/dev/null && fail "All continued after a dirty Corebrum checkout"

skipped="$(run_menu apply All)"
printf '%s\n' "$skipped" | grep -F 'ROS 2 is not installed. Skipped.' >/dev/null || fail "missing ROS was not skipped"
printf '%s\n' "$skipped" | grep -F 'Zenoh client stays as it is' >/dev/null || fail "Zenoh client was not skipped"
printf '%s\n' "$skipped" | grep -F 'Zenoh fleet is not installed. Skipped.' >/dev/null || fail "Zenoh fleet was not skipped"
printf '%s\n' "$skipped" | grep -F 'AgenticROS is not installed. Skipped.' >/dev/null || fail "AgenticROS was not skipped"
printf '%s\n' "$skipped" | grep -F 'No AI agents are installed.' >/dev/null || fail "missing agents were not reported"
printf '%s\n' "$skipped" | grep -F "$lib_pin" >/dev/null && fail "Zenoh client was reinstalled without ROS"
printf '%s\n' "$skipped" | grep -F '@agenticros/zenoh-fleet@' >/dev/null && fail "Zenoh fleet was reinstalled when it is absent"
ubuntu_at="$(line_of '== Ubuntu ==' <(printf '%s\n' "$skipped"))"
core_at="$(line_of '== Corebrum ==' <(printf '%s\n' "$skipped"))"
ros_at="$(line_of '== ROS 2 ==' <(printf '%s\n' "$skipped"))"
zenoh_at="$(line_of '== Zenoh ==' <(printf '%s\n' "$skipped"))"
agentic_at="$(line_of '== AgenticROS ==' <(printf '%s\n' "$skipped"))"
agents_at="$(line_of '== AI Agents ==' <(printf '%s\n' "$skipped"))"
[[ "$ubuntu_at" -lt "$core_at" && "$core_at" -lt "$ros_at" && "$ros_at" -lt "$zenoh_at" && "$zenoh_at" -lt "$agentic_at" && "$agentic_at" -lt "$agents_at" ]] \
  || fail "All did not run the six steps in order"

full="$(COREBRUM_UPDATES_ROS=1 COREBRUM_UPDATES_ZENOH_FLEET=1 COREBRUM_UPDATES_AGENTICROS=1 COREBRUM_AGENTS_INSTALLED=claude run_menu apply All)"
printf '%s\n' "$full" | grep -F 'sudo corebrum install ros' >/dev/null || fail "ROS 2 was not reinstalled"
printf '%s\n' "$full" | grep -F -- '--only-upgrade ros-<distro>-*' >/dev/null || fail "installed ROS packages were not upgraded"
printf '%s\n' "$full" | grep -F "$lib_pin" >/dev/null || fail "Zenoh client library pin was not reinstalled"
printf '%s\n' "$full" | grep -F "$tool_pin" >/dev/null || fail "Zenoh client tool pin was not reinstalled"
printf '%s\n' "$full" | grep -F 'scripts/ros/zenoh-cli.sh' >/dev/null || fail "Zenoh client wrapper was not copied"
printf '%s\n' "$full" | grep -F '@agenticros/zenoh-fleet@0.1.4' >/dev/null || fail "installed Zenoh fleet was not reinstalled"
printf '%s\n' "$full" | grep -F 'git -C agenticros fetch --depth 1 origin main' >/dev/null || fail "AgenticROS was not fetched"
printf '%s\n' "$full" | grep -F 'merge --ff-only FETCH_HEAD' >/dev/null || fail "AgenticROS was not fast-forwarded"
printf '%s\n' "$full" | grep -F 'agenticros init --yes' >/dev/null || fail "AgenticROS init did not run"
printf '%s\n' "$full" | grep -F 'https://claude.ai/install.sh' >/dev/null || fail "installed Claude was not updated"
printf '%s\n' "$full" | grep -F 'agenticros mcp setup --claude' >/dev/null || fail "Claude was not coupled to AgenticROS"
printf '%s\n' "$full" | grep -F '@xai-official/grok' >/dev/null && fail "Grok was updated without being installed"

set +e
agentic_dirty="$(COREBRUM_UPDATES_AGENTICROS=1 COREBRUM_UPDATES_DIRTY=agenticros run_menu apply AgenticROS 2>&1)"
agentic_ec=$?
set -e
[[ "$agentic_ec" -ne 0 ]] || fail "a dirty AgenticROS checkout continued"
printf '%s\n' "$agentic_dirty" | grep -F 'fetch --depth 1' >/dev/null && fail "a dirty AgenticROS checkout still fetched"

reboot="$(COREBRUM_UPDATES_REBOOT=1 run_menu apply Ubuntu)"
printf '%s\n' "$reboot" | grep -F 'A reboot is required before the new packages are fully in use.' >/dev/null \
  || fail "the reboot marker was not reported"
grep -F '/var/run/reboot-required' "$menu" >/dev/null || fail "the terminal does not look for reboot-required"

state="$(mktemp -d)"
trap 'rm -rf "$state"' EXIT
first="$(XDG_STATE_HOME="$state" run_menu remind)"
printf '%s\n' "$first" | grep -F 'notify-send Updates' >/dev/null || fail "the first reminder was silent"
printf '%s\n' "$first" | grep -F 'apt-get' >/dev/null && fail "the reminder ran apt"
second="$(XDG_STATE_HOME="$state" run_menu remind)"
[[ -z "$second" ]] || fail "a fresh reminder ran again"
touch -d '8 days ago' "${state}/corebrum/updates-reminded"
third="$(XDG_STATE_HOME="$state" run_menu remind)"
printf '%s\n' "$third" | grep -F 'notify-send Updates' >/dev/null || fail "an old reminder stayed silent"

runtime="$(mktemp -d)"
XDG_RUNTIME_DIR="$runtime" "$menu" refresh
desktop="${runtime}/corebrum/applications/corebrum-updates.desktop"
grep -F 'Name=Updates' "$desktop" >/dev/null || fail "Updates desktop entry is missing"
grep -F 'Keywords=update;upgrade;apt' "$desktop" >/dev/null || fail "typing update cannot find Updates"

grep -F 'corebrum-updates-menu.sh' "${ROOT}/scripts/lib/desktop.sh" >/dev/null || fail "desktop install does not ship Updates"
grep -F '/usr/local/bin/corebrum-updates-menu remind' "${ROOT}/config/hypr/hyprland.conf" >/dev/null \
  || fail "login does not remind about Updates"

printf 'ok: updates-menu\n'
