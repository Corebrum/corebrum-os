# shellcheck shell=sh
# Managed by Corebrum OS.
# Login shells and Corebrum terminals source this file.
# It does not write to the home directory.
export NVM_DIR="/usr/local/nvm"
if [ -n "${BASH_VERSION:-}" ] && [ -s "${NVM_DIR}/nvm.sh" ]; then
  case $- in
    *u*) _corebrum_node_nounset=1 ;;
    *) _corebrum_node_nounset=0 ;;
  esac
  set +u
  # nvm.sh reads unset variables. A load failure must not skip the restore below.
  # shellcheck disable=SC1091
  . "${NVM_DIR}/nvm.sh" || true
  if [ "${_corebrum_node_nounset}" -eq 1 ]; then
    set -u
  fi
  unset _corebrum_node_nounset
fi
