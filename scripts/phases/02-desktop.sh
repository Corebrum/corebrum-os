#!/usr/bin/env bash
# Phase 2 desktop profile. Sourced by scripts/install.sh.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  echo "Run ./scripts/install.sh --profile desktop" >&2
  exit 1
fi

corebrum_phase_desktop() {
  local manifest="${COREBRUM_ROOT}/manifests/packages/desktop.txt"
  local candidate
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
  corebrum_apt_install --no-install-recommends "${packages[@]}"
  corebrum_install_desktop_files
  corebrum_install_greetd_config
  corebrum_enable_desktop_login
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    corebrum_log "desktop profile dry-run complete"
  else
    corebrum_log "desktop profile install complete; reboot for the greetd login on VT 7 (Ctrl+Alt+F7). VT 1 stays a text console (Ctrl+Alt+F1)"
  fi
}
