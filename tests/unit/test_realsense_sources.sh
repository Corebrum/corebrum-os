#!/usr/bin/env bash
# An operator who followed Intel's install steps already has librealsense.list
# with its own keyring. apt rejects a second entry for the same archive with a
# different Signed-By, so the RealSense installer must reuse that entry.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
script="${ROOT}/scripts/desktop/corebrum-realsense-install.sh"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

# Runs one installer function in a child shell so realsense_die cannot end the test.
rs() {
  bash -c 'source "$1"; shift; "$@"' _ "$script" "$@"
}

apt="${work}/apt"
mkdir -p "${apt}/sources.list.d"
printf 'deb http://ports.ubuntu.com/ubuntu-ports noble main\n' >"${apt}/sources.list"
[[ -z "$(rs realsense_foreign_sources "$apt")" ]] || fail "an Ubuntu-only apt dir reported a RealSense source"

# Corebrum's own file is not foreign.
printf 'URIs: https://librealsense.realsenseai.com/Debian/apt-repo\nSuites: noble\n' \
  >"${apt}/sources.list.d/corebrum-librealsense.sources"
[[ -z "$(rs realsense_foreign_sources "$apt")" ]] || fail "Corebrum's own source counted as foreign"

# A commented-out entry is not a source.
printf '# deb https://librealsense.realsenseai.com/Debian/apt-repo noble main\n' \
  >"${apt}/sources.list.d/old.list"
[[ -z "$(rs realsense_foreign_sources "$apt")" ]] || fail "a commented entry counted as a source"

# Intel's one-line form, as found on the Jetson reference kit.
intel="${apt}/sources.list.d/librealsense.list"
printf 'deb [signed-by=%s/missing.gpg] https://librealsense.realsenseai.com/Debian/apt-repo noble main\n' "$work" >"$intel"
[[ "$(rs realsense_foreign_sources "$apt")" == "$intel" ]] || fail "Intel's librealsense.list was not found"

# deb822 form, trailing slash on the URI.
deb822="${apt}/sources.list.d/realsense.sources"
printf 'Types: deb\nURIs: https://librealsense.realsenseai.com/Debian/apt-repo/\nSuites: noble\nComponents: main\n' >"$deb822"
rs realsense_foreign_sources "$apt" | grep -qxF "$deb822" || fail "a deb822 RealSense source was not found"

out="$(rs realsense_check_foreign_source "$intel" resolute 2>&1)" && fail "a source without the needed suite was accepted"
grep -qF 'without the resolute suite' <<<"$out" || fail "wrong-suite message is unclear: ${out}"

out="$(rs realsense_check_foreign_source "$intel" noble 2>&1)" && fail "a missing keyring was accepted"
grep -qF 'which is missing' <<<"$out" || fail "missing-keyring message is unclear: ${out}"

out="$(rs realsense_check_foreign_source "$deb822" noble 2>&1)" || fail "a source without Signed-By stopped the install: ${out}"
grep -qF 'has no Signed-By' <<<"$out" || fail "a source without Signed-By was not reported"

# A keyring that does not hold the RealSense key is refused.
if command -v gpg >/dev/null 2>&1; then
  mkdir -p "${work}/gnupg"
  chmod 700 "${work}/gnupg"
  GNUPGHOME="${work}/gnupg" gpg --batch --quiet --passphrase '' --quick-gen-key 'Not RealSense <x@example.invalid>' ed25519 sign never 2>/dev/null
  GNUPGHOME="${work}/gnupg" gpg --batch --export >"${work}/other.gpg"
  printf 'deb [signed-by=%s/other.gpg] https://librealsense.realsenseai.com/Debian/apt-repo noble main\n' "$work" >"$intel"
  out="$(rs realsense_check_foreign_source "$intel" noble 2>&1)" && fail "a keyring without the RealSense key was accepted"
  grep -qF 'does not hold RealSense key' <<<"$out" || fail "wrong-key message is unclear: ${out}"
fi

# The installer must look for an existing source before adding its own.
grep -qF 'foreign="$(realsense_foreign_sources /etc/apt)"' "$script" || fail "realsense_add_repo no longer checks for an existing source"

echo "ok: realsense-sources"
