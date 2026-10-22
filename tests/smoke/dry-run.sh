#!/usr/bin/env bash
# Fail if a dry-run executes apt, locale, time, or service commands.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
shim_dir="$(mktemp -d)"
trap 'rm -rf "$shim_dir"' EXIT

for cmd in apt-get locale-gen timedatectl systemctl dpkg; do
  printf '#!/bin/sh\necho "forbidden command: %s $*" >&2\nexit 99\n' "$cmd" >"${shim_dir}/${cmd}"
  chmod +x "${shim_dir}/${cmd}"
done

run_dry() {
  PATH="${shim_dir}:${PATH}" "${ROOT}/scripts/install.sh" "$@" 2>&1
}

assert_dry_run() {
  local status output
  set +e
  output="$(run_dry "$@")"
  status=$?
  set -e
  if [[ "$status" -ne 0 ]]; then
    printf '%s\n' "$output" >&2
    echo "FAIL: dry-run exited ${status}" >&2
    exit 1
  fi
  if grep -q 'forbidden command' <<<"$output"; then
    printf '%s\n' "$output" >&2
    echo "FAIL: dry-run invoked a mutating command" >&2
    exit 1
  fi
  printf '%s\n' "$output"
}

output="$(assert_dry_run --profile base --dry-run)"
if ! grep -q 'base profile dry-run complete' <<<"$output"; then
  printf '%s\n' "$output" >&2
  echo "FAIL: dry-run did not finish the base profile" >&2
  exit 1
fi
if ! grep -q 'ca-certificates' <<<"$output"; then
  echo "FAIL: dry-run did not list base packages" >&2
  exit 1
fi
if grep -q 'systemctl enable --now ssh' <<<"$output"; then
  echo "FAIL: dry-run enabled ssh without --enable-ssh" >&2
  exit 1
fi

ssh_output="$(assert_dry_run --profile base --dry-run --enable-ssh)"
if ! grep -q 'systemctl enable --now ssh' <<<"$ssh_output"; then
  printf '%s\n' "$ssh_output" >&2
  echo "FAIL: --enable-ssh dry-run did not show the ssh action" >&2
  exit 1
fi
if ! grep -q 'openssh-server' <<<"$ssh_output"; then
  echo "FAIL: --enable-ssh dry-run did not list openssh-server" >&2
  exit 1
fi

desktop_output="$(assert_dry_run --profile desktop --dry-run)"
if ! grep -q 'desktop profile dry-run complete' <<<"$desktop_output"; then
  printf '%s\n' "$desktop_output" >&2
  echo "FAIL: dry-run did not finish the desktop profile" >&2
  exit 1
fi
if ! grep -q 'waybar' <<<"$desktop_output"; then
  echo "FAIL: desktop dry-run did not list waybar" >&2
  exit 1
fi
if ! grep -Eq 'quickshell is not in the Ubuntu archive|quickshell candidate ' <<<"$desktop_output"; then
  echo "FAIL: desktop dry-run did not record the Quickshell decision" >&2
  exit 1
fi
if ! grep -Eq 'hyprland is not in the Ubuntu archive|hyprland candidate ' <<<"$desktop_output"; then
  echo "FAIL: desktop dry-run did not record the Hyprland decision" >&2
  exit 1
fi
if ! grep -Eq 'hyprland-backgrounds candidate |hyprland-backgrounds is not in the archive' <<<"$desktop_output"; then
  echo "FAIL: desktop dry-run did not record the wallpaper asset decision" >&2
  exit 1
fi
if grep -q 'hyprland is not in the Ubuntu archive' <<<"$desktop_output"; then
  if ! grep -q 'ppa:cppiber/hyprland' <<<"$desktop_output"; then
    echo "FAIL: desktop dry-run did not name the Hyprland PPA" >&2
    exit 1
  fi
fi
if ! grep -q 'not changing existing Netplan files or running netplan apply' <<<"$desktop_output"; then
  echo "FAIL: desktop dry-run did not promise to leave existing Netplan files unchanged" >&2
  exit 1
