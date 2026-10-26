#!/usr/bin/env bash
# Ask the operator before an agent installs or creates a skill.
# Prints Yes and exits 0 only when the operator agrees. Anything else is no.
set -euo pipefail

corebrum_skills_approve_finish() {
  local answer="$1"
  if [[ "$answer" == "Yes" ]]; then
    printf 'Yes\n'
    exit 0
  fi
  printf 'No\n'
  exit 1
}

if [[ -n "${COREBRUM_SKILLS_APPROVE_ANSWER:-}" ]]; then
  case "${COREBRUM_SKILLS_APPROVE_ANSWER}" in
    yes | Yes) corebrum_skills_approve_finish "Yes" ;;
    *) corebrum_skills_approve_finish "No" ;;
  esac
fi

title="${1:-Skill}"
author="${2:-}"
detail="${3:-}"
text="$(printf '%s\n%s\n\n%s' "$title" "$author" "$detail")"

if command -v hyprland-dialog >/dev/null 2>&1; then
  out="$(timeout 120 hyprland-dialog \
    --title "Allow skill" \
    --apptitle "Corebrum" \
    --text "$text" \
    --buttons "Yes;No" 2>/dev/null || true)"
  first="$(printf '%s\n' "$out" | head -n 1 | tr -d '[:space:]')"
  corebrum_skills_approve_finish "$first"
fi

if command -v fuzzel >/dev/null 2>&1; then
  choice="$(printf 'Yes\nNo\n' | timeout 120 fuzzel \
    --config /etc/corebrum/fuzzel/fuzzel.ini \
    --dmenu \
    --prompt 'Allow skill  ' \
    --width 48 \
    --lines 4 || true)"
  choice="$(printf '%s' "$choice" | tr -d '[:space:]')"
  corebrum_skills_approve_finish "$choice"
fi

corebrum_skills_approve_finish "No"
