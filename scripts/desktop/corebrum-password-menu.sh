#!/usr/bin/env bash
# Super+Space Setup → Password. Change the logged-in account password with passwd.
set -euo pipefail

corebrum_password_die() {
  printf 'corebrum-password-menu: %s\n' "$1" >&2
  exit 1
}

corebrum_password_data_dir() {
  local root="${XDG_RUNTIME_DIR:-/tmp/corebrum-launcher-${UID}}"
  printf '%s\n' "${root}/corebrum"
}

corebrum_password_refresh() {
  local dir
  dir="$(corebrum_password_data_dir)/applications"
  mkdir -p "$dir"
  cat >"${dir}/corebrum-password.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Password
GenericName=Password
Comment=Change this account password
Keywords=password;passwd;account;login;credentials;
Exec=/usr/local/bin/corebrum-password-menu open
Icon=dialog-password
Terminal=false
Categories=Settings;System;
StartupNotify=false
EOF
}

corebrum_password_open() {
  if [[ "${COREBRUM_PASSWORD_STUB:-0}" == 1 ]]; then
    printf 'passwd\n'
    return 0
  fi
  command -v passwd >/dev/null 2>&1 || corebrum_password_die "passwd is not installed"
  command -v corebrum-terminal >/dev/null 2>&1 || corebrum_password_die "corebrum-terminal is not installed"
  # passwd must talk to a TTY. Ask for the current password, then the new one twice.
  exec /usr/local/bin/corebrum-terminal bash -c '
set +e
passwd
ec=$?
set -e
printf "\n"
if [ "$ec" -eq 0 ]; then
  printf "Password updated.\n"
else
  printf "Password was not changed (%s).\n" "$ec"
fi
read -r -p "Press Enter to close. "
exit "$ec"
'
}

usage() {
  cat <<'EOF'
Usage: corebrum-password-menu refresh|open|data-dir
EOF
}

cmd="${1:-}"
case "$cmd" in
  refresh) corebrum_password_refresh ;;
  open) corebrum_password_open ;;
  data-dir) corebrum_password_data_dir ;;
  -h | --help | help) usage ;;
  *)
    usage >&2
    exit 1
    ;;
esac
