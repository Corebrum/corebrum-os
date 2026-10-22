#!/usr/bin/env bash
# Phase 5 ROS 2 Jazzy and Zenoh. Sourced by scripts/install.sh.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  echo "Run ./scripts/corebrum.sh install ros" >&2
  exit 1
fi

# shellcheck source=../lib/ros.sh
source "${COREBRUM_ROOT}/scripts/lib/ros.sh"
