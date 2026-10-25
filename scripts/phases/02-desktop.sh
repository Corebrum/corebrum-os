#!/usr/bin/env bash
# Phase 2 desktop profile. Sourced by scripts/install.sh.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  echo "Run ./scripts/install.sh --profile desktop" >&2
  exit 1
fi

corebrum_phase_desktop() {
  local manifest="${COREBRUM_ROOT}/manifests/packages/desktop.txt"
  local candidate ubuntu_hyprpaper codename
  local -a packages=()
  corebrum_install_hyprland_ppa
  if [[ "${DRY_RUN:-0}" -eq 0 ]]; then
    candidate="$(corebrum_archive_candidate hyprland)"
    if ! corebrum_candidate_installable "$candidate"; then
      corebrum_die "hyprland has no installable candidate after checking the Ubuntu archive and ppa:cppiber/hyprland"
    fi
    corebrum_log "hyprland candidate ${candidate}"
  fi
  corebrum_load_manifest "$manifest" packages
  # Ubuntu splits the default wallpaper out of hyprland. noble's PPA build does
  # not publish this package; resolute does, and --no-install-recommends will
  # not pull it in on its own.
  candidate="$(corebrum_archive_candidate hyprland-backgrounds)"
  if corebrum_candidate_installable "$candidate"; then
    corebrum_log "hyprland-backgrounds candidate ${candidate}; installing the default wallpaper assets"
    packages+=(hyprland-backgrounds)
  else
    corebrum_log "hyprland-backgrounds is not in the archive; skipping the split wallpaper package"
  fi
  # hyprpaper draws the session wallpaper. The menu only lists images.
  # resolute publishes hyprpaper in universe. noble does not, so that
  # release installs the build from the pinned Hyprland PPA.
  ubuntu_hyprpaper="$(corebrum_ubuntu_archive_version hyprpaper)"
  if corebrum_candidate_installable "$ubuntu_hyprpaper"; then
    corebrum_log "hyprpaper candidate ${ubuntu_hyprpaper} from the Ubuntu archive"
    packages+=(hyprpaper)
  else
    codename="$(corebrum_read_os_release_field /etc/os-release VERSION_CODENAME || true)"
    if [[ "$codename" == "noble" ]]; then
      corebrum_log "hyprpaper is not in the Ubuntu archive; installing hyprpaper from ppa:cppiber/hyprland"
      packages+=(hyprpaper)
    else
      corebrum_log "hyprpaper is not in the Ubuntu archive; the session wallpaper stays unset"
    fi
  fi
  # hyprlock and gtkgreet are in Ubuntu 26.04. Ubuntu 24.04 publishes neither,
  # and that release keeps the agreety greeter.
  for pkg in hyprlock gtkgreet cage; do
    candidate="$(corebrum_archive_candidate "$pkg")"
    if corebrum_candidate_installable "$candidate"; then
      corebrum_log "${pkg} candidate ${candidate}"
      packages+=("$pkg")
    else
      corebrum_log "${pkg} is not in the archive; skipping"
    fi
  done
  # Hyprland looks for hyprland-dialog and warns when it is missing. That
  # binary is in hyprland-qtutils. Take it only from the Ubuntu archive.
  # The noble Hyprland PPA is not a source for this package.
  candidate="$(corebrum_ubuntu_archive_version hyprland-qtutils)"
  if corebrum_candidate_installable "$candidate"; then
    corebrum_log "hyprland-qtutils candidate ${candidate}"
    packages+=("hyprland-qtutils")
  else
    corebrum_log "hyprland-qtutils is not in the Ubuntu archive; Hyprland dialogs stay unavailable"
  fi
  # hypridle is in Ubuntu 26.04 with hyprlock. Ubuntu 24.04 publishes neither.
  # Do not install the idle daemon when there is no locker for it to run.
  candidate="$(corebrum_archive_candidate hypridle)"
  if corebrum_candidate_installable "$candidate" && corebrum_candidate_installable "$(corebrum_archive_candidate hyprlock)"; then
    corebrum_log "hypridle candidate ${candidate}"
    packages+=("hypridle")
  else
    corebrum_log "hypridle stays uninstalled; this archive has no hypridle and hyprlock pair"
  fi
  corebrum_apt_install --no-install-recommends "${packages[@]}"
  corebrum_install_desktop_files
  corebrum_install_node
  corebrum_install_greetd_config
  corebrum_enable_desktop_login
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    corebrum_log "desktop profile dry-run complete"
  else
    corebrum_log "desktop profile install complete; reboot for the greetd login on VT 7 (Ctrl+Alt+F7). VT 1 stays a text console (Ctrl+Alt+F1)"
  fi
}
