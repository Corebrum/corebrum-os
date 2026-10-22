#!/usr/bin/env bash
# Node.js 26.x, npm, and pnpm for the desktop profile. Source this file; do not execute it.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  echo "source scripts/lib/node.sh from another script" >&2
  exit 1
fi

# shellcheck source=files.sh
source "${COREBRUM_ROOT}/scripts/lib/files.sh"

# Pinned in manifests/versions/node.txt. Verified 2026-10-22.
COREBRUM_NVM_DIR="/usr/local/nvm"
COREBRUM_NVM_TAG="v0.40.8"
COREBRUM_NVM_COMMIT="a885b885fef16fac4bc544188fb25e9e37ae83e8"
COREBRUM_NVM_URL="https://github.com/nvm-sh/nvm.git"
COREBRUM_NODE_MAJOR="26"
COREBRUM_PNPM_VERSION="12.15.0"
COREBRUM_NODE_PROFILE_SRC="${COREBRUM_ROOT}/config/profile.d/corebrum-node.sh"
COREBRUM_NODE_PROFILE="/etc/profile.d/corebrum-node.sh"
COREBRUM_NODE_VERSION_FILE="/etc/corebrum/node/versions"
COREBRUM_NODE_BASHRC="/etc/bash.bashrc"
COREBRUM_NODE_BASHRC_BEGIN="# BEGIN Corebrum OS Node.js"
COREBRUM_NODE_BASHRC_END="# END Corebrum OS Node.js"

corebrum_node_relax() {
  COREBRUM_NODE_NOUNSET=0
  case $- in
    *u*) COREBRUM_NODE_NOUNSET=1 ;;
  esac
  set +u
}

corebrum_node_strict() {
  if [[ "${COREBRUM_NODE_NOUNSET:-0}" -eq 1 ]]; then
    set -u
  fi
}

corebrum_node_bashrc_block() {
  cat <<EOF
${COREBRUM_NODE_BASHRC_BEGIN}
# Interactive bash is not a login shell, so profile.d is not sourced.
if [ -f ${COREBRUM_NODE_PROFILE} ]; then
  . ${COREBRUM_NODE_PROFILE}
fi
${COREBRUM_NODE_BASHRC_END}
EOF
}

corebrum_node_index_has_major() {
  local index
  index="$(curl -fsSL --max-time 60 https://nodejs.org/dist/index.json)" \
    || corebrum_die "could not read the Node.js distribution index"
  if grep -Eq "\"version\"[[:space:]]*:[[:space:]]*\"v${COREBRUM_NODE_MAJOR}\\." <<<"$index"; then
    return 0
  fi
  return 1
}

corebrum_node_verify_nvm_tag() {
  local peeled
  peeled="$(GIT_TERMINAL_PROMPT=0 git ls-remote "$COREBRUM_NVM_URL" "refs/tags/${COREBRUM_NVM_TAG}^{}")" \
    || corebrum_die "could not read the nvm tag ${COREBRUM_NVM_TAG}"
  [[ "$peeled" == "${COREBRUM_NVM_COMMIT}"*$'\t'* ]] \
    || corebrum_die "nvm tag ${COREBRUM_NVM_TAG} resolved to '${peeled}', expected ${COREBRUM_NVM_COMMIT}"
}

corebrum_node_clone() {
  local head
  corebrum_log "run: git clone --depth 1 --branch ${COREBRUM_NVM_TAG} ${COREBRUM_NVM_URL} ${COREBRUM_NVM_DIR}"
  GIT_TERMINAL_PROMPT=0 git clone --depth 1 --branch "$COREBRUM_NVM_TAG" "$COREBRUM_NVM_URL" "$COREBRUM_NVM_DIR" \
    || corebrum_die "could not clone nvm ${COREBRUM_NVM_TAG}"
  head="$(git -C "$COREBRUM_NVM_DIR" rev-parse HEAD)"
  [[ "$head" == "$COREBRUM_NVM_COMMIT" ]] \
    || corebrum_die "cloned nvm ${head} does not match ${COREBRUM_NVM_COMMIT}"
  printf 'tag=%s\ncommit=%s\n' "$COREBRUM_NVM_TAG" "$COREBRUM_NVM_COMMIT" >"${COREBRUM_NVM_DIR}/.corebrum-managed"
  chmod 644 "${COREBRUM_NVM_DIR}/.corebrum-managed"
}

