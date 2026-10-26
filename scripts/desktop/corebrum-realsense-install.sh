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
# arm64 2.59.1 is published in the noble suite. The resolute suite is amd64 and i386.
# x86_64 keeps the codename pins in realsense_versions.
COREBRUM_REALSENSE_ARM64_SDK_VERSION="2.59.1-0~realsense.9166"
COREBRUM_REALSENSE_ARM64_SUITE="noble"
# Tag v2.59.1. PyPI has no cp314 aarch64 wheel for 2.59.1.11053.
COREBRUM_REALSENSE_SRC_URL="https://github.com/realsenseai/librealsense.git"
COREBRUM_REALSENSE_SRC_TAG="v2.59.1"
COREBRUM_REALSENSE_SRC_COMMIT="625279aa1fe903528a818f48746ee47c1b5fefd3"

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

realsense_install_python_wheel() {
  local py="$1"
  realsense_log "using system Python ${py} for pyrealsense2 ${COREBRUM_REALSENSE_PY}"
  python3 -m pip install --disable-pip-version-check --break-system-packages "pyrealsense2==${COREBRUM_REALSENSE_PY}"
  python3 -c 'import pyrealsense2' || realsense_die "Python ${py} could not import pyrealsense2"
}

realsense_build_python_bindings() {
  local py="$1" work peeled head cores platlib
  if python3 -c 'import pyrealsense2' >/dev/null 2>&1; then
    realsense_log "pyrealsense2 already imports on Python ${py}; not building it again"
    return 0
  fi
  realsense_log "pyrealsense2 ${COREBRUM_REALSENSE_PY} has no aarch64 wheel for Python ${py}; building librealsense ${COREBRUM_REALSENSE_SRC_TAG}"
  realsense_log "run: apt-get install build tools for the RealSense Python bindings"
  apt-get install -y --no-install-recommends \
    build-essential cmake git pkg-config python3-dev libusb-1.0-0-dev libudev-dev libssl-dev
  peeled="$(GIT_TERMINAL_PROMPT=0 git ls-remote "$COREBRUM_REALSENSE_SRC_URL" "refs/tags/${COREBRUM_REALSENSE_SRC_TAG}")" \
    || realsense_die "could not read librealsense tag ${COREBRUM_REALSENSE_SRC_TAG}"
  [[ "$peeled" == "${COREBRUM_REALSENSE_SRC_COMMIT}"*$'\t'* ]] \
    || realsense_die "librealsense tag ${COREBRUM_REALSENSE_SRC_TAG} resolved to '${peeled}', expected ${COREBRUM_REALSENSE_SRC_COMMIT}"
  work="$(mktemp -d)"
  realsense_log "run: git clone --depth 1 --branch ${COREBRUM_REALSENSE_SRC_TAG} ${COREBRUM_REALSENSE_SRC_URL}"
  if ! GIT_TERMINAL_PROMPT=0 git clone --depth 1 --branch "$COREBRUM_REALSENSE_SRC_TAG" "$COREBRUM_REALSENSE_SRC_URL" "${work}/librealsense"; then
    rm -rf "$work"
    realsense_die "could not clone librealsense ${COREBRUM_REALSENSE_SRC_TAG}"
  fi
  head="$(git -C "${work}/librealsense" rev-parse HEAD)"
  if [[ "$head" != "$COREBRUM_REALSENSE_SRC_COMMIT" ]]; then
    rm -rf "$work"
    realsense_die "cloned librealsense ${head} does not match ${COREBRUM_REALSENSE_SRC_COMMIT}"
  fi
  cores="$(nproc)"
  platlib="$(python3 -c 'import sysconfig; print(sysconfig.get_path("platlib"))')"
  realsense_log "run: cmake configure and build pyrealsense2 (${cores} jobs). This is the aarch64 path."
  if ! cmake -S "${work}/librealsense" -B "${work}/build" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="${work}/prefix" \
    -DPYTHON_INSTALL_DIR="${platlib}/pyrealsense2" \
    -DBUILD_PYTHON_BINDINGS=ON \
    -DBUILD_EXAMPLES=OFF \
    -DBUILD_GRAPHICAL_EXAMPLES=OFF \
    -DBUILD_TOOLS=OFF \
    -DBUILD_RS2_ALL=OFF \
    -DBUILD_WITH_OPENMP=OFF \
    -DCHECK_FOR_UPDATES=OFF \
    -DFORCE_RSUSB_BACKEND=ON \
    -DBUILD_SHARED_LIBS=OFF \
    -DPYTHON_EXECUTABLE="$(command -v python3)" \
    -DPython_EXECUTABLE="$(command -v python3)"; then
    rm -rf "$work"
    realsense_die "could not configure the RealSense Python bindings"
  fi
  if ! cmake --build "${work}/build" -j "$cores"; then
    rm -rf "$work"
    realsense_die "could not build the RealSense Python bindings"
  fi
  if ! cmake --install "${work}/build"; then
    rm -rf "$work"
    realsense_die "could not install the RealSense Python bindings"
  fi
  rm -rf "$work"
  python3 -c 'import pyrealsense2' || realsense_die "Python ${py} could not import the built pyrealsense2"
}

