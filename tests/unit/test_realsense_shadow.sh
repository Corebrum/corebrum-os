#!/usr/bin/env bash
# A source build in /usr/local shares the librealsense soname with the package
# and comes first on PATH and in the loader search. The installer must say so
# instead of reporting a silent success. It warns and does not fail.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
script="${ROOT}/scripts/desktop/corebrum-realsense-install.sh"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

report() {
  bash -c 'source "$1"; shift; realsense_shadow_report "$@"' _ "$script" "$@"
}

pkg="${work}/usr/lib/aarch64-linux-gnu"
local_lib="${work}/usr/local/lib"
mkdir -p "$pkg" "$local_lib" "${work}/usr/bin" "${work}/usr/local/bin"
: >"${pkg}/librealsense2.so.2.59.2"
ln -s librealsense2.so.2.59.2 "${pkg}/librealsense2.so.2.59"
: >"${local_lib}/librealsense2.so.2.59.1"
ln -s librealsense2.so.2.59.1 "${local_lib}/librealsense2.so.2.59"
: >"${work}/usr/bin/realsense-viewer"
: >"${work}/usr/local/bin/realsense-viewer"

# The Jetson reference kit on 2026-11-17: a CUDA build of 2.59.1 in /usr/local.
if out="$(report "${work}/usr/local/bin/realsense-viewer" "${work}/usr/bin/realsense-viewer" \
  "${local_lib}/librealsense2.so.2.59" "$pkg" 2.59.2)"; then
  fail "a /usr/local build was not reported"
fi
grep -qF "realsense-viewer on PATH is ${work}/usr/local/bin/realsense-viewer" <<<"$out" || fail "the PATH viewer was not named: ${out}"
grep -qF "load librealsense 2.59.1 from ${local_lib}/librealsense2.so.2.59.1, not 2.59.2" <<<"$out" \
  || fail "the loaded library version was not named: ${out}"
grep -qF 'yours to update or remove' <<<"$out" || fail "the warning does not say who owns the build: ${out}"
grep -qF 'install_manifest.txt' <<<"$out" || fail "the warning does not point at the install manifest: ${out}"

# Packages only: no warning. The loader may name the /lib path on a usrmerge system.
if ! out="$(report "${work}/usr/bin/realsense-viewer" "${work}/usr/bin/realsense-viewer" \
  "${pkg}/librealsense2.so.2.59" "$pkg" 2.59.2)"; then
  fail "the package install was reported as shadowed: ${out}"
fi
[[ -z "$out" ]] || fail "the package install printed a warning: ${out}"

# Only the viewer is shadowed (for example a copied binary): still a warning.
out="$(report "${work}/usr/local/bin/realsense-viewer" "${work}/usr/bin/realsense-viewer" \
  "${pkg}/librealsense2.so.2.59" "$pkg" 2.59.2)" && fail "a shadowing viewer alone was not reported"
grep -qF 'load librealsense' <<<"$out" && fail "the library was reported although it is the package: ${out}"

# The installer runs the check after it installs and does not stop on it.
grep -qE '^  realsense_check_shadow$' "$script" || fail "realsense_install_main does not run the shadow check"
grep -qF '"${REALSENSE_SDK_VERSION%%-*}" || true' "$script" || fail "the shadow check can fail the install"

echo "ok: realsense-shadow"
