#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ros="${ROOT}/scripts/lib/ros.sh"
wrapper="${ROOT}/scripts/ros/zenoh-cli.sh"

if ! grep -q 'eclipse-zenoh==1.9.0' "$ros"; then
  echo "FAIL: ROS install does not pin eclipse-zenoh 1.9.0" >&2
  exit 1
fi
if ! grep -q 'zenoh-cli==0.7.0' "$ros"; then
  echo "FAIL: ROS install does not pin zenoh-cli 0.7.0" >&2
  exit 1
fi
if ! grep -q 'COREBRUM_ZENOH_CLI_ROOT="/opt/corebrum/zenoh-cli"' "$ros"; then
  echo "FAIL: Zenoh CLI is not installed under /opt/corebrum/zenoh-cli" >&2
  exit 1
fi
if ! grep -q 'corebrum_ros_install_zenoh_cli' "$ros"; then
  echo "FAIL: ROS profile does not install the Zenoh CLI" >&2
  exit 1
fi
if ! grep -q 'rm -rf "$COREBRUM_ZENOH_CLI_ROOT"' "$ros"; then
  echo "FAIL: ROS uninstall does not remove the Zenoh CLI virtualenv" >&2
  exit 1
fi
if ! grep -q 'tcp/127.0.0.1:7447' "$wrapper"; then
  echo "FAIL: Zenoh CLI wrapper does not connect to the local router" >&2
  exit 1
fi
if ! grep -q 'scouting/multicast/enabled:false' "$wrapper"; then
  echo "FAIL: Zenoh CLI wrapper does not disable multicast scouting" >&2
  exit 1
fi

fake="$(mktemp)"
cat >"$fake" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@"
EOF
chmod 755 "$fake"

default="$(COREBRUM_ZENOH_CLI_BIN="$fake" "$wrapper" info)"
if [[ "$default" != $'--mode\nclient\n--connect\ntcp/127.0.0.1:7447\n--cfg\nscouting/multicast/enabled:false\ninfo' ]]; then
  echo "FAIL: bare zenoh command did not default to the local client" >&2
  echo "$default" >&2
  rm -f "$fake"
  exit 1
fi

custom="$(COREBRUM_ZENOH_CLI_BIN="$fake" "$wrapper" --mode peer info)"
if [[ "$custom" != $'--mode\npeer\ninfo' ]]; then
  echo "FAIL: an explicit session flag was rewritten" >&2
  echo "$custom" >&2
  rm -f "$fake"
  exit 1
fi
rm -f "$fake"

echo "ok: zenoh-cli"
