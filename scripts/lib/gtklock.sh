#!/usr/bin/env bash
# Ubuntu 24.04 builds gtklock 4. The archive package is 2.1 and cannot lock Sway.
# Source this file; do not execute it.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  echo "source scripts/lib/gtklock.sh from another script" >&2
  exit 1
fi

# shellcheck source=files.sh
source "${COREBRUM_ROOT}/scripts/lib/files.sh"

# Pinned in manifests/versions/gtklock.txt. Verified 2026-10-28.
COREBRUM_GTK_SESSION_LOCK_VERSION="0.2.0"
COREBRUM_GTK_SESSION_LOCK_URL="https://github.com/Cu3PO42/gtk-session-lock/archive/refs/tags/v0.2.0.tar.gz"
COREBRUM_GTK_SESSION_LOCK_SHA256="a4245c6930580c15ed263b9a7bb7e39f47693baec78be1026b4e0e28b233cb4e"
COREBRUM_GTKLOCK_VERSION="4.0.0"
COREBRUM_GTKLOCK_URL="https://github.com/jovanlanik/gtklock/archive/refs/tags/v4.0.0.tar.gz"
COREBRUM_GTKLOCK_SHA256="db20bf27bd5dd01901ea1753c89c170777dd7cf8fca19130cf90f5f4e3fb9633"

corebrum_gtklock_fetch() {
  local url="$1"
  local dest="$2"
  local sum="$3"
  if ! curl -fsSL --max-time 120 -o "$dest" "$url"; then
    corebrum_die "could not download ${url}"
  fi
  if ! echo "${sum}  ${dest}" | sha256sum -c - >/dev/null; then
    corebrum_die "checksum mismatch for ${url}"
  fi
}

corebrum_gtklock_compile() {
  local src="$1"
  shift
  local build="${src}/build"
  (
    cd "$src"
    meson setup "$build" --prefix=/usr/local --libdir=lib "$@"
    meson compile -C "$build"
    meson install -C "$build"
  )
}

# Noble's archive gtklock cannot lock Sway. Resolute's archive gtklock can.
corebrum_build_gtklock() {
  local codename work session_src gtklock_src
  codename="$(corebrum_read_os_release_field /etc/os-release VERSION_CODENAME || true)"
  if ! corebrum_gtklock_from_source "$codename"; then
    return 0
  fi
  if corebrum_gtklock_v4_path >/dev/null 2>&1 && [[ -f /etc/pam.d/gtklock ]]; then
    corebrum_log "gtklock ${COREBRUM_GTKLOCK_VERSION} is already installed"
    return 0
  fi
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    corebrum_log "dry-run: build gtk-session-lock ${COREBRUM_GTK_SESSION_LOCK_VERSION} and gtklock ${COREBRUM_GTKLOCK_VERSION} into /usr/local"
    corebrum_log "dry-run: install /etc/pam.d/gtklock"
    return 0
  fi
  corebrum_apt_install --no-install-recommends \
    build-essential meson ninja-build pkg-config gettext \
    libwayland-dev libgtk-3-dev libpam0g-dev wayland-protocols ca-certificates curl
  work="$(mktemp -d /tmp/corebrum-gtklock.XXXXXX)"
  corebrum_log "run: download gtk-session-lock ${COREBRUM_GTK_SESSION_LOCK_VERSION}"
  corebrum_gtklock_fetch "$COREBRUM_GTK_SESSION_LOCK_URL" "${work}/gtk-session-lock.tar.gz" "$COREBRUM_GTK_SESSION_LOCK_SHA256"
  corebrum_log "run: download gtklock ${COREBRUM_GTKLOCK_VERSION}"
  corebrum_gtklock_fetch "$COREBRUM_GTKLOCK_URL" "${work}/gtklock.tar.gz" "$COREBRUM_GTKLOCK_SHA256"
  tar -xzf "${work}/gtk-session-lock.tar.gz" -C "$work"
  tar -xzf "${work}/gtklock.tar.gz" -C "$work"
  session_src="${work}/gtk-session-lock-${COREBRUM_GTK_SESSION_LOCK_VERSION}"
  gtklock_src="${work}/gtklock-${COREBRUM_GTKLOCK_VERSION}"
  [[ -d "$session_src" && -d "$gtklock_src" ]] || corebrum_die "gtklock source archives did not contain the expected directories"
  corebrum_log "run: build gtk-session-lock ${COREBRUM_GTK_SESSION_LOCK_VERSION}"
  corebrum_gtklock_compile "$session_src" \
    -Dintrospection=false -Dvapi=false -Dexamples=false -Ddocs=false -Dtests=false
  ldconfig
  corebrum_log "run: build gtklock ${COREBRUM_GTKLOCK_VERSION}"
  PKG_CONFIG_PATH="/usr/local/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}" \
    corebrum_gtklock_compile "$gtklock_src" -Dman-pages=disabled
  corebrum_install_file "${COREBRUM_ROOT}/config/pam.d/gtklock" /etc/pam.d/gtklock 644
  rm -rf "$work"
  if ! corebrum_gtklock_v4_path >/dev/null 2>&1; then
    corebrum_die "gtklock ${COREBRUM_GTKLOCK_VERSION} did not install"
  fi
  corebrum_log "installed gtklock ${COREBRUM_GTKLOCK_VERSION}"
}

# The lock screen glitches from this module. Login uses the same clock in
# corebrum-login.py. Both releases build it. The archive gtklock loads it.
corebrum_build_glitch_module() {
  local src dest tmp
  local -a cflags libs
  src="${COREBRUM_ROOT}/scripts/desktop/corebrum-glitch-module.c"
  dest="/usr/local/lib/corebrum/libcorebrum-glitch.so"
  if [[ ! -f "$src" ]]; then
    corebrum_die "missing ${src}"
  fi
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    corebrum_log "dry-run: build ${dest}"
    return 0
  fi
  if ! command -v gcc >/dev/null 2>&1 || ! pkg-config --exists gtk+-3.0; then
    corebrum_apt_install --no-install-recommends gcc pkg-config libgtk-3-dev
  fi
  install -d -m 0755 /usr/local/lib/corebrum
  read -r -a cflags < <(pkg-config --cflags gtk+-3.0)
  read -r -a libs < <(pkg-config --libs gtk+-3.0)
  tmp="${dest}.tmp"
  corebrum_log "run: gcc -shared -fPIC -o ${dest}"
  if ! gcc -shared -fPIC -O2 -Wall -Wextra -Werror -o "$tmp" "$src" "${cflags[@]}" "${libs[@]}"; then
    rm -f "$tmp"
    corebrum_die "could not build ${dest}"
  fi
  mv -f "$tmp" "$dest"
  chmod 644 "$dest"
}
