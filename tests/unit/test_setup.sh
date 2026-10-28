#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
setup="${ROOT}/scripts/desktop/corebrum-setup.sh"
menu="${ROOT}/scripts/desktop/corebrum-agents-menu.sh"
catalog="${ROOT}/manifests/packages/agents.conf"
conf="${ROOT}/config/sway/config"

assert_eq() {
  local got="$1" expected="$2" message="$3"
  if [[ "$got" != "$expected" ]]; then
    printf 'FAIL: %s\n got: %q\n expected: %q\n' "$message" "$got" "$expected" >&2
    exit 1
  fi
}

if ! grep -qF 'corebrum/setup-done' "$conf"; then
  echo "FAIL: first login does not check the setup marker" >&2
  exit 1
fi
if ! grep -qF '/usr/local/bin/corebrum-setup login' "$conf"; then
  echo "FAIL: first login does not ask the wizard whether to open" >&2
  exit 1
fi
if ! grep -qF '/usr/local/bin/corebrum-terminal --class corebrum-setup /usr/local/bin/corebrum-setup' "$setup"; then
  echo "FAIL: an unfinished setup does not open in a terminal" >&2
  exit 1
fi
if ! grep -qF '/usr/local/bin/corebrum-setup' "${ROOT}/scripts/lib/desktop.sh"; then
  echo "FAIL: the desktop install does not copy the setup wizard" >&2
  exit 1
fi

run_setup() {
  local state="$1"
  shift
  mkdir -p "$state"
  export XDG_STATE_HOME="$state"
  export COREBRUM_SETUP_STUB=1
  export COREBRUM_SETUP_AGENTS_MENU="$menu"
  export COREBRUM_AGENTS_FILE="$catalog"
  export HOME="$state/home"
  export COREBRUM_SETUP_ANSWERS
  if [[ -n "${COREBRUM_SETUP_ROS+x}" ]]; then
    export COREBRUM_SETUP_ROS
  fi
  if [[ -n "${COREBRUM_SETUP_REALSENSE+x}" ]]; then
    export COREBRUM_SETUP_REALSENSE
  fi
  if [[ -n "${COREBRUM_SETUP_AGENTICROS+x}" ]]; then
    export COREBRUM_SETUP_AGENTICROS
  fi
  if [[ -n "${COREBRUM_AGENTS_INSTALLED+x}" ]]; then
    export COREBRUM_AGENTS_INSTALLED
  fi
  "$setup" "$@"
}

line_of() {
  local file="$1" needle="$2"
  grep -nF "$needle" "$file" | head -n 1 | cut -d: -f1
}

state="$(mktemp -d)"
out="$(COREBRUM_SETUP_ANSWERS=$'s\ns\ns\ns\n' run_setup "$state")"
if ! grep -q 'Step 1 of 4' <<<"$out"; then
  echo "FAIL: the wizard did not start at ROS 2" >&2
  exit 1
fi
if ! grep -q 'Step 4 of 4' <<<"$out"; then
  echo "FAIL: skipping did not reach the AI agents step" >&2
  exit 1
fi
if grep -q '^run:' <<<"$out"; then
  echo "FAIL: skip ran an installer" >&2
  printf '%s\n' "$out" >&2
  exit 1
fi
if [[ ! -f "${state}/corebrum/setup-done" ]]; then
  echo "FAIL: finishing the wizard did not remember that choice" >&2
  exit 1
fi

out="$(COREBRUM_SETUP_ANSWERS=$'i\n' run_setup "$state")"
assert_eq "$out" "" "a later login opens the wizard again"

out="$(COREBRUM_SETUP_ANSWERS=$'x\n' run_setup "$state" again)"
if ! grep -q 'Corebrum setup' <<<"$out"; then
  echo "FAIL: corebrum-setup again did not open the wizard" >&2
  exit 1
fi

state="$(mktemp -d)"
out="$(COREBRUM_SETUP_ANSWERS=$'x\n' run_setup "$state")"
if grep -q 'Step 2 of 4' <<<"$out"; then
  echo "FAIL: exit continued past the current step" >&2
  exit 1
fi
if [[ ! -f "${state}/corebrum/setup-done" ]]; then
  echo "FAIL: exit did not remember that choice" >&2
  exit 1
fi

state="$(mktemp -d)"
out="$(COREBRUM_SETUP_ANSWERS=$'s\ni\nr\nx\n' run_setup "$state")"
if ! grep -q 'RealSense needs ROS 2' <<<"$out"; then
  echo "FAIL: RealSense was offered before ROS 2" >&2
  printf '%s\n' "$out" >&2
  exit 1
fi
if grep -q 'realsense-install.sh' <<<"$out"; then
  echo "FAIL: RealSense install ran before ROS 2" >&2
  exit 1
fi
if ! grep -q 'run: sudo corebrum install ros' <<<"$out"; then
  echo "FAIL: the RealSense step did not offer to install ROS 2" >&2
  exit 1
fi

