#!/usr/bin/env bash
# Phase 2 desktop profile. Sourced by scripts/install.sh.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  echo "Run ./scripts/install.sh --profile desktop" >&2
  exit 1
fi

corebrum_phase_desktop() {
  local manifest="${COREBRUM_ROOT}/manifests/packages/desktop.txt"
  local candidate codename locker
  local -a packages=()
  candidate="$(corebrum_archive_candidate sway)"
  if corebrum_candidate_installable "$candidate"; then
    corebrum_log "sway candidate ${candidate}"
  elif [[ "${DRY_RUN:-0}" -eq 0 ]]; then
    corebrum_die "sway has no installable candidate in the Ubuntu archive"
  else
    corebrum_log "sway is not in the Ubuntu archive"
  fi
  corebrum_load_manifest "$manifest" packages
  # swaybg, swayidle, and wlgreet are in the Ubuntu 24.04 and 26.04 archives.
  # Both releases lock with gtklock 4. Noble builds it. Resolute uses the archive.
  # wlgreet runs inside the greeter Sway. A missing greeter keeps agreety.
  codename="$(corebrum_read_os_release_field /etc/os-release VERSION_CODENAME || true)"
  locker="$(corebrum_lock_package "$codename")" || corebrum_die "no lock program is selected for ${codename:-unknown}"
  for pkg in swaybg swayidle wlgreet "$locker"; do
    if [[ "$pkg" == "gtklock" ]] && corebrum_gtklock_from_source "$codename"; then
      corebrum_log "gtklock ${COREBRUM_GTKLOCK_VERSION} will be built from source"
      continue
    fi
    candidate="$(corebrum_archive_candidate "$pkg")"
    if corebrum_candidate_installable "$candidate"; then
      corebrum_log "${pkg} candidate ${candidate}"
      packages+=("$pkg")
    else
      corebrum_log "${pkg} is not in the archive; skipping"
    fi
  done
  corebrum_apt_install --no-install-recommends "${packages[@]}"
  corebrum_install_desktop_files
  corebrum_build_gtklock
  corebrum_install_node
  corebrum_enable_getting_started
  corebrum_install_greetd_config
  corebrum_enable_desktop_login
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    corebrum_log "desktop profile dry-run complete"
  else
    corebrum_log "desktop profile install complete; reboot for the greetd login on VT 7 (Ctrl+Alt+F7). VT 1 stays a text console (Ctrl+Alt+F1)"
  fi
}
