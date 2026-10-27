#!/usr/bin/env bash
# Getting Started pages, loopback Node server, and the unlocked Firefox homepage.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
docs="${ROOT}/config/getting-started"
nav="${docs}/nav.html"
server="${ROOT}/scripts/desktop/corebrum-getting-started-server.js"
wrapper="${ROOT}/scripts/desktop/corebrum-getting-started.sh"
unit="${ROOT}/config/systemd/corebrum-getting-started.service"
policy="${ROOT}/config/firefox/policies.json"
desktop="${ROOT}/scripts/lib/desktop.sh"
phase="${ROOT}/scripts/phases/02-desktop.sh"
validate="${ROOT}/scripts/validate/desktop.sh"
agents="${ROOT}/AGENTS.md"
menu="${ROOT}/scripts/desktop/corebrum-keys-menu.sh"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_file() {
  [[ -f "$1" ]] || fail "missing ${1#"${ROOT}/"}"
}

pages=(
  index.html
  physical-ai.html
  desktop.html
  ros.html
  zenoh.html
  realsense.html
  agenticros.html
  agents.html
  mission.html
  keybindings.html
  corebrum-cli.html
  agenticros-cli.html
)

for page in "${pages[@]}"; do
  assert_file "${docs}/${page}"
  if ! grep -q "href=\"${page}\"" "$nav"; then
    fail "sidebar does not link to ${page}"
  fi
  if ! grep -q '<!-- corebrum-nav -->' "${docs}/${page}"; then
    fail "${page} has no sidebar marker"
  fi
done

if ! grep -q 'src="/logo.png"' "$nav"; then
  fail "sidebar does not use the Corebrum logo"
fi
if ! grep -q 'The Physical AI Operating System' "$nav"; then
  fail "sidebar does not show the tagline"
fi
for icon in /ros.png /zenoh.png /realsense.png /agenticros.png /agents.png /ollama.png; do
  if ! grep -q "src=\"${icon}\"" "${docs}/index.html"; then
    fail "welcome page does not reference ${icon}"
  fi
done
if compgen -G "${docs}/*.png" >/dev/null; then
  fail "getting-started added another logo file"
fi

if ! grep -q 'ros2 topic list' "${docs}/ros.html"; then
  fail "ROS page is missing ros2 topic list"
fi
if ! grep -q 'ros2 topic echo' "${docs}/ros.html"; then
  fail "ROS page is missing ros2 topic echo"
fi
if ! grep -q 'ros2 topic pub' "${docs}/ros.html"; then
  fail "ROS page is missing ros2 topic pub"
fi
if ! grep -q 'ros2 node list' "${docs}/ros.html"; then
  fail "ROS page is missing ros2 node list"
fi

if ! grep -qF 'https://corebrum.org' "${docs}/index.html"; then
  fail "welcome page is missing https://corebrum.org"
fi
if ! grep -qF 'https://docs.ros.org/en/lyrical/' "${docs}/ros.html"; then
  fail "ROS page is missing the Lyrical docs"
fi
if ! grep -qF 'https://zenoh.io/' "${docs}/zenoh.html"; then
  fail "Zenoh page is missing https://zenoh.io/"
fi
if ! grep -qF 'https://realsenseai.com' "${docs}/realsense.html"; then
  fail "RealSense page is missing https://realsenseai.com"
fi
for site in \
  "https://agenticros.com" \
  "https://skills.agenticros.com" \
  "https://cloud.agenticros.com"
do
  if ! grep -qF "$site" "${docs}/agenticros.html"; then
    fail "AgenticROS page is missing ${site}"
  fi
done

for site in \
  "https://antigravity.google" \
  "https://claude.ai" \
  "https://chatgpt.com/codex" \
  "https://cursor.com" \
  "https://x.ai/build" \
  "https://hermes-agent.nousresearch.com" \
  "https://openclaw.ai" \
  "https://ollama.com"
do
  if ! grep -qF "$site" "${docs}/agents.html"; then
    fail "AI Agents page is missing ${site}"
  fi
done

if ! grep -q 'zenoh network' "${docs}/zenoh.html"; then
  fail "Zenoh page is missing zenoh network"
fi
if ! grep -q 'zenoh info' "${docs}/zenoh.html"; then
  fail "Zenoh page is missing zenoh info"