realsense_install_python() {
  local py arch
  py="$(python3 -c 'import sys; print("%d.%d" % sys.version_info[:2])')"
  arch="$(uname -m)"
  if [[ "$arch" == "x86_64" ]]; then
    case "$py" in
      3.10 | 3.11 | 3.12 | 3.13 | 3.14) ;;
      *)
        realsense_die "Python ${py} has no x86_64 wheel for pyrealsense2 ${COREBRUM_REALSENSE_PY}. That release publishes wheels for Python 3.10 through 3.14."
        ;;
    esac
    realsense_install_python_wheel "$py"
    return 0
  fi
  if [[ "$arch" != "aarch64" ]]; then
    realsense_die "RealSense install supports x86_64 and aarch64 (found ${arch})"
  fi
  case "$py" in
    3.10 | 3.12)
      realsense_log "aarch64 wheel is published for Python ${py}"
      realsense_install_python_wheel "$py"
      ;;
    3.11 | 3.13 | 3.14)
      realsense_build_python_bindings "$py"
      ;;
    *)
      realsense_die "Python ${py} has no aarch64 pyrealsense2 ${COREBRUM_REALSENSE_PY} wheel, and the source build is pinned for Python 3.11, 3.13, and 3.14."
      ;;
  esac
}

realsense_apply_arch_packages() {
  local arch
  arch="$(uname -m)"
  case "$arch" in
    x86_64)
      REALSENSE_SUITE="$1"
      ;;
    aarch64)
      REALSENSE_SDK_VERSION="$COREBRUM_REALSENSE_ARM64_SDK_VERSION"
      REALSENSE_SUITE="$COREBRUM_REALSENSE_ARM64_SUITE"
      REALSENSE_DKMS_VERSION=""
      realsense_log "aarch64 RealSense SDK ${REALSENSE_SDK_VERSION} from the ${REALSENSE_SUITE} suite; not using the x86_64 pin"
      ;;
    *)
      realsense_die "RealSense install supports x86_64 and aarch64 (found ${arch})"
      ;;
  esac
}

realsense_install_main() {
  local codename
  [[ "$(id -u)" -eq 0 ]] || realsense_die "RealSense install requires root"
  [[ -f /etc/apt/sources.list.d/ros2.sources ]] || realsense_die "the ROS apt source is missing; choose ROS 2 in Super+Space first, then select RealSense again"
  codename="$(realsense_codename)"
  realsense_versions "$codename"
  realsense_apply_arch_packages "$codename"
  realsense_add_repo "$REALSENSE_SUITE"
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