state="$(mktemp -d)"
out="$(COREBRUM_SETUP_ANSWERS=$'i\ni\ns\ns\n' run_setup "$state")"
ros_line="$(line_of <(printf '%s\n' "$out") 'run: sudo corebrum install ros' || true)"
rs_line="$(line_of <(printf '%s\n' "$out") 'run: sudo /usr/local/lib/corebrum/realsense-install.sh' || true)"
if [[ -z "$ros_line" || -z "$rs_line" || "$ros_line" -ge "$rs_line" ]]; then
  echo "FAIL: ROS 2 did not install before RealSense" >&2
  printf '%s\n' "$out" >&2
  exit 1
fi
if grep -q 'agenticros-install.sh' <<<"$out"; then
  echo "FAIL: skipping AgenticROS still built it" >&2
  exit 1
fi

state="$(mktemp -d)"
out="$(COREBRUM_SETUP_ROS=1 COREBRUM_SETUP_ANSWERS=$'i\ns\ns\n' run_setup "$state")"
if ! grep -q 'ROS 2 is already installed.' <<<"$out"; then
  echo "FAIL: an installed ROS 2 was offered again" >&2
  exit 1
fi
if grep -q 'run: sudo corebrum install ros' <<<"$out"; then
  echo "FAIL: an installed ROS 2 was installed again" >&2
  exit 1
fi
if ! grep -q 'realsense-install.sh' <<<"$out"; then
  echo "FAIL: RealSense did not install after ROS 2" >&2
  exit 1
fi

state="$(mktemp -d)"
out="$(COREBRUM_SETUP_ANSWERS=$'i\ns\ni\n2\ns\n' run_setup "$state")"
if ! grep -q 'run: /usr/local/lib/corebrum/agenticros-install.sh' <<<"$out"; then
  echo "FAIL: AgenticROS did not build from the wizard" >&2
  printf '%s\n' "$out" >&2
  exit 1
fi
if ! grep -q 'run: /usr/local/bin/agenticros init --yes' <<<"$out"; then
  echo "FAIL: the wizard did not init AgenticROS" >&2
  exit 1
fi
if ! grep -q 'https://claude.ai/install.sh' <<<"$out"; then
  echo "FAIL: the agent list did not install Claude" >&2
  printf '%s\n' "$out" >&2
  exit 1
fi
if ! grep -q 'agenticros mcp setup --claude' <<<"$out"; then
  echo "FAIL: installing Claude after AgenticROS did not register it" >&2
  exit 1
fi
agent_line="$(line_of <(printf '%s\n' "$out") 'https://claude.ai/install.sh' || true)"
ros_line="$(line_of <(printf '%s\n' "$out") 'run: sudo corebrum install ros' || true)"
if [[ -z "$agent_line" || -z "$ros_line" || "$ros_line" -ge "$agent_line" ]]; then
  echo "FAIL: an agent installed before ROS 2" >&2
  exit 1
fi

installed_agents="$(awk -F'^' 'NF && $1 !~ /^#/ { printf "%s ", $3 }' "$catalog")"
installed_agents="${installed_agents%" "}"

state="$(mktemp -d)"
out="$(COREBRUM_SETUP_ROS=1 COREBRUM_SETUP_REALSENSE=1 COREBRUM_SETUP_AGENTICROS=1 COREBRUM_AGENTS_INSTALLED="$installed_agents" run_setup "$state" login)"
assert_eq "$out" "" "a fully installed machine opens the wizard on login"
if [[ ! -f "${state}/corebrum/setup-done" ]]; then
  echo "FAIL: a fully installed machine did not remember setup" >&2
  exit 1
fi

state="$(mktemp -d)"
out="$(COREBRUM_SETUP_ROS=1 COREBRUM_SETUP_REALSENSE=1 COREBRUM_SETUP_AGENTICROS=1 COREBRUM_AGENTS_INSTALLED="$installed_agents" run_setup "$state")"
assert_eq "$out" "" "a fully installed machine still shows the wizard"
if [[ ! -f "${state}/corebrum/setup-done" ]]; then
  echo "FAIL: a fully installed machine did not remember setup when started directly" >&2
  exit 1
fi

state="$(mktemp -d)"
out="$(COREBRUM_SETUP_ROS=1 COREBRUM_SETUP_REALSENSE=1 COREBRUM_SETUP_AGENTICROS=1 COREBRUM_AGENTS_INSTALLED="$installed_agents" run_setup "$state" again)"
if ! grep -q 'AI agents are already installed.' <<<"$out"; then
  echo "FAIL: again did not see the installed agents" >&2
  printf '%s\n' "$out" >&2
  exit 1
fi

state="$(mktemp -d)"
out="$(COREBRUM_SETUP_ROS=1 COREBRUM_SETUP_REALSENSE=1 COREBRUM_SETUP_AGENTICROS=1 COREBRUM_AGENTS_INSTALLED=claude run_setup "$state" login)"
assert_eq "$out" "open-wizard" "a missing agent stays quiet on login"
if [[ -e "${state}/corebrum/setup-done" ]]; then
  echo "FAIL: a missing agent wrote the setup marker" >&2
  exit 1
fi

rm -rf "$state"
echo "ok: setup"