corebrum_node_ensure_checkout() {
  local head
  if [[ ! -d "$COREBRUM_NVM_DIR" ]]; then
    corebrum_node_clone
    return 0
  fi
  if [[ -f "${COREBRUM_NVM_DIR}/.corebrum-managed" ]]; then
    head="$(git -C "$COREBRUM_NVM_DIR" rev-parse HEAD 2>/dev/null || true)"
    if [[ "$head" == "$COREBRUM_NVM_COMMIT" ]]; then
      corebrum_log "unchanged: nvm ${COREBRUM_NVM_TAG} at ${COREBRUM_NVM_DIR}"
    else
      corebrum_log "nvm at ${COREBRUM_NVM_DIR} is ${head:-unknown}; expected ${COREBRUM_NVM_COMMIT}; leaving the checkout in place"
    fi
    return 0
  fi
  if [[ -z "$(ls -A "$COREBRUM_NVM_DIR")" ]]; then
    rmdir "$COREBRUM_NVM_DIR"
    corebrum_node_clone
    return 0
  fi
  corebrum_die "${COREBRUM_NVM_DIR} exists and is not a Corebrum nvm checkout; refusing to replace it"
}

corebrum_node_load_nvm() {
  local status
  [[ -s "${COREBRUM_NVM_DIR}/nvm.sh" ]] || corebrum_die "missing ${COREBRUM_NVM_DIR}/nvm.sh"
  export NVM_DIR="$COREBRUM_NVM_DIR"
  corebrum_node_relax
  set +e
  # shellcheck disable=SC1091
  . "${COREBRUM_NVM_DIR}/nvm.sh"
  status=$?
  set -e
  corebrum_node_strict
  [[ "$status" -eq 0 ]] || corebrum_die "could not load ${COREBRUM_NVM_DIR}/nvm.sh"
  declare -F nvm >/dev/null 2>&1 || corebrum_die "nvm did not load from ${COREBRUM_NVM_DIR}/nvm.sh"
}

corebrum_node_install_runtime() {
  local installed node_bin npm_bin pnpm_meta work
  corebrum_node_relax
  installed="$(nvm version "$COREBRUM_NODE_MAJOR" 2>/dev/null || true)"
  corebrum_node_strict
  if [[ "$installed" == v${COREBRUM_NODE_MAJOR}.* ]]; then
    corebrum_log "node ${installed} already installed"
  else
    corebrum_log "run: nvm install ${COREBRUM_NODE_MAJOR}"
    corebrum_node_relax
    nvm install "$COREBRUM_NODE_MAJOR"
    installed="$(nvm version "$COREBRUM_NODE_MAJOR" 2>/dev/null || true)"
    corebrum_node_strict
  fi
  [[ "$installed" == v${COREBRUM_NODE_MAJOR}.* ]] \
    || corebrum_die "Node.js ${COREBRUM_NODE_MAJOR}.x did not install (got ${installed:-nothing})"
  corebrum_node_relax
  nvm alias default "$COREBRUM_NODE_MAJOR" >/dev/null
  nvm use "$COREBRUM_NODE_MAJOR" >/dev/null
  corebrum_node_strict
  hash -r
  node_bin="$(command -v node || true)"
  npm_bin="$(command -v npm || true)"
  [[ -n "$node_bin" && -x "$node_bin" ]] || corebrum_die "node is not on PATH after nvm use ${COREBRUM_NODE_MAJOR}"
  [[ -n "$npm_bin" && -x "$npm_bin" ]] || corebrum_die "npm is not on PATH after installing Node.js ${installed}"
  [[ "$(dirname "$node_bin")" == "$(dirname "$npm_bin")" ]] \
    || corebrum_die "npm is not the copy shipped with ${node_bin}"
  [[ "$(node -v)" == v${COREBRUM_NODE_MAJOR}.* ]] || corebrum_die "node $(node -v) is not ${COREBRUM_NODE_MAJOR}.x"
  corebrum_log "node $(node -v); npm $(npm -v)"
  if [[ -x "$(dirname "$node_bin")/pnpm" ]]; then
    corebrum_log "pnpm $(pnpm -v) already installed"
  else
    pnpm_meta="$(curl -fsSL --max-time 60 "https://registry.npmjs.org/pnpm/${COREBRUM_PNPM_VERSION}")" \
      || corebrum_die "could not read pnpm ${COREBRUM_PNPM_VERSION} from the npm registry"
    grep -q "\"version\":\"${COREBRUM_PNPM_VERSION}\"" <<<"$pnpm_meta" \
      || corebrum_die "pnpm ${COREBRUM_PNPM_VERSION} is not on the npm registry"
    corebrum_log "run: npm install -g --allow-scripts=pnpm pnpm@${COREBRUM_PNPM_VERSION}"
    npm install -g --allow-scripts=pnpm "pnpm@${COREBRUM_PNPM_VERSION}"
    hash -r
  fi
  command -v pnpm >/dev/null 2>&1 || corebrum_die "pnpm is not on PATH"
  chmod -R a+rX "$COREBRUM_NVM_DIR"
  work="$(mktemp)"
  cat >"$work" <<EOF
nvm=${COREBRUM_NVM_TAG}
nvm_commit=${COREBRUM_NVM_COMMIT}
node=$(node -v)
npm=$(npm -v)
pnpm=$(pnpm -v)
EOF
  corebrum_install_file "$work" "$COREBRUM_NODE_VERSION_FILE" 644
  rm -f "$work"
}

