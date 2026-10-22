#!/usr/bin/env bash
# Install librealsense, realsense-ros, and pyrealsense2 for the Super+Space menu.
# Run as root. desktop uninstall sources the remove helper.
COREBRUM_REALSENSE_KEY_URL="https://librealsense.realsenseai.com/Debian/librealsenseai.asc"
COREBRUM_REALSENSE_KEY_FINGERPRINT="5381411D24E659FB18195FA5FB0B24895113F120"
COREBRUM_REALSENSE_REPO="https://librealsense.realsenseai.com/Debian/apt-repo"
COREBRUM_REALSENSE_ORIGIN="librealsense.realsenseai.com"
COREBRUM_REALSENSE_KEYRING="/usr/share/keyrings/corebrum-librealsense.gpg"
COREBRUM_REALSENSE_SOURCE="/etc/apt/sources.list.d/corebrum-librealsense.sources"
COREBRUM_REALSENSE_PIN="/etc/apt/preferences.d/corebrum-librealsense"
COREBRUM_REALSENSE_PY="2.59.1.11053"

realsense_die() {
  printf 'realsense-install: %s\n' "$1" >&2
  exit 1
}

realsense_log() {
  if declare -F corebrum_log >/dev/null 2>&1; then
    corebrum_log "$1"
  else
    printf '%s\n' "$1"
  fi
}

realsense_codename() {
  # shellcheck disable=SC1091
  . /etc/os-release
  printf '%s\n' "${VERSION_CODENAME:-}"
}

realsense_versions() {
  local codename="$1"
  case "$codename" in
    noble)
      REALSENSE_SDK_VERSION="2.59.1-0~realsense.20270"
      REALSENSE_DKMS_VERSION="1.3.33-noble"
      REALSENSE_ROS_DISTRO="jazzy"
      ;;
    resolute)
      REALSENSE_SDK_VERSION="2.59.1-0~realsense.20271"
      REALSENSE_DKMS_VERSION=""
      REALSENSE_ROS_DISTRO="lyrical"
      ;;
    *)
      realsense_die "librealsense packages are pinned for noble and resolute (found ${codename:-unknown})"
      ;;
  esac
}

realsense_install_owned_file() {
  local src="$1" dest="$2" mode="$3" stamp
  mkdir -p "$(dirname "$dest")"
  if [[ -f "$dest" ]] && cmp -s "$src" "$dest"; then
    realsense_log "unchanged: ${dest}"
    return 0
  fi
  if [[ -e "$dest" ]]; then
    stamp="$(date +%Y%m%d-%H%M%S)"
    mkdir -p /var/log/corebrum/backups
    cp -a "$dest" "/var/log/corebrum/backups/${stamp}-$(basename "$dest")"
    realsense_log "backed up ${dest}"
  fi
  install -m "$mode" "$src" "$dest"
  realsense_log "installed ${dest}"
}

realsense_require_archive_version() {
  local pkg="$1" version="$2" madison
  # Capture first. grep -q in a pipeline exits early, and pipefail then treats
  # apt-cache's SIGPIPE as a missing package.
  madison="$(apt-cache madison "$pkg" || true)"
  if ! grep -qF "$version" <<<"$madison"; then
    realsense_die "${pkg} ${version} is not in the RealSense archive. apt listed: ${madison:-nothing}"
  fi
}

realsense_add_repo() {
  local codename="$1" work fingerprint source_file pin_file
  command -v curl >/dev/null 2>&1 || realsense_die "curl is required to fetch the RealSense signing key"
  command -v gpg >/dev/null 2>&1 || realsense_die "gpg is required to check the RealSense signing key"
  work="$(mktemp -d)"
  mkdir -p "${work}/gnupg"
  chmod 700 "${work}/gnupg"
  if ! curl -fsSL --max-time 60 "$COREBRUM_REALSENSE_KEY_URL" -o "${work}/key.asc"; then
    rm -rf "$work"
    realsense_die "could not download the RealSense signing key"
  fi
  if ! GNUPGHOME="${work}/gnupg" gpg --batch --dearmor -o "${work}/key.gpg" "${work}/key.asc"; then
    rm -rf "$work"
    realsense_die "could not decode the RealSense signing key"
  fi
  fingerprint="$(GNUPGHOME="${work}/gnupg" gpg --batch --show-keys --with-colons "${work}/key.gpg" | awk -F: '/^fpr:/ { print $10 }')"
  if ! grep -qx "$COREBRUM_REALSENSE_KEY_FINGERPRINT" <<<"$fingerprint"; then
    rm -rf "$work"
    realsense_die "RealSense key fingerprint does not include ${COREBRUM_REALSENSE_KEY_FINGERPRINT}"
  fi
  realsense_install_owned_file "${work}/key.gpg" "$COREBRUM_REALSENSE_KEYRING" 644
  source_file="${work}/realsense.sources"
  pin_file="${work}/realsense.pin"
  cat >"$source_file" <<EOF
# Managed by Corebrum OS. RealSense SDK packages for realsense-viewer.
Types: deb
URIs: ${COREBRUM_REALSENSE_REPO}
Suites: ${codename}
Components: main
Signed-By: ${COREBRUM_REALSENSE_KEYRING}
EOF
  cat >"$pin_file" <<EOF
# Managed by Corebrum OS.
# Only the RealSense SDK packages used by the Super+Space installer come from
# ${COREBRUM_REALSENSE_ORIGIN}. Everything else there stays below Ubuntu.
Package: librealsense2 librealsense2-gl librealsense2-utils librealsense2-udev-rules librealsense2-dkms
Pin: origin ${COREBRUM_REALSENSE_ORIGIN}
Pin-Priority: 500

Package: *
Pin: origin ${COREBRUM_REALSENSE_ORIGIN}
Pin-Priority: 100
EOF
  realsense_install_owned_file "$source_file" "$COREBRUM_REALSENSE_SOURCE" 644
  realsense_install_owned_file "$pin_file" "$COREBRUM_REALSENSE_PIN" 644
  rm -rf "$work"
}

