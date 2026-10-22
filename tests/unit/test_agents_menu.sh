#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
menu="${ROOT}/scripts/desktop/corebrum-agents-menu.sh"
catalog="${ROOT}/manifests/packages/agents.conf"
launcher="${ROOT}/scripts/desktop/corebrum-launcher.sh"

assert_eq() {
  local got="$1" expected="$2" message="$3"
  if [[ "$got" != "$expected" ]]; then
    printf 'FAIL: %s\n got: %q\n expected: %q\n' "$message" "$got" "$expected" >&2
    exit 1
  fi
}

if ! grep -q '/usr/local/bin/corebrum-agents-menu refresh' "$launcher"; then
  echo "FAIL: Super+Space does not refresh the AI Agents entry" >&2
  exit 1
fi
if grep -q 'x.ai/cli/install.sh' "$catalog"; then
  echo "FAIL: Grok uses the shell installer that replaces Cursor's agent command" >&2
  exit 1
fi
for id in antigravity claude codex cursor grok hermes openclaw; do
  if ! grep -q "^${id}\\^" "$catalog"; then
    echo "FAIL: agent list is missing ${id}" >&2
    exit 1
  fi
done

export COREBRUM_AGENTS_STUB=1
export COREBRUM_AGENTS_FILE="$catalog"
export COREBRUM_AGENTS_INSTALLED="agent"

assert_eq "$("$menu" labels)" "$(printf '%s\n' \
  "Antigravity CLI   install" \
  "Claude Code CLI   install" \
  "Codex CLI   install" \
  "Cursor CLI" \
  "Grok CLI   install" \
  "Hermes CLI   install" \
  "OpenClaw   install")" "only Cursor CLI is installed"

export COREBRUM_AGENTS_CHOICE="Antigravity CLI   install"
got="$("$menu" open)"
if ! grep -q 'https://antigravity.google/cli/install.sh' <<<"$got"; then
  echo "FAIL: Antigravity CLI did not start its installer" >&2
  exit 1
fi
if grep -q 'sudo ' <<<"$got"; then
  echo "FAIL: the Antigravity installer runs with sudo" >&2
  exit 1
fi

export COREBRUM_AGENTS_CHOICE="Grok CLI   install"
got="$("$menu" open)"
assert_eq "$got" 'sudo env PATH="$node_dir:$PATH" node npm install -g --allow-scripts=@xai-official/grok @xai-official/grok' "Grok installs from npm"

export COREBRUM_AGENTS_CHOICE="OpenClaw   install"
got="$("$menu" open)"
assert_eq "$got" 'sudo env PATH="$node_dir:$PATH" node npm install -g --allow-scripts=openclaw openclaw@latest' "OpenClaw installs from npm"

export COREBRUM_AGENTS_CHOICE="Cursor CLI"
assert_eq "$("$menu" open)" "agent" "Cursor CLI launches agent"

runtime="$(mktemp -d)"
export XDG_RUNTIME_DIR="$runtime"
"$menu" refresh
if ! grep -q '^Name=AI Agents$' "${runtime}/corebrum/applications/corebrum-agents.desktop"; then
  echo "FAIL: refreshed desktop entry did not name AI Agents" >&2
  exit 1
fi
if ! grep -q '^Exec=/usr/local/bin/corebrum-agents-menu open$' "${runtime}/corebrum/applications/corebrum-agents.desktop"; then
  echo "FAIL: AI Agents desktop entry does not open the agent menu" >&2
  exit 1
fi
rm -rf "$runtime"

echo "ok: agents-menu"
