#!/usr/bin/env bash
# Phase 2 desktop helpers. Source this file; do not execute it.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  echo "source scripts/lib/desktop.sh from another script" >&2
  exit 1
fi

# shellcheck source=archive.sh
source "${COREBRUM_ROOT}/scripts/lib/archive.sh"
# shellcheck source=files.sh
source "${COREBRUM_ROOT}/scripts/lib/files.sh"
# shellcheck source=ppa.sh
source "${COREBRUM_ROOT}/scripts/lib/ppa.sh"
# shellcheck source=preflight.sh
source "${COREBRUM_ROOT}/scripts/lib/preflight.sh"
# shellcheck source=node.sh
source "${COREBRUM_ROOT}/scripts/lib/node.sh"
# shellcheck source=gtklock.sh
source "${COREBRUM_ROOT}/scripts/lib/gtklock.sh"
# shellcheck source=../desktop/corebrum-realsense-install.sh
source "${COREBRUM_ROOT}/scripts/desktop/corebrum-realsense-install.sh"

# 12 GiB. The desktop profile adds a compositor, a browser, and fonts on top of the base profile.
COREBRUM_DESKTOP_MIN_FREE_KIB=12582912

corebrum_desktop_disk_check() {
  local free_kib
  free_kib="$(corebrum_root_free_kib)"
  if ! corebrum_disk_is_sufficient "$free_kib" "$COREBRUM_DESKTOP_MIN_FREE_KIB"; then
    corebrum_die "desktop profile needs at least ${COREBRUM_DESKTOP_MIN_FREE_KIB} KiB free on / (have ${free_kib})"
  fi
  corebrum_log "desktop preflight: ${free_kib} KiB free on /"
}

# Logs the Quickshell decision and where Sway will come from.
corebrum_desktop_plan() {
  local quickshell_candidate sway_ubuntu shell
  quickshell_candidate="$(corebrum_archive_candidate quickshell)"
  sway_ubuntu="$(corebrum_ubuntu_archive_version sway)"
  shell="$(corebrum_shell_for_candidate "$quickshell_candidate")"
  if [[ "$shell" == "quickshell" ]]; then
    corebrum_log "quickshell candidate ${quickshell_candidate} is in the Ubuntu archive; this phase ships no Quickshell config, so the session uses Waybar, Fuzzel, and the Corebrum app grid"
  else
    corebrum_log "quickshell is not in the Ubuntu archive; using Waybar, Fuzzel, and the Corebrum app grid"
  fi
  if [[ -n "$sway_ubuntu" ]]; then
    corebrum_log "sway candidate ${sway_ubuntu} from the Ubuntu archive"
  else
    corebrum_log "sway is not in the Ubuntu archive"
  fi
}

# The Ubuntu firefox package is a transitional deb. Its preinst runs
# `snap install firefox` only while that deb is being unpacked and
# /run/snapd.socket already exists. The NVIDIA Jetson image ships the
# deb without the snap. Installing the same version again does not
# unpack it, so the browser stays missing. See docs/decisions/0092-firefox-snap.md.
corebrum_install_firefox_snap() {
  local bin="${COREBRUM_FIREFOX_BIN:-/snap/bin/firefox}"
  if [[ -x "$bin" ]]; then
    corebrum_log "firefox snap is already installed"
    return 0
  fi
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    corebrum_log "dry-run: snap install firefox"
    return 0
  fi
  corebrum_log "run: snap install firefox"
  snap install firefox
}

# Replace packaged Hyprland walls with the images in this repo. A diversion keeps
# a later hyprland-backgrounds upgrade from writing the upstream files back.
corebrum_install_wallpapers() {
  local name src dest
  for name in wall0.png wall1.png wall2.png wall3.png; do
    src="${COREBRUM_ROOT}/config/hypr/wallpapers/${name}"
    dest="/usr/share/hypr/${name}"
    if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
      corebrum_log "dry-run: divert ${dest} aside, then install ${src}"
      continue
    fi
    [[ -f "$src" ]] || corebrum_die "missing wallpaper ${src}"
    if ! dpkg-divert --list "$dest" 2>/dev/null | grep -Fq "diversion of ${dest} to "; then
      corebrum_log "run: dpkg-divert --local --rename --divert ${dest}.hyprland --add ${dest}"
      dpkg-divert --local --rename --divert "${dest}.hyprland" --add "$dest"
    fi
    corebrum_install_file "$src" "$dest" 644
  done
}

