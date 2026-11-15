#!/usr/bin/env bash
# Non-destructive B-ref pre-checks (no cmd_vel motion unless COREBRUM_B_REF_MOTION=1).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../lib/hardware.sh
source "${ROOT}/scripts/lib/hardware.sh"

echo "==> Jetson B-ref validation"

if ! corebrum_detect_jetson; then
  echo "SKIP: not a Tegra host (software tests only)."
  echo "     Run this script on the reference Orin kit for full B-ref."
  exit 0
fi

ref_id="$(corebrum_reference_hardware_id)"
echo "    reference hardware id: ${ref_id:-unknown}"

if ! command -v synapse >/dev/null 2>&1; then
  echo "FAIL: synapse not on PATH" >&2
  exit 1
fi

echo "==> synapse doctor (Jetson GPIO checks)"
if ! synapse doctor 2>&1 | tee /tmp/corebrum-b-ref-doctor.log; then
  echo "FAIL: synapse doctor reported errors" >&2
  exit 1
fi

backend_test="${ROOT}/../synapse/packages/synapse-robot/lib/resolve-motor-backend.test.js"
if [[ -f "$backend_test" ]]; then
  echo "==> motor backend unit tests"
  (cd "${ROOT}/../synapse/packages/synapse-robot" && npm test -- lib/resolve-motor-backend.test.js) || exit 1
fi

if [[ "${COREBRUM_B_REF_MOTION:-0}" != "1" ]]; then
  echo "OK: static checks passed. For motion B-ref set COREBRUM_B_REF_MOTION=1 and run"
  echo "    synapse/docs/acceptance/jetson-b-ref.md steps 4–5 on a clear floor."
  exit 0
fi

echo "==> motion checks (operator responsibility)"
echo "    synapse start motors"
echo "    publish bounded /cmd_vel twist"
echo "    synapse stop motors or ros2_estop"
echo "WARN: COREBRUM_B_REF_MOTION=1 does not automate motion — record results in ADR 0136."