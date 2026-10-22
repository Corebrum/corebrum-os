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

# Logs the Quickshell decision and where Hyprland will come from.
corebrum_desktop_plan() {
  local quickshell_candidate hyprland_ubuntu shell
  quickshell_candidate="$(corebrum_archive_candidate quickshell)"
  hyprland_ubuntu="$(corebrum_ubuntu_archive_version hyprland)"
  shell="$(corebrum_shell_for_candidate "$quickshell_candidate")"
  if [[ "$shell" == "quickshell" ]]; then
    corebrum_log "quickshell candidate ${quickshell_candidate} is in the Ubuntu archive; this phase ships no Quickshell config, so the session uses Waybar, Fuzzel, and the Corebrum app grid"
  else
    corebrum_log "quickshell is not in the Ubuntu archive; using Waybar, Fuzzel, and the Corebrum app grid"
  fi
  if [[ -n "$hyprland_ubuntu" ]]; then
    corebrum_log "hyprland candidate ${hyprland_ubuntu} from the Ubuntu archive"
  else
    corebrum_log "hyprland is not in the Ubuntu archive; using ppa:cppiber/hyprland for Hyprland and the libraries it requires. Other packages from that archive stay pinned below Ubuntu"
  fi
}

corebrum_install_desktop_files() {
  local root="$COREBRUM_ROOT"
  corebrum_install_file "${root}/config/hypr/hyprland.conf" /etc/corebrum/hypr/hyprland.conf 644
  corebrum_install_file "${root}/config/hypr/hyprlock.conf" /etc/corebrum/hypr/hyprlock.conf 644
  corebrum_install_file "${root}/config/greetd/gtkgreet.css" /etc/corebrum/greetd/gtkgreet.css 644
  corebrum_install_file "${root}/config/waybar/config.json" /etc/corebrum/waybar/config.json 644
  corebrum_install_file "${root}/config/waybar/style.css" /etc/corebrum/waybar/style.css 644
  corebrum_install_file "${root}/config/kitty/kitty.conf" /etc/corebrum/kitty/kitty.conf 644
  corebrum_install_file "${root}/config/fuzzel/fuzzel.ini" /etc/corebrum/fuzzel/fuzzel.ini 644
  corebrum_install_file "${root}/config/mako/config" /etc/corebrum/mako/config 644
  corebrum_install_file "${root}/config/wofi/config" /etc/corebrum/wofi/config 644
  corebrum_install_file "${root}/config/wofi/style.css" /etc/corebrum/wofi/style.css 644
  corebrum_install_file "${root}/apps/dashboard/tiles.conf" /etc/corebrum/dashboard/tiles.conf 644
  corebrum_install_file "${root}/scripts/lib/grid.sh" /usr/local/lib/corebrum/grid.sh 644
  corebrum_install_file "${root}/scripts/desktop/corebrum-session.sh" /usr/local/bin/corebrum-session 755
  corebrum_install_file "${root}/scripts/desktop/corebrum-greeter.sh" /usr/local/bin/corebrum-greeter 755
  corebrum_install_file "${root}/scripts/desktop/corebrum-lock.sh" /usr/local/bin/corebrum-lock 755
  corebrum_install_file "${root}/scripts/desktop/corebrum-terminal.sh" /usr/local/bin/corebrum-terminal 755
  corebrum_install_file "${root}/scripts/desktop/corebrum-grid.sh" /usr/local/bin/corebrum-grid 755
  corebrum_install_file "${root}/scripts/desktop/corebrum-launcher.sh" /usr/local/bin/corebrum-launcher 755
  corebrum_install_file "${root}/scripts/desktop/corebrum-ros-menu.sh" /usr/local/bin/corebrum-ros-menu 755
  corebrum_install_file "${root}/scripts/desktop/corebrum-realsense-menu.sh" /usr/local/bin/corebrum-realsense-menu 755
  corebrum_install_file "${root}/scripts/desktop/corebrum-chromium-menu.sh" /usr/local/bin/corebrum-chromium-menu 755
  corebrum_install_file "${root}/scripts/desktop/corebrum-agents-menu.sh" /usr/local/bin/corebrum-agents-menu 755
  corebrum_install_file "${root}/scripts/desktop/corebrum-wallpaper-menu.sh" /usr/local/bin/corebrum-wallpaper-menu 755
  corebrum_install_file "${root}/scripts/desktop/corebrum-keys-menu.sh" /usr/local/bin/corebrum-keys-menu 755
  corebrum_install_file "${root}/config/systemd/user/hyprpaper.service.d/corebrum.conf" /etc/systemd/user/hyprpaper.service.d/corebrum.conf 644
  if [[ "${DRY_RUN:-0}" -eq 0 ]]; then
    rm -f /usr/local/bin/corebrum-waypaper-menu
  fi
  corebrum_install_file "${root}/manifests/packages/agents.conf" /etc/corebrum/agents.conf 644
  corebrum_install_file "${root}/scripts/desktop/corebrum-realsense-install.sh" /usr/local/lib/corebrum/realsense-install.sh 755
  corebrum_install_file "${root}/manifests/packages/ros-tools.conf" /etc/corebrum/ros-tools.conf 644
  corebrum_install_file "${root}/scripts/ros/corebrum-ros-shell.sh" /usr/local/bin/corebrum-ros-shell 755
  corebrum_install_file "${root}/apps/corebrum-grid.desktop" /usr/local/share/applications/corebrum-grid.desktop 644
}

