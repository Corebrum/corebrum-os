#!/usr/bin/env bash
# Locale, time sync, and optional OpenSSH. Source this file; do not execute it.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  echo "source scripts/lib/system.sh from another script" >&2
  exit 1
fi

corebrum_backup_file() {
  local path="$1"
  local stamp dest
  COREBRUM_LAST_BACKUP=""
  [[ -e "$path" ]] || return 0
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    corebrum_log "dry-run: backup ${path}"
    return 0
  fi
  stamp="$(date +%Y%m%d-%H%M%S)"
  dest="/var/log/corebrum/backups/${stamp}-$(basename "$path")"
  mkdir -p /var/log/corebrum/backups
  cp -a "$path" "$dest"
  COREBRUM_LAST_BACKUP="$dest"
  export COREBRUM_LAST_BACKUP
  corebrum_log "backed up ${path} to ${dest}"
}

corebrum_locale_present() {
  locale -a | grep -Eiq '^en_US\.(utf8|utf-8)$'
}

corebrum_ensure_locale() {
  local gen="/etc/locale.gen"
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    corebrum_log "dry-run: ensure locale en_US.UTF-8 is generated"
    corebrum_log "dry-run: set LANG=en_US.UTF-8 only when /etc/default/locale has no LANG"
    return 0
  fi
  if [[ -f "$gen" ]] && grep -qE '^en_US\.UTF-8 UTF-8$' "$gen"; then
    corebrum_log "locale line already enabled in ${gen}"
  elif [[ -f "$gen" ]] && grep -qE '^# *en_US\.UTF-8 UTF-8$' "$gen"; then
    corebrum_backup_file "$gen"
    sed -i -E 's/^# *(en_US\.UTF-8 UTF-8)$/\1/' "$gen"
    corebrum_log "enabled en_US.UTF-8 in ${gen}"
  else
    if [[ -f "$gen" ]]; then
      corebrum_backup_file "$gen"
    fi
    printf 'en_US.UTF-8 UTF-8\n' >>"$gen"
    corebrum_log "appended en_US.UTF-8 to ${gen}"
  fi
  if corebrum_locale_present; then
    corebrum_log "locale en_US.UTF-8 already generated"
  else
    corebrum_log "run: locale-gen en_US.UTF-8"
    locale-gen en_US.UTF-8
  fi
  if [[ -f /etc/default/locale ]] && grep -qE '^LANG=' /etc/default/locale; then
    corebrum_log "keeping existing LANG in /etc/default/locale"
  else
    if [[ -f /etc/default/locale ]]; then
      corebrum_backup_file /etc/default/locale
    fi
    printf 'LANG=en_US.UTF-8\n' >>/etc/default/locale
    corebrum_log "set LANG=en_US.UTF-8 in /etc/default/locale"
  fi
}

corebrum_ensure_ntp() {
  local ntp
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    corebrum_log "dry-run: ensure systemd-timesyncd NTP is enabled"
    return 0
  fi
  if ! command -v timedatectl >/dev/null 2>&1; then
    corebrum_die "timedatectl is missing; the base profile expects systemd"
  fi
  ntp="$(timedatectl show -p NTP --value 2>/dev/null || true)"
  if [[ "$ntp" == "yes" ]]; then
    corebrum_log "NTP already enabled"
    return 0
  fi
  corebrum_log "run: timedatectl set-ntp true"
  timedatectl set-ntp true
}

corebrum_enable_ssh() {
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    corebrum_log "dry-run: systemctl enable --now ssh"
    return 0
  fi
  corebrum_log "run: systemctl enable --now ssh"
  systemctl enable --now ssh
}
