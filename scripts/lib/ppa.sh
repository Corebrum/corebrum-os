#!/usr/bin/env bash
# Named Hyprland PPA. Source this file; do not execute it.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  echo "source scripts/lib/ppa.sh from another script" >&2
  exit 1
fi

# Fingerprint published by Launchpad for ~cppiber/hyprland and checked against
# the keyserver key "Launchpad PPA for Constantin Piber".
COREBRUM_HYPRLAND_PPA_FINGERPRINT="A54D23B62FF3FCC76EFF71E8FDBAAA1CF0CCF48E"
COREBRUM_HYPRLAND_PPA_ORIGIN="LP-PPA-cppiber-hyprland"
COREBRUM_HYPRLAND_KEYRING="/usr/share/keyrings/corebrum-cppiber-hyprland.gpg"
COREBRUM_HYPRLAND_SOURCE="/etc/apt/sources.list.d/corebrum-cppiber-hyprland.sources"
COREBRUM_HYPRLAND_PIN="/etc/apt/preferences.d/corebrum-cppiber-hyprland"

# Print the version published by archive.ubuntu.com or security.ubuntu.com.
# corebrum_policy_ubuntu_version reads apt-cache policy text on stdin.
corebrum_policy_ubuntu_version() {
  awk '
    ver != "" && $0 ~ /archive\.ubuntu\.com|security\.ubuntu\.com/ { print ver; exit }
    $1 == "***" { ver = $2; next }
    $1 ~ /^[0-9]/ { ver = $1; next }
  '
}

corebrum_ubuntu_archive_version() {
  local policy
  policy="$(apt-cache policy "$1" 2>/dev/null || true)"
  corebrum_policy_ubuntu_version <<<"$policy"
}

corebrum_write_hyprland_pin() {
  local dest="$1"
  local -a packages=()
  corebrum_load_manifest "${COREBRUM_ROOT}/manifests/packages/hyprland-ppa.txt" packages
  cat >"$dest" <<EOF
# Managed by Corebrum OS.
# ppa:cppiber/hyprland is below the Ubuntu archive except for Hyprland
# and the libraries that package requires.
Package: ${packages[*]}
Pin: release o=${COREBRUM_HYPRLAND_PPA_ORIGIN}
Pin-Priority: 500

Package: *
Pin: release o=${COREBRUM_HYPRLAND_PPA_ORIGIN}
Pin-Priority: 100
EOF
}

corebrum_install_hyprland_ppa() {
  local ubuntu_version codename work fingerprint source_file pin_file
  ubuntu_version="$(corebrum_ubuntu_archive_version hyprland)"
  if [[ -n "$ubuntu_version" ]]; then
    corebrum_log "hyprland ${ubuntu_version} is in the Ubuntu archive; not adding ppa:cppiber/hyprland"
    return 0
  fi
  codename="$(corebrum_read_os_release_field /etc/os-release VERSION_CODENAME || true)"
  if [[ "$codename" != "noble" ]]; then
    corebrum_die "hyprland is not in the Ubuntu archive on ${codename:-unknown}; ppa:cppiber/hyprland is only used on noble"
  fi
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    corebrum_log "dry-run: install signing key ${COREBRUM_HYPRLAND_PPA_FINGERPRINT} for ppa:cppiber/hyprland"
    corebrum_log "dry-run: write ${COREBRUM_HYPRLAND_SOURCE}"
    corebrum_log "dry-run: write ${COREBRUM_HYPRLAND_PIN} so only Hyprland's required packages come from that PPA"
    corebrum_log "dry-run: apt-get update"
    return 0
  fi
  command -v curl >/dev/null 2>&1 || corebrum_die "curl is required to fetch the Hyprland PPA key"
  command -v gpg >/dev/null 2>&1 || corebrum_die "gpg is required to check the Hyprland PPA key"
  codename="$(corebrum_read_os_release_field /etc/os-release VERSION_CODENAME || true)"
  [[ "$codename" == "noble" ]] || corebrum_die "ppa:cppiber/hyprland is configured for noble (found ${codename:-unknown})"

  work="$(mktemp -d)"
  mkdir -p "${work}/gnupg"
  chmod 700 "${work}/gnupg"
  corebrum_log "run: fetch Hyprland PPA signing key"
  if ! curl -fsSL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x${COREBRUM_HYPRLAND_PPA_FINGERPRINT}" -o "${work}/key.asc"; then
    rm -rf "$work"
    corebrum_die "could not download the Hyprland PPA signing key"
  fi
  if ! GNUPGHOME="${work}/gnupg" gpg --batch --dearmor -o "${work}/key.gpg" "${work}/key.asc"; then
    rm -rf "$work"
    corebrum_die "could not decode the Hyprland PPA signing key"
  fi
  fingerprint="$(GNUPGHOME="${work}/gnupg" gpg --batch --show-keys --with-colons "${work}/key.gpg")"
  fingerprint="$(awk -F: '/^fpr:/ { print $10; exit }' <<<"$fingerprint")"
  if [[ "$fingerprint" != "$COREBRUM_HYPRLAND_PPA_FINGERPRINT" ]]; then
    rm -rf "$work"
    corebrum_die "Hyprland PPA key fingerprint ${fingerprint:-missing} does not match ${COREBRUM_HYPRLAND_PPA_FINGERPRINT}"
  fi
  corebrum_install_file "${work}/key.gpg" "$COREBRUM_HYPRLAND_KEYRING" 644

  source_file="${work}/hyprland.sources"
  pin_file="${work}/hyprland.pin"
  cat >"$source_file" <<EOF
# Managed by Corebrum OS. ppa:cppiber/hyprland
Types: deb
URIs: https://ppa.launchpadcontent.net/cppiber/hyprland/ubuntu
Suites: ${codename}
Components: main
Signed-By: ${COREBRUM_HYPRLAND_KEYRING}
EOF
  corebrum_write_hyprland_pin "$pin_file"
  corebrum_install_file "$source_file" "$COREBRUM_HYPRLAND_SOURCE" 644
  corebrum_install_file "$pin_file" "$COREBRUM_HYPRLAND_PIN" 644
  rm -rf "$work"

  export DEBIAN_FRONTEND=noninteractive
  corebrum_log "run: apt-get update"
  apt-get update
}

corebrum_remove_hyprland_ppa() {
  local path
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    corebrum_log "dry-run: remove ${COREBRUM_HYPRLAND_SOURCE}, ${COREBRUM_HYPRLAND_PIN}, and ${COREBRUM_HYPRLAND_KEYRING}"
    return 0
  fi
  for path in "$COREBRUM_HYPRLAND_SOURCE" "$COREBRUM_HYPRLAND_PIN" "$COREBRUM_HYPRLAND_KEYRING"; do
    if [[ -e "$path" ]]; then
      corebrum_backup_file "$path"
      rm -f "$path"
      corebrum_log "removed ${path}"
    fi
  done
}