realsense_install_python() {
  local py
  py="$(python3 -c 'import sys; print("%d.%d" % sys.version_info[:2])')"
  case "$py" in
    3.10 | 3.11 | 3.12 | 3.13 | 3.14) ;;
    *)
      realsense_die "Python ${py} has no x86_64 wheel for pyrealsense2 ${COREBRUM_REALSENSE_PY}. That release publishes wheels for Python 3.10 through 3.14."
      ;;
  esac
  realsense_log "using system Python ${py} for pyrealsense2 ${COREBRUM_REALSENSE_PY}"
  python3 -m pip install --disable-pip-version-check --break-system-packages "pyrealsense2==${COREBRUM_REALSENSE_PY}"
  python3 -c 'import pyrealsense2' || realsense_die "Python ${py} could not import pyrealsense2"
}

realsense_install_main() {
  local codename
  [[ "$(id -u)" -eq 0 ]] || realsense_die "RealSense install requires root"
  [[ "$(uname -m)" == "x86_64" ]] || realsense_die "pyrealsense2 wheels used here are x86_64 only"
  [[ -f /etc/apt/sources.list.d/ros2.sources ]] || realsense_die "the ROS apt source is missing; choose ROS 2 in Super+Space first, then select RealSense again"
  codename="$(realsense_codename)"
  realsense_versions "$codename"
  realsense_add_repo "$codename"
  export DEBIAN_FRONTEND=noninteractive
  realsense_log "run: apt-get update"
  apt-get update
  realsense_require_archive_version librealsense2 "$REALSENSE_SDK_VERSION"
  realsense_require_archive_version librealsense2-gl "$REALSENSE_SDK_VERSION"
  realsense_require_archive_version librealsense2-utils "$REALSENSE_SDK_VERSION"
  realsense_require_archive_version librealsense2-udev-rules "$REALSENSE_SDK_VERSION"
  realsense_log "run: apt-get install librealsense2 ${REALSENSE_SDK_VERSION}"
  apt-get install -y --no-install-recommends \
    "librealsense2=${REALSENSE_SDK_VERSION}" \
    "librealsense2-gl=${REALSENSE_SDK_VERSION}" \
    "librealsense2-utils=${REALSENSE_SDK_VERSION}" \
    "librealsense2-udev-rules=${REALSENSE_SDK_VERSION}"
  if [[ -n "$REALSENSE_DKMS_VERSION" ]]; then
    realsense_require_archive_version librealsense2-dkms "$REALSENSE_DKMS_VERSION"
    realsense_log "run: apt-get install librealsense2-dkms ${REALSENSE_DKMS_VERSION}"
    apt-get install -y --no-install-recommends "librealsense2-dkms=${REALSENSE_DKMS_VERSION}"
  else
    realsense_log "librealsense2-dkms is not published for ${codename}; skipping the kernel module package"
  fi
  realsense_log "run: apt-get install ros-${REALSENSE_ROS_DISTRO}-librealsense2 ros-${REALSENSE_ROS_DISTRO}-realsense2-camera python3-pip"
  apt-get install -y --no-install-recommends \
    "ros-${REALSENSE_ROS_DISTRO}-librealsense2" \
    "ros-${REALSENSE_ROS_DISTRO}-realsense2-camera" \
    python3-pip
  realsense_install_python
  command -v realsense-viewer >/dev/null 2>&1 || realsense_die "realsense-viewer is not on PATH"
  realsense_log "RealSense is installed"
}

realsense_remove_repo() {
  local path
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    realsense_log "dry-run: remove ${COREBRUM_REALSENSE_SOURCE}, ${COREBRUM_REALSENSE_PIN}, and ${COREBRUM_REALSENSE_KEYRING}"
    return 0
  fi
  for path in "$COREBRUM_REALSENSE_SOURCE" "$COREBRUM_REALSENSE_PIN" "$COREBRUM_REALSENSE_KEYRING"; do
    if [[ -e "$path" ]]; then
      if declare -F corebrum_backup_file >/dev/null 2>&1; then
        corebrum_backup_file "$path"
      fi
      rm -f "$path"
      realsense_log "removed ${path}"
    fi
  done
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  set -euo pipefail
  realsense_install_main
fi