fi
if ! grep -q 'corebrum zenoh peers' "${docs}/zenoh.html"; then
  fail "Zenoh page is missing corebrum zenoh peers"
fi

keys="$(awk '/^Super\+|^Control\+/' "$menu")"
while IFS= read -r line; do
  [[ -n "$line" ]] || continue
  chord="$(printf '%s\n' "$line" | sed -E 's/[[:space:]]{2,}.*//')"
  desc="$(printf '%s\n' "$line" | sed -E 's/^.*[[:space:]]{2,}//')"
  if ! grep -qF "$chord" "${docs}/keybindings.html"; then
    fail "keybindings page is missing ${chord}"
  fi
  if ! grep -qF "$desc" "${docs}/keybindings.html"; then
    fail "keybindings page is missing ${desc}"
  fi
done <<<"$keys"

for command in \
  "corebrum version" \
  "corebrum status" \
  "corebrum doctor" \
  "corebrum config" \
  "corebrum install" \
  "corebrum uninstall" \
  "corebrum ros" \
  "corebrum zenoh" \
  "corebrum camera list" \
  "corebrum agents list" \
  "corebrum agents update" \
  "corebrum update status" \
  "corebrum speak" \
  "corebrum voice"
do
  if ! grep -qF "$command" "${docs}/corebrum-cli.html"; then
    fail "Corebrum commands page is missing ${command}"
  fi
done

for command in \
  "agenticros init" \
  "agenticros status" \
  "agenticros doctor" \
  "agenticros connect" \
  "agenticros disconnect" \
  "agenticros login" \
  "agenticros start realsense" \
  "agenticros stop realsense" \
  "agenticros start camera" \
  "agenticros stop camera" \
  "agenticros start motors" \
  "agenticros stop motors" \
  "agenticros eyes" \
  "agenticros stop eyes" \
  "agenticros up real" \
  "agenticros up sim-amr" \
  "agenticros up sim-arm" \
  "agenticros down" \
  "agenticros mode real" \
  "agenticros mode sim" \
  "agenticros mcp setup" \
  "agenticros skills list" \
  "agenticros skills search" \
  "agenticros skills install" \
  "agenticros skills remove" \
  "agenticros desktop"
do
  if ! grep -qF "$command" "${docs}/agenticros-cli.html"; then
    fail "AgenticROS commands page is missing ${command}"
  fi
done

if ! grep -q 'http://127.0.0.1:8765/getting-started/' "$policy"; then
  fail "Firefox homepage is not the Getting Started URL"
fi
if ! grep -q '"Locked": false' "$policy"; then
  fail "Firefox homepage is locked"
fi
if grep -q 'homepage-locked' "$policy"; then
  fail "Firefox homepage uses homepage-locked"
fi
if [[ -e "${ROOT}/config/chromium" ]]; then
  fail "a Chromium policy file was added"
fi
if grep -q 'snap install chromium' "$desktop" || grep -q 'snap install chromium' "$phase"; then
  fail "the desktop install installs the Chromium snap"
fi

if ! grep -q "127.0.0.1" "$server"; then
  fail "the server does not bind 127.0.0.1"
fi
if ! grep -q "require('http')" "$server"; then
  fail "the server does not use Node's http module"
fi
if ! grep -q '/usr/share/corebrum' "$server"; then
  fail "the server does not serve /usr/share/corebrum"
fi
if grep -q 'express' "$server" || grep -q 'python' "$server"; then
  fail "the server depends on Express or Python"
fi
if [[ -f "${ROOT}/scripts/desktop/package.json" || -f "${docs}/package.json" ]]; then
  fail "Getting Started added an npm package"
fi
if ! grep -q '^User=nobody$' "$unit"; then
  fail "the unit does not run as nobody"
fi
if ! grep -q '^ExecStart=/usr/local/bin/corebrum-getting-started$' "$unit"; then
  fail "the unit does not start the Node wrapper"
fi
if grep -q '0.0.0.0' "$unit" || grep -q '0.0.0.0' "$server"; then
  fail "Getting Started listens beyond loopback"
fi
if ! grep -q 'corebrum-node-path.sh' "$wrapper"; then
  fail "the wrapper does not use the Node 26 path helper"
fi