corebrum_remove_wallpapers() {
  local name dest
  for name in wall0.png wall1.png wall2.png wall3.png; do
    dest="/usr/share/hypr/${name}"
    if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
      corebrum_log "dry-run: remove ${dest} and restore the diverted package file when one exists"
      continue
    fi
    if dpkg-divert --list "$dest" 2>/dev/null | grep -Fq "diversion of ${dest} to "; then
      rm -f "$dest"
      if [[ -e "${dest}.hyprland" ]]; then
        dpkg-divert --local --rename --remove "$dest"
      else
        dpkg-divert --local --remove "$dest"
      fi
      corebrum_log "restored ${dest}"
    fi
  done
}

# The package enables hyprpaper.service for every graphical session. That
# unit starts hyprpaper with no config path. The session starts it later
# with the image chosen from the wallpaper menu.
corebrum_disable_packaged_hyprpaper() {
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    corebrum_log "dry-run: systemctl --global disable hyprpaper.service"
    return 0
  fi
  if [[ ! -f /usr/lib/systemd/user/hyprpaper.service ]]; then
    corebrum_log "hyprpaper.service is not installed; not disabling it"
    return 0
  fi
  corebrum_log "run: systemctl --global disable hyprpaper.service"
  systemctl --global disable hyprpaper.service || corebrum_log "could not disable hyprpaper.service"
}

