#!/usr/bin/env bash
# Ollama is its own Super+Space entry and is not part of the desktop package list.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
menu="${ROOT}/scripts/desktop/corebrum-ollama-menu.sh"
launcher="${ROOT}/scripts/desktop/corebrum-launcher.sh"
desktop_lib="${ROOT}/scripts/lib/desktop.sh"
fail=0

assert_grep() {
  local pattern="$1" file="$2" message="$3"
  if ! grep -qE "$pattern" "$file"; then
    echo "FAIL: ${message}" >&2
    fail=1
  fi
}

assert_grep 'corebrum-ollama-menu refresh' "$launcher" "launcher does not refresh Ollama"
assert_grep 'corebrum-ollama-menu.sh' "$desktop_lib" "desktop install does not ship the Ollama menu"
assert_grep 'curl -fsSL https://ollama.com/install.sh \| sh' "$menu" "installer does not use the official script"
assert_grep 'apt-get install -y --no-install-recommends zstd' "$menu" "installer does not install Ubuntu zstd when it is missing"
if grep -qE '^ollama$' "${ROOT}/manifests/packages/desktop.txt"; then
  echo "FAIL: desktop profile preinstalls Ollama" >&2
  fail=1
fi

runtime="$(mktemp -d)"
export XDG_RUNTIME_DIR="$runtime"
export COREBRUM_OLLAMA_STUB=1

name="$(COREBRUM_OLLAMA_READY=0 bash "$menu" entry-name)"
if [[ "$name" != "Ollama   install" ]]; then
  echo "FAIL: missing Ollama is not marked install (got ${name})" >&2
  fail=1
fi
name="$(COREBRUM_OLLAMA_READY=1 bash "$menu" entry-name)"
if [[ "$name" != "Ollama" ]]; then
  echo "FAIL: installed Ollama still shows install (got ${name})" >&2
  fail=1
fi

COREBRUM_OLLAMA_READY=0 bash "$menu" refresh
desktop="${runtime}/corebrum/applications/corebrum-ollama.desktop"
if ! grep -q '^Name=Ollama   install$' "$desktop"; then
  echo "FAIL: desktop entry name is not the install row" >&2
  fail=1
fi
if ! grep -q '^Exec=/usr/local/bin/corebrum-ollama-menu open$' "$desktop"; then
  echo "FAIL: desktop entry does not open the Ollama menu" >&2
  fail=1
fi
if grep -q '^NoDisplay=true$' "$desktop"; then
  echo "FAIL: Ollama is hidden from the idle menu" >&2
  fail=1
fi

output="$(COREBRUM_OLLAMA_READY=0 bash "$menu" open)"
if [[ "$output" != *'curl -fsSL https://ollama.com/install.sh | sh'* ]]; then
  echo "FAIL: selecting Ollama did not run the official installer" >&2
  fail=1
fi

export COREBRUM_OLLAMA_READY=1
export COREBRUM_OLLAMA_MODELS=$'llama3.2:latest\ngemma3:4b'
output="$(bash "$menu" open)"
if [[ "$output" != *'llama3.2:latest'* || "$output" != *'Run another model'* ]]; then
  echo "FAIL: installed Ollama did not list models (got ${output})" >&2
  fail=1
fi

output="$(COREBRUM_OLLAMA_CHOICE='llama3.2:latest' bash "$menu" open)"
if [[ "$output" != 'ollama run llama3.2:latest' ]]; then
  echo "FAIL: choosing a model did not run it (got ${output})" >&2
  fail=1
fi
output="$(COREBRUM_OLLAMA_CHOICE='Run another model' COREBRUM_OLLAMA_MODEL='hf.co/org/model:Q4' bash "$menu" open)"
if [[ "$output" != 'ollama run hf.co/org/model:Q4' ]]; then
  echo "FAIL: another model name was not accepted (got ${output})" >&2
  fail=1
fi
if COREBRUM_OLLAMA_CHOICE='llama3;id' bash "$menu" open >/dev/null 2>&1; then
  echo "FAIL: a model name with a shell metacharacter was accepted" >&2
  fail=1
fi

rm -rf "$runtime"
if [[ "$fail" -ne 0 ]]; then
  exit 1
fi
echo "ok: ollama menu"