corebrum_node_install_bashrc() {
  local tmp block
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    corebrum_log "dry-run: append the Node.js source block to ${COREBRUM_NODE_BASHRC} when it is absent"
    return 0
  fi
  [[ -f "$COREBRUM_NODE_BASHRC" ]] || corebrum_die "missing ${COREBRUM_NODE_BASHRC}"
  if grep -qF "$COREBRUM_NODE_BASHRC_BEGIN" "$COREBRUM_NODE_BASHRC"; then
    corebrum_log "unchanged: ${COREBRUM_NODE_BASHRC} already sources Node.js"
    return 0
  fi
  corebrum_backup_file "$COREBRUM_NODE_BASHRC"
  block="$(corebrum_node_bashrc_block)"
  tmp="$(mktemp)"
  cat "$COREBRUM_NODE_BASHRC" >"$tmp"
  printf '\n%s\n' "$block" >>"$tmp"
  install -m 644 "$tmp" "$COREBRUM_NODE_BASHRC"
  rm -f "$tmp"
  corebrum_log "updated ${COREBRUM_NODE_BASHRC} to source Node.js"
}

corebrum_node_remove_bashrc() {
  local tmp
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    corebrum_log "dry-run: remove the Node.js source block from ${COREBRUM_NODE_BASHRC} when present"
    return 0
  fi
  [[ -f "$COREBRUM_NODE_BASHRC" ]] || return 0
  if ! grep -qF "$COREBRUM_NODE_BASHRC_BEGIN" "$COREBRUM_NODE_BASHRC"; then
    return 0
  fi
  corebrum_backup_file "$COREBRUM_NODE_BASHRC"
  tmp="$(mktemp)"
  awk -v begin="$COREBRUM_NODE_BASHRC_BEGIN" -v end="$COREBRUM_NODE_BASHRC_END" '
    $0 == begin { skip = 1; next }
    $0 == end { skip = 0; next }
    skip != 1 { print }
  ' "$COREBRUM_NODE_BASHRC" >"$tmp"
  install -m 644 "$tmp" "$COREBRUM_NODE_BASHRC"
  rm -f "$tmp"
  corebrum_log "removed the Node.js source block from ${COREBRUM_NODE_BASHRC}"
}

corebrum_install_node() {
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    corebrum_log "dry-run: clone nvm ${COREBRUM_NVM_TAG} (${COREBRUM_NVM_COMMIT}) into ${COREBRUM_NVM_DIR} when that checkout is absent"
    corebrum_log "dry-run: install Node.js ${COREBRUM_NODE_MAJOR}.x with the npm shipped in that build, and alias it as the nvm default"
    corebrum_log "dry-run: npm install -g --allow-scripts=pnpm pnpm@${COREBRUM_PNPM_VERSION} when that Node installation has no pnpm"
    corebrum_install_file "$COREBRUM_NODE_PROFILE_SRC" "$COREBRUM_NODE_PROFILE" 644
    corebrum_node_install_bashrc
    return 0
  fi
  command -v curl >/dev/null 2>&1 || corebrum_die "curl is required to install Node.js"
  command -v git >/dev/null 2>&1 || corebrum_die "git is required to install nvm"
  corebrum_node_verify_nvm_tag
  corebrum_node_index_has_major \
    || corebrum_die "Node.js ${COREBRUM_NODE_MAJOR}.x is not listed on https://nodejs.org/dist/index.json"
  corebrum_node_ensure_checkout
  corebrum_node_load_nvm
  corebrum_node_install_runtime
  corebrum_install_file "$COREBRUM_NODE_PROFILE_SRC" "$COREBRUM_NODE_PROFILE" 644
  corebrum_node_install_bashrc
}

corebrum_uninstall_node() {
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    corebrum_log "dry-run: remove ${COREBRUM_NVM_DIR} when .corebrum-managed is present"
    corebrum_node_remove_bashrc
    return 0
  fi
  corebrum_node_remove_bashrc
  if [[ "$COREBRUM_NVM_DIR" != "/usr/local/nvm" ]]; then
    corebrum_die "refusing to remove ${COREBRUM_NVM_DIR}"
  fi
  if [[ -f "${COREBRUM_NVM_DIR}/.corebrum-managed" ]]; then
    rm -rf -- "$COREBRUM_NVM_DIR"
    corebrum_log "removed ${COREBRUM_NVM_DIR}"
  fi
}