corebrum_install_getting_started() {
  local src name
  local dir="${COREBRUM_ROOT}/config/getting-started"
  for src in "${dir}"/*; do
    [[ -f "$src" ]] || continue
    name="$(basename "$src")"
    corebrum_install_file "$src" "/usr/share/corebrum/getting-started/${name}" 644
  done
  corebrum_install_file \
    "${COREBRUM_ROOT}/scripts/desktop/corebrum-getting-started-server.js" \
    /usr/local/lib/corebrum/getting-started-server.js \
    644
  corebrum_install_file \
    "${COREBRUM_ROOT}/scripts/desktop/corebrum-getting-started.sh" \
    /usr/local/bin/corebrum-getting-started \
    755
  corebrum_install_file \
    "${COREBRUM_ROOT}/config/systemd/corebrum-getting-started.service" \
    /etc/systemd/system/corebrum-getting-started.service \
    644
  corebrum_install_file \
    "${COREBRUM_ROOT}/config/firefox/policies.json" \
    /etc/firefox/policies/policies.json \
    644
}

# Node 26 is installed later in the desktop phase. Start the page after that.
corebrum_enable_getting_started() {
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    corebrum_log "dry-run: systemctl daemon-reload"
    corebrum_log "dry-run: systemctl enable corebrum-getting-started.service when Node.js 26 is installed"
    corebrum_log "dry-run: systemctl restart corebrum-getting-started.service"
    return 0
  fi
  corebrum_log "run: systemctl daemon-reload"
  systemctl daemon-reload
  corebrum_log "run: systemctl enable corebrum-getting-started.service"
  systemctl enable corebrum-getting-started.service
  corebrum_log "run: systemctl restart corebrum-getting-started.service"
  systemctl restart corebrum-getting-started.service
}

corebrum_disable_getting_started() {
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    corebrum_log "dry-run: systemctl disable --now corebrum-getting-started.service"
    return 0
  fi
  systemctl disable --now corebrum-getting-started.service >/dev/null 2>&1 \
    || corebrum_log "could not disable corebrum-getting-started.service"
}

corebrum_install_desktop_files() {
  local root="$COREBRUM_ROOT"
  local codename locker
  codename="$(corebrum_read_os_release_field /etc/os-release VERSION_CODENAME || true)"
  locker="$(corebrum_lock_package "$codename" || true)"
  corebrum_install_file "${root}/config/sway/config" /etc/corebrum/sway/config 644
  corebrum_install_file "${root}/config/gtklock/config.ini" /etc/corebrum/gtklock/config.ini 644
  corebrum_install_file "${root}/config/gtklock/style.css" /etc/corebrum/gtklock/style.css 644
  corebrum_install_file "${root}/config/gtklock/layout.ui" /etc/corebrum/gtklock/layout.ui 644
  corebrum_install_file "${root}/config/sway/idle.conf" /etc/corebrum/sway/idle.conf 644
  corebrum_install_file "${root}/config/greetd/wlgreet.toml" /etc/corebrum/greetd/wlgreet.toml 644
  corebrum_install_file "${root}/config/greetd/login.css" /etc/corebrum/greetd/login.css 644
  corebrum_install_file "${root}/config/greetd/sway-config" /etc/corebrum/greetd/sway-config 644
  corebrum_install_file "${root}/config/waybar/config.json" /etc/corebrum/waybar/config.json 644
  corebrum_install_file "${root}/config/waybar/style.css" /etc/corebrum/waybar/style.css 644
  corebrum_install_file "${root}/config/kitty/kitty.conf" /etc/corebrum/kitty/kitty.conf 644
  corebrum_install_file "${root}/config/fuzzel/fuzzel.ini" /etc/corebrum/fuzzel/fuzzel.ini 644
  corebrum_install_file "${root}/config/mako/config" /etc/corebrum/mako/config 644
  corebrum_install_file "${root}/config/wofi/config" /etc/corebrum/wofi/config 644
  corebrum_install_file "${root}/config/wofi/style.css" /etc/corebrum/wofi/style.css 644
  corebrum_install_file "${root}/apps/dashboard/tiles.conf" /etc/corebrum/dashboard/tiles.conf 644
  corebrum_install_file "${root}/scripts/lib/grid.sh" /usr/local/lib/corebrum/grid.sh 644
  corebrum_install_file "${root}/scripts/desktop/corebrum-node-path.sh" /usr/local/lib/corebrum/node-path.sh 644
  corebrum_install_file "${root}/scripts/lib/vc4.sh" /usr/local/lib/corebrum/vc4.sh 644
  corebrum_install_file "${root}/scripts/desktop/corebrum-drm.sh" /usr/local/lib/corebrum/drm.sh 644
  corebrum_install_file "${root}/scripts/desktop/corebrum-autotile.sh" /usr/local/bin/corebrum-autotile 755
  corebrum_install_file "${root}/scripts/desktop/corebrum-tile.sh" /usr/local/bin/corebrum-tile 755
  corebrum_install_file "${root}/scripts/desktop/corebrum-session.sh" /usr/local/bin/corebrum-session 755
  corebrum_install_file "${root}/scripts/desktop/corebrum-setup.sh" /usr/local/bin/corebrum-setup 755
  corebrum_install_file "${root}/scripts/desktop/corebrum-greetd.sh" /usr/local/bin/corebrum-greetd 755
  corebrum_install_file "${root}/scripts/desktop/corebrum-greeter.sh" /usr/local/bin/corebrum-greeter 755
  corebrum_install_file "${root}/scripts/desktop/corebrum-login.py" /usr/local/bin/corebrum-login 755
  corebrum_install_file "${root}/scripts/desktop/corebrum-login-logo.py" /usr/local/bin/corebrum-login-logo 755
  corebrum_install_file "${root}/scripts/desktop/corebrum-lock.sh" /usr/local/bin/corebrum-lock 755
  corebrum_install_file "${root}/scripts/desktop/corebrum-terminal.sh" /usr/local/bin/corebrum-terminal 755
  corebrum_install_file "${root}/scripts/desktop/corebrum-grid.sh" /usr/local/bin/corebrum-grid 755
  corebrum_install_file "${root}/scripts/desktop/corebrum-launcher.sh" /usr/local/bin/corebrum-launcher 755
  corebrum_install_file "${root}/scripts/desktop/corebrum-launcher.py" /usr/local/lib/corebrum/corebrum-launcher.py 644
  corebrum_install_file "${root}/scripts/desktop/corebrum-ros-menu.sh" /usr/local/bin/corebrum-ros-menu 755
  corebrum_install_file "${root}/scripts/desktop/corebrum-realsense-menu.sh" /usr/local/bin/corebrum-realsense-menu 755
  corebrum_install_file "${root}/scripts/desktop/corebrum-agenticros-menu.sh" /usr/local/bin/corebrum-agenticros-menu 755
  corebrum_install_file "${root}/scripts/desktop/corebrum-skills-menu.sh" /usr/local/bin/corebrum-skills-menu 755
  corebrum_install_file "${root}/scripts/desktop/corebrum-arc-menu.sh" /usr/local/bin/corebrum-arc-menu 755
  corebrum_install_file "${root}/scripts/desktop/corebrum-skills-approve.sh" /usr/local/bin/corebrum-skills-approve 755
  corebrum_install_file "${root}/scripts/desktop/corebrum-agenticros-status.sh" /usr/local/bin/corebrum-agenticros-status 755
  corebrum_install_file "${root}/scripts/desktop/corebrum-chromium-menu.sh" /usr/local/bin/corebrum-chromium-menu 755
  corebrum_install_file "${root}/scripts/desktop/corebrum-ollama-menu.sh" /usr/local/bin/corebrum-ollama-menu 755
  corebrum_install_file "${root}/scripts/desktop/corebrum-zenoh-fleet-menu.sh" /usr/local/bin/corebrum-zenoh-fleet-menu 755
  corebrum_install_file "${root}/scripts/desktop/corebrum-agents-menu.sh" /usr/local/bin/corebrum-agents-menu 755
  corebrum_install_file "${root}/scripts/desktop/corebrum-updates-menu.sh" /usr/local/bin/corebrum-updates-menu 755
  corebrum_install_file "${root}/scripts/desktop/corebrum-wallpaper-menu.sh" /usr/local/bin/corebrum-wallpaper-menu 755
  corebrum_install_file "${root}/scripts/desktop/corebrum-keys-menu.sh" /usr/local/bin/corebrum-keys-menu 755
  corebrum_install_file "${root}/scripts/desktop/corebrum-docs-menu.sh" /usr/local/bin/corebrum-docs-menu 755
  corebrum_install_file "${root}/scripts/desktop/corebrum-edit-keys.sh" /usr/local/bin/corebrum-edit-keys 755
  corebrum_install_file "${root}/scripts/desktop/corebrum-osd.sh" /usr/local/bin/corebrum-osd 755
  corebrum_install_file "${root}/scripts/desktop/corebrum-autolock.sh" /usr/local/bin/corebrum-autolock 755
  corebrum_install_file "${root}/scripts/desktop/corebrum-power-menu.sh" /usr/local/bin/corebrum-power-menu 755
  corebrum_install_file "${root}/scripts/desktop/corebrum-vnc-menu.sh" /usr/local/bin/corebrum-vnc-menu 755
  corebrum_install_file "${root}/scripts/desktop/corebrum-vnc-proxy.py" /usr/local/bin/corebrum-vnc-proxy 755
  corebrum_install_file "${root}/scripts/desktop/corebrum-record.sh" /usr/local/bin/corebrum-record 755
  corebrum_install_file "${root}/scripts/desktop/corebrum-camera-preview.py" /usr/local/lib/corebrum/corebrum-camera-preview.py 755
  corebrum_install_file "${root}/config/systemd/user/hyprpaper.service.d/corebrum.conf" /etc/systemd/user/hyprpaper.service.d/corebrum.conf 644
  corebrum_disable_packaged_hyprpaper
  corebrum_install_file "${root}/config/systemd/user/hypridle.service.d/corebrum.conf" /etc/systemd/user/hypridle.service.d/corebrum.conf 644
  if [[ "${DRY_RUN:-0}" -eq 0 ]]; then
    rm -f /etc/corebrum/sway/swaylock.conf
  else
    corebrum_log "dry-run: remove /etc/corebrum/sway/swaylock.conf"
  fi
  if [[ "${DRY_RUN:-0}" -eq 0 ]]; then
    rm -f /usr/local/bin/corebrum-waypaper-menu
  fi
  corebrum_install_file "${root}/manifests/packages/agents.conf" /etc/corebrum/agents.conf 644
  corebrum_install_file "${root}/scripts/desktop/corebrum-realsense-install.sh" /usr/local/lib/corebrum/realsense-install.sh 755
  corebrum_install_file "${root}/scripts/desktop/corebrum-agenticros-install.sh" /usr/local/lib/corebrum/agenticros-install.sh 755
  corebrum_install_file "${root}/scripts/desktop/corebrum-agenticros-with-ros.sh" /usr/local/lib/corebrum/agenticros-with-ros.sh 755
  corebrum_install_file "${root}/manifests/packages/ros-tools.conf" /etc/corebrum/ros-tools.conf 644
  corebrum_install_file "${root}/scripts/ros/corebrum-ros-shell.sh" /usr/local/bin/corebrum-ros-shell 755
  corebrum_install_file "${root}/apps/corebrum-grid.desktop" /usr/local/share/applications/corebrum-grid.desktop 644
  corebrum_install_file "${root}/config/brand/logo.png" /usr/share/corebrum/logo.png 644
  corebrum_install_file "${root}/config/brand/icon.png" /usr/share/corebrum/icon.png 644
  corebrum_install_file "${root}/config/brand/agenticros.png" /usr/share/corebrum/agenticros.png 644
  corebrum_install_file "${root}/config/brand/ollama.png" /usr/share/corebrum/ollama.png 644
  corebrum_install_file "${root}/config/brand/ros.png" /usr/share/corebrum/ros.png 644
  corebrum_install_file "${root}/config/brand/zenoh.png" /usr/share/corebrum/zenoh.png 644
  corebrum_install_file "${root}/config/brand/realsense.png" /usr/share/corebrum/realsense.png 644
  corebrum_install_file "${root}/config/brand/agents.png" /usr/share/corebrum/agents.png 644
  corebrum_install_agent_marks "$root"
  corebrum_install_getting_started
  corebrum_install_wallpapers
}

# Marks from https://corebrum.com/#agents. The welcome page lists them under the tool marks.
corebrum_install_agent_marks() {
  local root="$1"
  local name
  for name in antigravity.png claude.png codex.png cursor.png grok.webp hermes.png openclaw.png; do
    corebrum_install_file "${root}/config/brand/agents/${name}" "/usr/share/corebrum/agents/${name}" 644
  done
}

# wlgreet is in the Ubuntu 24.04 and 26.04 archives and depends on sway,
# which this profile installs. The greeter compositor is that Sway.
corebrum_graphical_login_available() {
  local wlgreet
  wlgreet="$(corebrum_archive_candidate wlgreet)"
  corebrum_candidate_installable "$wlgreet"
}

corebrum_install_greetd_config() {
  local src="${COREBRUM_ROOT}/config/greetd/config.toml"
  local dest="/etc/greetd/config.toml"
  if corebrum_graphical_login_available; then
    src="${COREBRUM_ROOT}/config/greetd/gtkgreet.toml"
    corebrum_log "login greeter: wlgreet"
  else
    corebrum_log "login greeter: agreety"
  fi
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    corebrum_log "dry-run: install ${dest} from ${src} and keep the first backup of the packaged file"
    return 0
  fi
  corebrum_install_file "$src" "$dest" 644
  if [[ -n "${COREBRUM_LAST_BACKUP:-}" ]]; then
    corebrum_state_set_once greetd_backup "${COREBRUM_LAST_BACKUP}"
  fi
}

# NVIDIA L4T images and Ubuntu Desktop leave GDM as display-manager.service.
# greetd aliases that same name, so enable fails until the symlink is recorded
# and removed. The handoff runs on every machine that has a non-greetd symlink,
# including AGX Orin, Orin Nano, Orin NX, Thor, and Ubuntu Desktop on x86-64
# and other ARM machines. Ubuntu Server has no such symlink, so its greetd
# enable path stays the same.
COREBRUM_DISPLAY_MANAGER_LINK="${COREBRUM_DISPLAY_MANAGER_LINK:-/etc/systemd/system/display-manager.service}"

corebrum_release_other_display_manager() {
  local link="$COREBRUM_DISPLAY_MANAGER_LINK"
  local target unit
  if [[ ! -L "$link" && ! -e "$link" ]]; then
    return 0
  fi
  if [[ ! -L "$link" ]]; then
    if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
      corebrum_log "dry-run: ${link} is not a symlink; install would stop"
      return 0
    fi
    corebrum_die "${link} is not a symlink; not replacing it"
  fi
  target="$(readlink "$link")"
  unit="$(basename "$target")"
  if [[ "$unit" == "greetd.service" ]]; then
    return 0
  fi
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    corebrum_log "dry-run: record and remove ${link} (${unit}) so greetd can become the display manager"
    return 0
  fi
  corebrum_state_set_once previous_display_manager "$target"
  corebrum_log "removing ${link} (${unit}) so greetd can become the display manager"
  rm -f -- "$link"
}

corebrum_restore_display_manager() {
  local link="$COREBRUM_DISPLAY_MANAGER_LINK"
  local previous
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    corebrum_log "dry-run: restore ${link} from the recorded target when that link is absent"
    return 0
  fi
  if ! previous="$(corebrum_state_get previous_display_manager)"; then
    return 0
  fi
  if [[ -L "$link" || -e "$link" ]]; then
    corebrum_log "leaving ${link} in place"
    return 0
  fi
  ln -s -- "$previous" "$link"
  corebrum_log "restored ${link} -> ${previous}"
}

# /dev/dri and the Jetson NVIDIA nodes (nvmap, nvhost) are group video or
# render, and the NVIDIA nodes have no logind uaccess tag. _greetd is created
# with only its own group, so Sway cannot open the GPU. A later login picks
# up the new groups; the running greeter does not.
corebrum_greetd_gpu_groups() {
  local user="${COREBRUM_GREETD_USER:-_greetd}"
  local group groups
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    corebrum_log "dry-run: add ${user} to video and render when those groups exist and the user does not"
    return 0
  fi
  if ! id "$user" >/dev/null 2>&1; then
    corebrum_log "greetd user ${user} is not present; skipping GPU groups"
    return 0
  fi
  groups="$(id -nG "$user")"
  for group in video render; do
    if ! getent group "$group" >/dev/null 2>&1; then
      continue
    fi
    if [[ " $groups " == *" $group "* ]]; then
      continue
    fi
    corebrum_log "run: usermod -aG ${group} ${user}"
    usermod -aG "$group" "$user"
  done
}

corebrum_enable_desktop_login() {
  local current
  corebrum_greetd_gpu_groups
  corebrum_release_other_display_manager
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    corebrum_log "dry-run: systemctl enable greetd.service"
    corebrum_log "dry-run: set default target to graphical.target when it is not already"
    return 0
  fi
  corebrum_log "run: systemctl enable greetd.service"
  systemctl enable greetd.service
  current="$(systemctl get-default)"
  if [[ "$current" == "graphical.target" ]]; then
    corebrum_log "default target already graphical.target"
    return 0
  fi
  corebrum_state_set_once previous_default_target "$current"
  corebrum_log "run: systemctl set-default graphical.target"
  systemctl set-default graphical.target
}

corebrum_desktop_managed_paths() {
  cat <<'EOF'
/etc/corebrum/sway/config
/etc/corebrum/sway/swaylock.conf
/usr/local/bin/gtklock
/usr/local/lib/libgtk-session-lock.so
/usr/local/lib/libgtk-session-lock.so.0
/usr/local/lib/libgtk-session-lock.so.0.2.0
/usr/local/lib/pkgconfig/gtk-session-lock-0.pc
/usr/local/include/gtk-session-lock/gtk-session-lock.h
/etc/corebrum/gtklock/config.ini
/etc/corebrum/gtklock/style.css
/etc/corebrum/gtklock/layout.ui
/etc/corebrum/sway/idle.conf
/etc/corebrum/greetd/wlgreet.toml
/etc/corebrum/greetd/login.css
/etc/corebrum/greetd/sway-config
/usr/local/bin/corebrum-autotile
/usr/local/bin/corebrum-tile
/etc/corebrum/waybar/config.json
/etc/corebrum/waybar/style.css
/etc/corebrum/kitty/kitty.conf
/etc/corebrum/fuzzel/fuzzel.ini
/etc/corebrum/mako/config
/etc/corebrum/wofi/config
/etc/corebrum/wofi/style.css
/etc/corebrum/dashboard/tiles.conf
/usr/local/lib/corebrum/grid.sh
/usr/local/lib/corebrum/node-path.sh
/usr/local/lib/corebrum/vc4.sh
/usr/local/lib/corebrum/drm.sh
/usr/local/bin/corebrum-session
/usr/local/bin/corebrum-setup
/usr/local/bin/corebrum-greetd
/usr/local/bin/corebrum-greeter
/usr/local/bin/corebrum-login
/usr/local/bin/corebrum-login-logo
/usr/local/bin/corebrum-lock
/usr/local/bin/corebrum-terminal
/usr/local/bin/corebrum-grid
/usr/local/bin/corebrum-launcher
/usr/local/lib/corebrum/corebrum-launcher.py
/usr/local/bin/corebrum-ros-menu
/usr/local/bin/corebrum-realsense-menu
/usr/local/bin/corebrum-agenticros-menu
/usr/local/bin/corebrum-skills-menu
/usr/local/bin/corebrum-arc-menu
/usr/local/bin/corebrum-skills-approve
/usr/local/bin/corebrum-agenticros-status
/usr/local/bin/corebrum-chromium-menu
/usr/local/bin/corebrum-ollama-menu
/usr/local/bin/corebrum-zenoh-fleet-menu
/usr/local/bin/corebrum-agents-menu
/usr/local/bin/corebrum-updates-menu
/usr/local/bin/corebrum-wallpaper-menu
/usr/local/bin/corebrum-waypaper-menu
/usr/local/bin/corebrum-keys-menu
/usr/local/bin/corebrum-docs-menu
/usr/local/bin/corebrum-edit-keys
/usr/local/bin/corebrum-osd
/usr/local/bin/corebrum-autolock
/usr/local/bin/corebrum-power-menu
/usr/local/bin/corebrum-vnc-menu
/usr/local/bin/corebrum-vnc-proxy
/usr/local/bin/corebrum-record
/usr/local/lib/corebrum/corebrum-camera-preview.py
/etc/systemd/user/hyprpaper.service.d/corebrum.conf
/etc/systemd/user/hypridle.service.d/corebrum.conf
/etc/corebrum/agents.conf
/usr/local/lib/corebrum/realsense-install.sh
/usr/local/lib/corebrum/agenticros-install.sh
/usr/local/lib/corebrum/agenticros-with-ros.sh
/etc/corebrum/ros-tools.conf
/usr/local/bin/corebrum-ros-shell
/usr/local/share/applications/corebrum-grid.desktop
/usr/share/corebrum/logo.png
/usr/share/corebrum/icon.png
/usr/share/corebrum/agenticros.png
/usr/share/corebrum/ollama.png
/usr/share/corebrum/ros.png
/usr/share/corebrum/zenoh.png
/usr/share/corebrum/realsense.png
/usr/share/corebrum/agents.png
/usr/share/corebrum/agents/antigravity.png
/usr/share/corebrum/agents/claude.png
/usr/share/corebrum/agents/codex.png
/usr/share/corebrum/agents/cursor.png
/usr/share/corebrum/agents/grok.webp
/usr/share/corebrum/agents/hermes.png
/usr/share/corebrum/agents/openclaw.png
/usr/share/corebrum/getting-started/index.html
/usr/share/corebrum/getting-started/physical-ai.html
/usr/share/corebrum/getting-started/desktop.html
/usr/share/corebrum/getting-started/ros.html
/usr/share/corebrum/getting-started/zenoh.html
/usr/share/corebrum/getting-started/realsense.html
/usr/share/corebrum/getting-started/agenticros.html
/usr/share/corebrum/getting-started/agents.html
/usr/share/corebrum/getting-started/mission.html
/usr/share/corebrum/getting-started/keybindings.html
/usr/share/corebrum/getting-started/corebrum-cli.html
/usr/share/corebrum/getting-started/agenticros-cli.html
/usr/share/corebrum/getting-started/nav.html
/usr/share/corebrum/getting-started/style.css
/usr/local/lib/corebrum/getting-started-server.js
/usr/local/bin/corebrum-getting-started
/etc/systemd/system/corebrum-getting-started.service
/etc/firefox/policies/policies.json
/etc/profile.d/corebrum-node.sh
/etc/corebrum/node/versions
EOF
}

corebrum_uninstall_desktop() {
  local backup previous path dest
  if [[ "${DRY_RUN:-0}" -eq 0 && "$(id -u)" -ne 0 ]]; then
    corebrum_die "desktop uninstall requires root; pass --dry-run to preview"
  fi
  # shellcheck source=services.sh
  source "${COREBRUM_ROOT}/scripts/lib/services.sh"
  corebrum_uninstall_services
  corebrum_disable_getting_started
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    corebrum_uninstall_node
    realsense_remove_repo
    corebrum_log "dry-run: disable greetd.service when the unit exists"
    corebrum_restore_display_manager
    corebrum_log "dry-run: restore /etc/greetd/config.toml from the recorded backup when present"
    corebrum_log "dry-run: restore the previous default target when one was recorded"
    corebrum_log "dry-run: remove Corebrum desktop files under /etc/corebrum, /usr/local/bin, /usr/local/lib/corebrum, and /usr/local/share/applications; leave /usr/local/bin/corebrum"
    corebrum_log "dry-run: remove /usr/share/corebrum/logo.png"
    corebrum_log "dry-run: remove /usr/share/corebrum/icon.png"
    corebrum_log "dry-run: remove /usr/share/corebrum/agenticros.png"
    corebrum_log "dry-run: remove /usr/share/corebrum/ollama.png"
    corebrum_log "dry-run: remove /usr/share/corebrum/ros.png"
    corebrum_log "dry-run: remove /usr/share/corebrum/zenoh.png"
    corebrum_log "dry-run: remove /usr/share/corebrum/realsense.png"
    corebrum_log "dry-run: remove /usr/share/corebrum/agents.png"
    corebrum_log "dry-run: remove /usr/share/corebrum/agents"
    corebrum_log "dry-run: remove /usr/share/corebrum/getting-started"
    corebrum_log "dry-run: remove /etc/firefox/policies/policies.json"
    corebrum_log "dry-run: remove /usr/local/bin/corebrum-getting-started"
    corebrum_log "dry-run: remove /etc/systemd/system/corebrum-getting-started.service"
    corebrum_remove_wallpapers
    corebrum_remove_hyprland_ppa
    corebrum_log "desktop uninstall dry-run complete"
    return 0
  fi

  dest="/etc/greetd/config.toml"
  if backup="$(corebrum_state_get greetd_backup)" && [[ -f "$backup" ]]; then
    if [[ -f "$dest" ]]; then
      corebrum_backup_file "$dest"
    fi
    cp -a "$backup" "$dest"
    corebrum_log "restored ${dest} from ${backup}"
  elif [[ -f "$dest" ]] && grep -q "Managed by Corebrum OS" "$dest"; then
    corebrum_install_file "${COREBRUM_ROOT}/config/greetd/ubuntu-default.toml" "$dest" 644
  fi

  corebrum_remove_wallpapers
  while IFS= read -r path; do
    [[ -n "$path" ]] || continue
    if [[ -e "$path" ]]; then
      corebrum_backup_file "$path"
      rm -f "$path"
      corebrum_log "removed ${path}"
    fi
  done < <(corebrum_desktop_managed_paths)
  systemctl daemon-reload || corebrum_log "could not reload systemd"

  if previous="$(corebrum_state_get previous_default_target)"; then
    corebrum_log "run: systemctl set-default ${previous}"
    systemctl set-default "$previous"
  fi
  corebrum_remove_hyprland_ppa
  corebrum_uninstall_node
  realsense_remove_repo
  if systemctl cat greetd.service >/dev/null 2>&1; then
    corebrum_log "run: systemctl disable greetd.service"
    systemctl disable greetd.service
  else
    corebrum_log "greetd.service is not installed"
  fi
  corebrum_restore_display_manager
  rm -f "$COREBRUM_STATE_FILE"
  rmdir \
    /etc/corebrum/hypr \
    /etc/corebrum/waybar \
    /etc/corebrum/kitty \
    /etc/corebrum/fuzzel \
    /etc/corebrum/mako \
    /etc/corebrum/wofi \
    /etc/corebrum/dashboard \
    /etc/corebrum/node \
    /etc/corebrum \
    /usr/local/lib/corebrum \
    /usr/local/share/applications \
    /usr/share/corebrum/getting-started \
    /usr/share/corebrum/agents \
    /usr/share/corebrum \
    /etc/firefox/policies \
    /etc/firefox \
    2>/dev/null || true
  corebrum_log "desktop uninstall complete; Ubuntu packages were left installed; reboot to leave the graphical login"
}
