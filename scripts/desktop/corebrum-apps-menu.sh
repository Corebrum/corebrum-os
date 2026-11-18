#!/usr/bin/env bash
# Super+Space → Robot → Corebrum Apps.
set -euo pipefail

pick() {
  local prompt="$1"
  shift
  fuzzel --config /etc/corebrum/fuzzel/fuzzel.ini --dmenu --prompt "$prompt  " --width 72 --lines 12 "$@"
}

pick_app() {
  local prompt="$1" rows="$2" index selection
  local -a entries
  mapfile -t entries <<<"$rows"
  index="$(pick "$prompt" --index <<<"${rows//$'\t'/    }")" || return 1
  [[ "$index" =~ ^(0|[1-9][0-9]*)$ && "$index" -lt "${#entries[@]}" ]] || return 1
  selection="${entries[index]}"
  printf '%s\n' "${selection%%$'\t'*}"
}

notify() {
  notify-send "Corebrum Apps" "$1"
}

review() {
  local app="$1" details
  details="$(corebrum apps info "$app")" || return
  jq -r '
    "\(.title) — \(.description)",
    "Source: \(.source)",
    "",
    (.releases[] | "Version \(.version)", (
      .targets[] |
      "  Ubuntu \(.ubuntu) · \(.arch)",
      "    Tested on \(.hardware | join(", "))",
      (.requirements[] | "    " + .),
      ((.commands // []) | select(length > 0) | "    Commands: " + join(", "))
    ), "")
  ' <<<"$details"
  local answer
  read -r -p "Install the newest compatible release for this account? [y/N] " answer || return 0
  if [[ "$answer" == [yY] ]]; then
    corebrum apps install "$app"
  fi
}

if [[ "${1:-}" == review ]]; then
  review "$2"
  exit
fi

choice="$(printf '%s\n' 'Search marketplace' 'Run installed app' | pick 'Corebrum Apps')" || exit 0
case "$choice" in
  'Search marketplace')
    if ! rows="$(corebrum apps search 2>&1)"; then
      notify "$rows"
      exit 1
    fi
    [[ -n "$rows" ]] || { notify 'No apps are listed in the marketplace.'; exit 0; }
    app="$(pick_app 'Search Corebrum Apps' "$rows")" || exit 0
    exec corebrum-terminal --hold -- "$0" review "$app"
    ;;
  'Run installed app')
    if ! rows="$(corebrum apps list 2>&1)"; then
      notify "$rows"
      exit 1
    fi
    [[ -n "$rows" ]] || { notify 'No Corebrum Apps are installed for this account.'; exit 0; }
    app="$(pick_app 'Run Corebrum App' "$rows")" || exit 0
    exec corebrum-terminal --hold -- corebrum apps run "$app"
    ;;
esac