fi
if grep -Eq 'run: netplan apply|dry-run: netplan apply' <<<"$desktop_output"; then
  echo "FAIL: desktop dry-run would apply netplan" >&2
  exit 1
fi
if ! grep -q 'network-manager' <<<"$desktop_output"; then
  echo "FAIL: desktop dry-run did not list network-manager" >&2
  exit 1
fi
if ! grep -q 'clone nvm v0.40.8 (a885b885fef16fac4bc544188fb25e9e37ae83e8) into /usr/local/nvm' <<<"$desktop_output"; then
  echo "FAIL: desktop dry-run did not plan the nvm checkout" >&2
  exit 1
fi
if ! grep -q 'install Node.js 26.x' <<<"$desktop_output"; then
  echo "FAIL: desktop dry-run did not plan Node.js 26.x" >&2
  exit 1
fi
if ! grep -q 'npm install -g --allow-scripts=pnpm pnpm@12.15.0' <<<"$desktop_output"; then
  echo "FAIL: desktop dry-run did not plan pnpm" >&2
  exit 1
fi
if ! grep -q 'dry-run: install /etc/profile.d/corebrum-node.sh' <<<"$desktop_output"; then
  echo "FAIL: desktop dry-run did not plan the Node.js profile" >&2
  exit 1
fi
if grep -q '\.nvm' <<<"$desktop_output"; then
  echo "FAIL: desktop dry-run would write a home-directory nvm checkout" >&2
  exit 1
fi
if ! grep -q 'workstation services dry-run complete' <<<"$desktop_output"; then
  printf '%s\n' "$desktop_output" >&2
  echo "FAIL: dry-run did not finish workstation services" >&2
  exit 1
fi
if grep -q 'ros-jazzy-ros-base' <<<"$desktop_output"; then
  echo "FAIL: desktop dry-run listed ROS packages" >&2
  exit 1
fi

ros_output="$(assert_dry_run --profile ros --dry-run)"
if ! grep -q 'ros profile dry-run complete' <<<"$ros_output"; then
  printf '%s\n' "$ros_output" >&2
  echo "FAIL: dry-run did not finish the ros profile" >&2
  exit 1
fi
if ! grep -q 'ros-jazzy-rmw-zenoh-cpp' <<<"$ros_output"; then
  echo "FAIL: ros dry-run did not list the Zenoh RMW" >&2
  exit 1
fi
if ! grep -q 'not changing existing Netplan files or running netplan apply' <<<"$ros_output"; then
  echo "FAIL: ros dry-run did not promise to leave existing Netplan files unchanged" >&2
  exit 1
fi
if ! grep -q 'not running apt upgrade' <<<"$ros_output"; then
  echo "FAIL: ros dry-run did not refuse apt upgrade" >&2
  exit 1
fi
if grep -Eq 'ros-jazzy-desktop|ros-jazzy-rviz2|releases/latest' <<<"$ros_output"; then
  echo "FAIL: ros dry-run floated the apt source or listed a later-phase package" >&2
  exit 1
fi

set +e
uninstall_output="$(PATH="${shim_dir}:${PATH}" "${ROOT}/scripts/uninstall.sh" --profile desktop --dry-run 2>&1)"
uninstall_status=$?
set -e
if [[ "$uninstall_status" -ne 0 ]]; then
  printf '%s\n' "$uninstall_output" >&2
  echo "FAIL: desktop uninstall dry-run exited ${uninstall_status}" >&2
  exit 1
fi
if grep -q 'forbidden command' <<<"$uninstall_output"; then
  printf '%s\n' "$uninstall_output" >&2
  echo "FAIL: desktop uninstall dry-run invoked a mutating command" >&2
  exit 1
fi
if ! grep -q 'dry-run: remove /usr/local/nvm when .corebrum-managed is present' <<<"$uninstall_output"; then
  echo "FAIL: desktop uninstall dry-run did not plan to remove the nvm checkout" >&2
  exit 1
fi
if ! grep -q 'desktop uninstall dry-run complete' <<<"$uninstall_output"; then
  printf '%s\n' "$uninstall_output" >&2
  echo "FAIL: desktop uninstall dry-run did not finish" >&2
  exit 1
fi

echo "ok: dry-run"