# gtkgreet needs cage. Ubuntu 24.04 has neither gtkgreet nor hyprlock.
corebrum_graphical_login_available() {
  local gtkgreet cage
  gtkgreet="$(corebrum_archive_candidate gtkgreet)"
  cage="$(corebrum_archive_candidate cage)"
  corebrum_candidate_installable "$gtkgreet" && corebrum_candidate_installable "$cage"
}

corebrum_install_greetd_config() {
  local src="${COREBRUM_ROOT}/config/greetd/config.toml"
  local dest="/etc/greetd/config.toml"
  if corebrum_graphical_login_available; then
    src="${COREBRUM_ROOT}/config/greetd/gtkgreet.toml"
    corebrum_log "login greeter: gtkgreet in cage"
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

corebrum_enable_desktop_login() {
  local current
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
/etc/corebrum/hypr/hyprland.conf
/etc/corebrum/hypr/hyprlock.conf
/etc/corebrum/greetd/gtkgreet.css
/etc/corebrum/waybar/config.json
/etc/corebrum/waybar/style.css
/etc/corebrum/kitty/kitty.conf
/etc/corebrum/fuzzel/fuzzel.ini
/etc/corebrum/mako/config
/etc/corebrum/wofi/config
/etc/corebrum/wofi/style.css
/etc/corebrum/dashboard/tiles.conf
/usr/local/lib/corebrum/grid.sh
/usr/local/bin/corebrum-session
/usr/local/bin/corebrum-greeter
/usr/local/bin/corebrum-lock
/usr/local/bin/corebrum-terminal
/usr/local/bin/corebrum-grid
/usr/local/bin/corebrum-launcher
/usr/local/bin/corebrum-ros-menu
/usr/local/bin/corebrum-realsense-menu
/usr/local/bin/corebrum-chromium-menu
/usr/local/bin/corebrum-agents-menu
/usr/local/bin/corebrum-wallpaper-menu
/usr/local/bin/corebrum-waypaper-menu
/usr/local/bin/corebrum-keys-menu
/etc/systemd/user/hyprpaper.service.d/corebrum.conf
/etc/corebrum/agents.conf
/usr/local/lib/corebrum/realsense-install.sh
/etc/corebrum/ros-tools.conf
/usr/local/bin/corebrum-ros-shell
/usr/local/share/applications/corebrum-grid.desktop
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
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    corebrum_uninstall_node
    realsense_remove_repo
    corebrum_log "dry-run: disable greetd.service when the unit exists"
    corebrum_log "dry-run: restore /etc/greetd/config.toml from the recorded backup when present"
    corebrum_log "dry-run: restore the previous default target when one was recorded"
    corebrum_log "dry-run: remove Corebrum desktop files under /etc/corebrum, /usr/local/bin, /usr/local/lib/corebrum, and /usr/local/share/applications; leave /usr/local/bin/corebrum"
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

  while IFS= read -r path; do
    [[ -n "$path" ]] || continue
    if [[ -e "$path" ]]; then
      corebrum_backup_file "$path"
      rm -f "$path"
      corebrum_log "removed ${path}"
    fi
  done < <(corebrum_desktop_managed_paths)

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
    2>/dev/null || true
  corebrum_log "desktop uninstall complete; Ubuntu packages were left installed; reboot to leave the graphical login"
}
