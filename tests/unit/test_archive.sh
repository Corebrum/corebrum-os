#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../scripts/lib/log.sh
source "${ROOT}/scripts/lib/log.sh"
# shellcheck source=../../scripts/lib/manifest.sh
source "${ROOT}/scripts/lib/manifest.sh"
# shellcheck source=../../scripts/lib/archive.sh
source "${ROOT}/scripts/lib/archive.sh"
# shellcheck source=../../scripts/lib/ppa.sh
source "${ROOT}/scripts/lib/ppa.sh"

assert_eq() {
  local got="$1"
  local expected="$2"
  local message="$3"
  if [[ "$got" != "$expected" ]]; then
    printf 'FAIL: %s (got %q expected %q)\n' "$message" "$got" "$expected" >&2
    exit 1
  fi
}

if corebrum_candidate_installable ""; then
  echo "FAIL: empty candidate should not be installable" >&2
  exit 1
fi
if corebrum_candidate_installable "(none)"; then
  echo "FAIL: (none) should not be installable" >&2
  exit 1
fi
if ! corebrum_candidate_installable "0.53.3+ds-4"; then
  echo "FAIL: a version candidate should be installable" >&2
  exit 1
fi

assert_eq "$(corebrum_shell_for_candidate "")" "waybar" "missing quickshell uses waybar"
assert_eq "$(corebrum_shell_for_candidate "(none)")" "waybar" "none candidate uses waybar"
assert_eq "$(corebrum_shell_for_candidate "0.3.0-1build1")" "quickshell" "published quickshell is selected"

curl_candidate="$(corebrum_archive_candidate curl)"
if ! corebrum_candidate_installable "$curl_candidate"; then
  echo "FAIL: curl should have an apt candidate (got ${curl_candidate:-empty})" >&2
  exit 1
fi

policy="$(cat <<'EOF'
hyprland:
  Installed: (none)
  Candidate: (none)
  Version table:
EOF
)"
assert_eq "$(corebrum_policy_ubuntu_version <<<"$policy")" "" "missing package has no ubuntu version"

policy="$(cat <<'EOF'
libxkbcommon0:
  Installed: 1.6.0-1build1
  Candidate: 1.6.0-1build1
  Version table:
 *** 1.6.0-1build1 500
        500 http://us.archive.ubuntu.com/ubuntu noble/main amd64 Packages
        100 /var/lib/dpkg/status
EOF
)"
assert_eq "$(corebrum_policy_ubuntu_version <<<"$policy")" "1.6.0-1build1" "installed ubuntu version"

policy="$(cat <<'EOF'
hyprland:
  Installed: (none)
  Candidate: 0.56.2-1ppa2
  Version table:
     0.56.2-1ppa2 500
        500 https://ppa.launchpadcontent.net/cppiber/hyprland/ubuntu noble/main amd64 Packages
EOF
)"
assert_eq "$(corebrum_policy_ubuntu_version <<<"$policy")" "" "ppa version is not an ubuntu archive version"

pinned=()
corebrum_load_manifest "${ROOT}/manifests/packages/hyprland-ppa.txt" pinned
found_hyprland=0
found_input=0
found_xkb=0
found_xkb_x11=0
found_xkb_reg=0
for pkg in "${pinned[@]}"; do
  [[ "$pkg" == "hyprland" ]] && found_hyprland=1
  [[ "$pkg" == "libinput10" ]] && found_input=1
  [[ "$pkg" == "libxkbcommon0" ]] && found_xkb=1
  [[ "$pkg" == "libxkbcommon-x11-0" ]] && found_xkb_x11=1
  [[ "$pkg" == "libxkbregistry0" ]] && found_xkb_reg=1
  if [[ "$pkg" == "waybar" || "$pkg" == "fuzzel" || "$pkg" == "pipewire" ]]; then
    echo "FAIL: ${pkg} must stay on the Ubuntu archive" >&2
    exit 1
  fi
done
if [[ "$found_hyprland" -ne 1 || "$found_input" -ne 1 || "$found_xkb" -ne 1 || "$found_xkb_x11" -ne 1 || "$found_xkb_reg" -ne 1 ]]; then
  echo "FAIL: Hyprland pin list is missing hyprland, libinput10, or an xkbcommon package" >&2
  exit 1
fi
assert_eq "$COREBRUM_HYPRLAND_PPA_FINGERPRINT" "A54D23B62FF3FCC76EFF71E8FDBAAA1CF0CCF48E" "recorded PPA fingerprint"

set +e
resolute_err="$(
  corebrum_ubuntu_archive_version() { printf ''; }
  corebrum_read_os_release_field() { printf 'resolute'; }
  DRY_RUN=1
  corebrum_install_hyprland_ppa 2>&1
)"
resolute_status=$?
noble_err="$(
  corebrum_ubuntu_archive_version() { printf ''; }
  corebrum_read_os_release_field() { printf 'noble'; }
  DRY_RUN=1
  corebrum_install_hyprland_ppa 2>&1
)"
noble_status=$?
archive_err="$(
  corebrum_ubuntu_archive_version() { printf '0.53.3+ds-4\n'; }
  DRY_RUN=1
  corebrum_install_hyprland_ppa 2>&1
)"
archive_status=$?
set -e
if [[ "$resolute_status" -eq 0 ]] || ! grep -q 'ppa:cppiber/hyprland is only used on noble' <<<"$resolute_err"; then
  echo "FAIL: Ubuntu 26.04 should refuse the Hyprland PPA when the archive has no hyprland" >&2
  exit 1
fi
if [[ "$noble_status" -ne 0 ]] || ! grep -q 'ppa:cppiber/hyprland' <<<"$noble_err"; then
  echo "FAIL: Ubuntu 24.04 should still plan the Hyprland PPA when the archive has no hyprland" >&2
  exit 1
fi
if [[ "$archive_status" -ne 0 ]] || ! grep -q 'not adding ppa:cppiber/hyprland' <<<"$archive_err"; then
  echo "FAIL: an archive hyprland package should skip the PPA" >&2
  exit 1
fi

echo "ok: archive"