node_line="$(grep -n 'corebrum_install_node$' "$phase" | head -n 1 | cut -d: -f1)"
enable_line="$(grep -n 'corebrum_enable_getting_started$' "$phase" | head -n 1 | cut -d: -f1)"
if [[ -z "$node_line" || -z "$enable_line" || "$enable_line" -le "$node_line" ]]; then
  fail "the desktop phase does not enable Getting Started after Node.js"
fi
if ! grep -q 'corebrum_install_getting_started' "$desktop"; then
  fail "the desktop install does not copy the Getting Started files"
fi
if ! grep -q '/etc/firefox/policies/policies.json' "$desktop"; then
  fail "the desktop install does not install the Firefox policy"
fi
if ! grep -q 'corebrum-getting-started.service' "$desktop"; then
  fail "desktop uninstall does not name the Getting Started unit"
fi
if ! grep -q 'corebrum_disable_getting_started' "$desktop"; then
  fail "desktop uninstall does not stop the Getting Started unit"
fi
for installed in \
  /usr/share/corebrum/getting-started/index.html \
  /usr/local/bin/corebrum-getting-started \
  /etc/systemd/system/corebrum-getting-started.service \
  /etc/firefox/policies/policies.json
do
  if ! grep -q "$installed" "$validate"; then
    fail "desktop validate does not check ${installed}"
  fi
done
if ! grep -q 'config/getting-started/' "$agents"; then
  fail "AGENTS.md does not name the Getting Started pages"
fi

if command -v node >/dev/null 2>&1 && command -v curl >/dev/null 2>&1; then
  tmp="$(mktemp -d)"
  port="$((20000 + RANDOM % 20000))"
  pid=""
  cleanup() {
    if [[ -n "$pid" ]]; then
      kill "$pid" >/dev/null 2>&1 || true
      wait "$pid" >/dev/null 2>&1 || true
    fi
    rm -rf "$tmp"
  }
  trap cleanup EXIT
  mkdir -p "${tmp}/getting-started"
  cp "${docs}/"* "${tmp}/getting-started/"
  cp "${ROOT}/config/brand/"*.png "$tmp/"
  # Run a copy outside this checkout. A parent package.json with
  # "type": "module" would otherwise treat the repo .js file as ESM.
  cp "$server" "${tmp}/getting-started-server.js"
  COREBRUM_GETTING_STARTED_ROOT="$tmp" \
    COREBRUM_GETTING_STARTED_PORT="$port" \
    node "${tmp}/getting-started-server.js" >"${tmp}/server.log" 2>&1 &
  pid="$!"
  ready=0
  for _ in $(seq 1 50); do
    if curl -sf -o /dev/null "http://127.0.0.1:${port}/getting-started/"; then
      ready=1
      break
    fi
    sleep 0.05
  done
  if [[ "$ready" -ne 1 ]]; then
    cat "${tmp}/server.log" >&2 || true
    fail "Getting Started server did not listen on ${port}"
  fi
  body="$(curl -sf "http://127.0.0.1:${port}/getting-started/")"
  if ! grep -q 'href="index.html" aria-current="page"' <<<"$body"; then
    fail "the welcome page did not mark its sidebar link"
  fi
  if ! grep -q 'The Physical AI Operating System' <<<"$body"; then
    fail "the welcome page did not include the sidebar"
  fi
  ros_body="$(curl -sf "http://127.0.0.1:${port}/getting-started/ros.html")"
  if ! grep -q 'href="ros.html" aria-current="page"' <<<"$ros_body"; then
    fail "the ROS page did not mark its sidebar link"
  fi
  if grep -q 'href="index.html" aria-current="page"' <<<"$ros_body"; then
    fail "the ROS page marked the welcome link"
  fi
  logo_code="$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:${port}/logo.png")"
  [[ "$logo_code" == "200" ]] || fail "logo.png was not served"
  root_code="$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:${port}/")"
  [[ "$root_code" == "404" ]] || fail "the server listed the share root"
  nav_code="$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:${port}/getting-started/nav.html")"
  [[ "$nav_code" == "404" ]] || fail "nav.html was served as a page"
  escape_code="$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:${port}/getting-started/..%2F..%2Fetc/passwd")"
  [[ "$escape_code" == "404" ]] || fail "a path outside the share was served"
  cleanup
  trap - EXIT
  pid=""
fi

echo "getting started unit tests passed"
