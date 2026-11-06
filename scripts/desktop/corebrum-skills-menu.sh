#!/usr/bin/env bash
# Super+Space Skills entry. Lists, searches, installs, and removes Corebrum Synapse skills.
# Refresh only writes the desktop row. It does not install a skill.
set -euo pipefail

corebrum_skills_ready() {
  if [[ "${COREBRUM_SKILLS_STUB:-0}" == 1 ]]; then
    [[ "${COREBRUM_SKILLS_READY:-0}" == 1 ]]
    return
  fi
  [[ -x /usr/local/bin/synapse && -f "${HOME}/.synapse/config.json" ]]
}

corebrum_skills_data_dir() {
  local root="${XDG_RUNTIME_DIR:-/tmp/corebrum-launcher-${UID}}"
  printf '%s\n' "${root}/corebrum"
}

corebrum_skills_refresh() {
  local dir dest
  dir="$(corebrum_skills_data_dir)/applications"
  dest="${dir}/corebrum-skills.desktop"
  mkdir -p "$dir"
  if ! corebrum_skills_ready; then
    rm -f "$dest"
    return 0
  fi
  cat >"$dest" <<'EOF'
[Desktop Entry]
Type=Application
Name=Corebrum Skills
GenericName=Corebrum Skills
Comment=Corebrum Synapse skills on this machine
Keywords=skills;synapse
Exec=/usr/local/bin/corebrum-skills-menu open
Icon=/usr/share/corebrum/icon.png
Terminal=false
Categories=Science;Development;
StartupNotify=false
EOF
}

corebrum_skills_labels() {
  printf '%s\n' "List" "Search" "Install" "Remove"
}

# Map skill text to operator-facing stack hints. Does not start those stacks.
corebrum_skills_dep_hints() {
  local text="${1,,}"
  local -a hints=()
  [[ -n "$text" ]] || return 0

  if [[ "$text" =~ navigate_to|navigate_through|nav2|/navigate|wander|explore ]]; then
    hints+=("This skill needs Nav2. Install or launch it from Super+Space Robot → ROS. The skill does not start that stack.")
  fi
  if [[ "$text" =~ pick_object|moveit ]]; then
    hints+=("This skill needs MoveIt. Install or launch it from Super+Space Robot → ROS. The skill does not start that stack.")
  fi
  if [[ "$text" =~ dock_to_charger|opennav|docking ]]; then
    hints+=("This skill needs OpenNav docking. Bring that stack up yourself. The skill does not start it.")
  fi
  if [[ "$text" =~ start_slam|stop_slam|save_map|load_map|rtab ]]; then
    hints+=("This skill needs RTAB-Map. Bring mapping up yourself. The skill does not start that stack.")
  fi
  if [[ "$text" =~ follow_person|follow.me|follow_me ]]; then
    hints+=("This skill needs the on-robot follow node. Bring it up yourself. The skill does not start it.")
  fi
  if [[ "$text" =~ detect_humans|object.detection|detection ]]; then
    hints+=("This skill needs a detection publisher. Bring it up yourself. The skill does not start it.")
  fi
  if [[ "$text" =~ realsense|d435|d455 ]]; then
    hints+=("This skill expects RealSense. Start it from Super+Space Robot → RealSense when needed.")
  fi

  local hint
  for hint in "${hints[@]+"${hints[@]}"}"; do
    printf '%s\n' "$hint"
  done
}

corebrum_skills_listing_text() {
  local ref="$1" owner skill url
  if [[ "${COREBRUM_SKILLS_STUB:-0}" == 1 ]]; then
    printf '%s\n' "${COREBRUM_SKILLS_LISTING:-}"
    return 0
  fi
  [[ "$ref" == */* && "$ref" != @* ]] || return 0
  owner="${ref%%/*}"
  skill="${ref#*/}"
  [[ -n "$owner" && -n "$skill" && "$skill" != */* ]] || return 0
  url="https://skills.corebrum.com/api/skills/${owner}/${skill}"
  curl -fsSL --max-time 5 "$url" 2>/dev/null | python3 -c "$(cat <<'PY'
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    raise SystemExit(0)
parts = [
    str(data.get("displayName") or ""),
    str(data.get("description") or ""),
    " ".join(str(x) for x in (data.get("keywords") or [])),
    " ".join(str(x) for x in (data.get("capabilityIds") or [])),
]
for cap in data.get("capabilities") or []:
    if isinstance(cap, dict):
        parts.append(str(cap.get("id") or ""))
        parts.append(str(cap.get("description") or ""))
        impl = cap.get("implementation") or {}
        if isinstance(impl, dict):
            parts.append(str(impl.get("package") or ""))
            parts.append(str(impl.get("action") or ""))
print(" ".join(parts))
PY
)" 2>/dev/null || true
}

corebrum_skills_needs_ros_menu() {
  local text="${1,,}"
  [[ "$text" =~ nav2|moveit|opennav|rtab|navigate|dock|slam|mapping|wander|explore|pick_object ]]
}

corebrum_skills_followup_lines() {
  local blob="$1"
  printf '%s\n' "Open AI Agents"
  if corebrum_skills_needs_ros_menu "$blob"; then
    printf '%s\n' "Open ROS"
  fi
  printf '%s\n' "Done"
}

# Stub-mode guidance after a resolved install ref.
corebrum_skills_success_guidance() {
  local ref="$1" blob hint
  blob="$ref"
  blob+=" $(corebrum_skills_listing_text "$ref")"
  printf '%s\n' "Restart AI agents so they load the new skill tools."
  printf '%s\n' "Super+Space → AI Agents, then open the CLI again."
  while IFS= read -r hint; do
    [[ -n "$hint" ]] || continue
    printf '%s\n' "$hint"
  done < <(corebrum_skills_dep_hints "$blob")
  corebrum_skills_followup_lines "$blob"
  printf '\n'
  printf '%s\n' "Press Enter to close."
}

# Bash fragment: after `ref` is set, install it and run follow-up.
# Used inside terminal heredocs. Expects set +e.
corebrum_skills_install_and_followup_fragment() {
  cat <<'EOF'
synapse skills install "$ref"
ec=$?
printf '\n'
if [ "$ec" -eq 0 ]; then
  printf '%s\n' "Restart AI agents so they load the new skill tools."
  printf '%s\n' "Super+Space → AI Agents, then open the CLI again."
  blob="$ref"
  listing=""
  case "$ref" in
    @*) ;;
    */*/*) ;;
    */*)
      owner="${ref%%/*}"
      skill="${ref#*/}"
      if [ -n "$owner" ] && [ -n "$skill" ]; then
        listing="$(curl -fsSL --max-time 5 "https://skills.corebrum.com/api/skills/${owner}/${skill}" 2>/dev/null | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    raise SystemExit(0)
parts = [
    str(data.get("displayName") or ""),
    str(data.get("description") or ""),
    " ".join(str(x) for x in (data.get("keywords") or [])),
    " ".join(str(x) for x in (data.get("capabilityIds") or [])),
]
for cap in data.get("capabilities") or []:
    if isinstance(cap, dict):
        parts.append(str(cap.get("id") or ""))
        parts.append(str(cap.get("description") or ""))
        impl = cap.get("implementation") or {}
        if isinstance(impl, dict):
            parts.append(str(impl.get("package") or ""))
            parts.append(str(impl.get("action") or ""))
print(" ".join(parts))
' 2>/dev/null || true)"
      fi
      ;;
  esac
  blob="$blob $listing"
  lower="$(printf '%s' "$blob" | tr '[:upper:]' '[:lower:]')"
  case "$lower" in
    *navigate_to*|*navigate_through*|*nav2*|*navigate*|*wander*|*explore*)
      printf '%s\n' "This skill needs Nav2. Install or launch it from Super+Space Robot → ROS. The skill does not start that stack."
      ;;
  esac
  case "$lower" in
    *pick_object*|*moveit*)
      printf '%s\n' "This skill needs MoveIt. Install or launch it from Super+Space Robot → ROS. The skill does not start that stack."
      ;;
  esac
  case "$lower" in
    *dock_to_charger*|*opennav*|*docking*)
      printf '%s\n' "This skill needs OpenNav docking. Bring that stack up yourself. The skill does not start it."
      ;;
  esac
  case "$lower" in
    *start_slam*|*stop_slam*|*save_map*|*load_map*|*rtab*)
      printf '%s\n' "This skill needs RTAB-Map. Bring mapping up yourself. The skill does not start that stack."
      ;;
  esac
  case "$lower" in
    *follow_person*|*follow-me*|*follow_me*)
      printf '%s\n' "This skill needs the on-robot follow node. Bring it up yourself. The skill does not start it."
      ;;
  esac
  case "$lower" in
    *detect_humans*|*object-detection*|*detection*)
      printf '%s\n' "This skill needs a detection publisher. Bring it up yourself. The skill does not start it."
      ;;
  esac
  case "$lower" in
    *realsense*|*d435*|*d455*)
      printf '%s\n' "This skill expects RealSense. Start it from Super+Space Robot → RealSense when needed."
      ;;
  esac
  if command -v notify-send >/dev/null 2>&1; then
    notify-send "Corebrum Skills" "Restart AI agents so new skill tools load." || true
  fi
  printf '\n'
  lines="Open AI Agents
Done"
  case "$lower" in
    *nav2*|*moveit*|*opennav*|*rtab*|*navigate*|*dock*|*slam*|*mapping*|*wander*|*explore*|*pick_object*)
      lines="Open AI Agents
Open ROS
Done"
      ;;
  esac
  if command -v fuzzel >/dev/null 2>&1; then
    choice="$(printf '%s\n' "$lines" | fuzzel \
      --config /etc/corebrum/fuzzel/fuzzel.ini \
      --dmenu \
      --prompt 'After install  ' \
      --width 40 \
      --lines 4 || true)"
  else
    printf '%s\n' "$lines"
    read -r -p "Choice: " choice
  fi
  case "$choice" in
    "Open AI Agents")
      if [ -x /usr/local/bin/corebrum-agents-menu ]; then
        /usr/local/bin/corebrum-agents-menu open >/dev/null 2>&1 &
      fi
      ;;
    "Open ROS")
      if [ -x /usr/local/bin/corebrum-ros-menu ]; then
        /usr/local/bin/corebrum-ros-menu open >/dev/null 2>&1 &
      fi
      ;;
  esac
fi
printf '\n'
read -r -p "Press Enter to close. "
exit "$ec"
EOF
}

# Search the marketplace API. Prints "marketplaceRef<TAB>displayName" lines.
corebrum_skills_search_rows() {
  local q="$1"
  if [[ "${COREBRUM_SKILLS_STUB:-0}" == 1 ]]; then
    if [[ -n "${COREBRUM_SKILLS_SEARCH_JSON:-}" ]]; then
      printf '%s\n' "$COREBRUM_SKILLS_SEARCH_JSON" | python3 -c "$(cat <<'PY'
import json, sys
raw = sys.stdin.read().strip()
try:
    data = json.loads(raw)
except Exception:
    raise SystemExit(0)
items = data if isinstance(data, list) else data.get("skills") or []
for s in items:
    if not isinstance(s, dict):
        continue
    ref = (s.get("marketplaceRef") or "").strip()
    if not ref and s.get("ownerLogin") and (s.get("skillSlug") or s.get("slug")):
        ref = f"{s.get('ownerLogin')}/{s.get('skillSlug') or s.get('slug')}"
    name = (s.get("displayName") or s.get("name") or ref or "").strip()
    if ref:
        print(f"{ref}\t{name}")
PY
)"
      return 0
    fi
    return 0
  fi
  local enc
  enc="$(python3 -c 'import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))' "$q")"
  curl -fsSL --max-time 15 \
    "https://skills.corebrum.com/api/skills?q=${enc}&sort=recent&limit=25" 2>/dev/null \
    | python3 -c "$(cat <<'PY'
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    raise SystemExit(0)
items = data.get("skills") if isinstance(data, dict) else data
if not isinstance(items, list):
    raise SystemExit(0)
for s in items:
    if not isinstance(s, dict):
        continue
    ref = (s.get("marketplaceRef") or "").strip()
    if not ref and s.get("ownerLogin") and (s.get("skillSlug") or s.get("slug")):
        ref = f"{s.get('ownerLogin')}/{s.get('skillSlug') or s.get('slug')}"
    name = (s.get("displayName") or s.get("name") or ref or "").strip()
    if ref:
        print(f"{ref}\t{name}")
PY
)" 2>/dev/null || true
}

corebrum_skills_search_script() {
  if [[ "${COREBRUM_SKILLS_STUB:-0}" == 1 ]]; then
    local q="${COREBRUM_SKILLS_QUERY:-}"
    [[ -n "$q" ]] || return 0
    local rows ref name
    rows="$(corebrum_skills_search_rows "$q")"
    if [[ -z "$rows" ]]; then
      cat <<EOF
printf '%s\n' "No marketplace skills matched $(printf '%q' "$q")."
printf '%s\n' "Install needs owner/skill, for example codevinoo/surroundings-scan."
printf '\n'
printf '%s\n' "Press Enter to close."
EOF
      return 0
    fi
    ref="$(printf '%s\n' "$rows" | head -n 1 | cut -f1)"
    name="$(printf '%s\n' "$rows" | head -n 1 | cut -f2-)"
    cat <<EOF
printf '%s\n' "Search: $(printf '%q' "$q")"
printf '%s\n' "1) ${name}  (${ref})"
printf '%s\n' "Installing ${ref}"
synapse skills install $(printf '%q' "$ref")
$(corebrum_skills_success_guidance "$ref")
EOF
    return 0
  fi
  cat <<EOF
set +e
read -r -p "Search skills: " q
if [ -z "\$q" ]; then
  printf '%s\n' "No search was entered."
  read -r -p "Press Enter to close. "
  exit 0
fi
enc="\$(python3 -c 'import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))' "\$q")"
rows="\$(curl -fsSL --max-time 15 "https://skills.corebrum.com/api/skills?q=\${enc}&sort=recent&limit=25" 2>/dev/null | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    raise SystemExit(0)
items = data.get("skills") if isinstance(data, dict) else data
if not isinstance(items, list):
    raise SystemExit(0)
for s in items:
    if not isinstance(s, dict):
        continue
    ref = (s.get("marketplaceRef") or "").strip()
    if not ref and s.get("ownerLogin") and (s.get("skillSlug") or s.get("slug")):
        ref = f"{s.get("ownerLogin")}/{s.get("skillSlug") or s.get("slug")}"
    name = (s.get("displayName") or s.get("name") or ref or "").strip()
    if ref:
        print(f"{ref}\\t{name}")
' 2>/dev/null || true)"
if [ -z "\$rows" ]; then
  printf '%s\n' "No marketplace skills matched \"\$q\"."
  printf '%s\n' "Browse https://skills.corebrum.com or try Install with owner/skill."
  printf '\n'
  read -r -p "Press Enter to close. "
  exit 0
fi
printf '\\n'
printf '%s\\n' "Pick a skill to install (owner/skill). A display name alone will 404."
i=1
refs=""
while IFS=\$'\t' read -r ref name; do
  [ -n "\$ref" ] || continue
  printf '%s\\n' "\$i) \$name  (\$ref)"
  refs="\$refs
\$i \$ref"
  i=\$((i + 1))
done <<< "\$rows"
count=\$((i - 1))
printf '\\n'
if [ "\$count" -eq 1 ]; then
  ref="\$(printf '%s\\n' "\$refs" | awk 'NF { print \$2; exit }')"
  printf '%s\\n' "Only one match. Installing \$ref"
else
  read -r -p "Number to install (1-\$count), or paste owner/skill: " pick
  if [ -z "\$pick" ]; then
    printf '%s\\n' "Nothing selected."
    read -r -p "Press Enter to close. "
    exit 0
  fi
  case "\$pick" in
    */*|@*)
      ref="\$pick"
      ;;
    *)
      ref="\$(printf '%s\\n' "\$refs" | awk -v n="\$pick" '\$1 == n { print \$2; exit }')"
      if [ -z "\$ref" ]; then
        printf '%s\\n' "That number was not in the list."
        read -r -p "Press Enter to close. "
        exit 1
      fi
      ;;
  esac
fi
printf '\\n'
$(corebrum_skills_install_and_followup_fragment)
EOF
}

corebrum_skills_install_script() {
  if [[ "${COREBRUM_SKILLS_STUB:-0}" == 1 ]]; then
    local ref="${COREBRUM_SKILLS_QUERY:-}"
    [[ -n "$ref" ]] || return 0
    # Bare names resolve through search in stub when SEARCH_JSON is set.
    if [[ "$ref" != */* && "$ref" != @* ]]; then
      local rows resolved
      rows="$(corebrum_skills_search_rows "$ref")"
      resolved="$(printf '%s\n' "$rows" | head -n 1 | cut -f1)"
      if [[ -n "$resolved" ]]; then
        ref="$resolved"
      fi
    fi
    cat <<EOF
synapse skills install $(printf '%q' "$ref")
$(corebrum_skills_success_guidance "$ref")
EOF
    return 0
  fi
  cat <<EOF
set +e
printf '%s\n' "Install needs owner/skill (example: codevinoo/surroundings-scan)."
printf '%s\n' "A display name alone returns 404. Prefer Search, then pick a result."
read -r -p "Install skill: " ref
if [ -z "\$ref" ]; then
  printf '%s\n' "No skill was entered."
  read -r -p "Press Enter to close. "
  exit 0
fi
case "\$ref" in
  */*|@*) ;;
  *)
    printf '\\n'
    printf '%s\\n' "Resolving \"\$ref\" on the marketplace…"
    enc="\$(python3 -c 'import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))' "\$ref")"
    rows="\$(curl -fsSL --max-time 15 "https://skills.corebrum.com/api/skills?q=\${enc}&sort=recent&limit=25" 2>/dev/null | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    raise SystemExit(0)
items = data.get("skills") if isinstance(data, dict) else data
if not isinstance(items, list):
    raise SystemExit(0)
for s in items:
    if not isinstance(s, dict):
        continue
    ref = (s.get("marketplaceRef") or "").strip()
    if not ref and s.get("ownerLogin") and (s.get("skillSlug") or s.get("slug")):
        ref = f"{s.get("ownerLogin")}/{s.get("skillSlug") or s.get("slug")}"
    name = (s.get("displayName") or s.get("name") or ref or "").strip()
    if ref:
        print(f"{ref}\\t{name}")
' 2>/dev/null || true)"
    if [ -z "\$rows" ]; then
      printf '%s\\n' "No marketplace skills matched \"\$ref\"."
      printf '%s\\n' "Use Search, or paste owner/skill from https://skills.corebrum.com"
      read -r -p "Press Enter to close. "
      exit 1
    fi
    count="\$(printf '%s\\n' "\$rows" | grep -c .)"
    if [ "\$count" -eq 1 ]; then
      ref="\$(printf '%s\\n' "\$rows" | head -n 1 | cut -f1)"
      name="\$(printf '%s\\n' "\$rows" | head -n 1 | cut -f2-)"
      printf '%s\\n' "Matched \$name (\$ref)"
    else
      printf '%s\\n' "Several skills matched. Pick one to install:"
      i=1
      refs=""
      while IFS=\$'\t' read -r r name; do
        [ -n "\$r" ] || continue
        printf '%s\\n' "\$i) \$name  (\$r)"
        refs="\$refs
\$i \$r"
        i=\$((i + 1))
      done <<< "\$rows"
      read -r -p "Number (1-\$((i - 1))): " pick
      ref="\$(printf '%s\\n' "\$refs" | awk -v n="\$pick" '\$1 == n { print \$2; exit }')"
      if [ -z "\$ref" ]; then
        printf '%s\\n' "That number was not in the list."
        read -r -p "Press Enter to close. "
        exit 1
      fi
    fi
    ;;
esac
printf '\\n'
$(corebrum_skills_install_and_followup_fragment)
EOF
}

# Registered skills as "id<TAB>packageName" from list --json (or stub JSON).
corebrum_skills_registered_rows() {
  if [[ "${COREBRUM_SKILLS_STUB:-0}" == 1 ]]; then
    if [[ -n "${COREBRUM_SKILLS_LIST_JSON:-}" ]]; then
      printf '%s\n' "$COREBRUM_SKILLS_LIST_JSON" | python3 -c "$(cat <<'PY'
import json, sys
raw = sys.stdin.read().strip()
try:
    data = json.loads(raw)
except Exception:
    raise SystemExit(0)
items = data if isinstance(data, list) else data.get("registered") or []
for s in items:
    if not isinstance(s, dict):
        continue
    sid = str(s.get("id") or "").strip()
    pkg = str(s.get("packageName") or s.get("name") or sid).strip()
    if sid:
        print(f"{sid}\t{pkg}")
PY
)"
    fi
    return 0
  fi
  if [[ ! -x /usr/local/bin/synapse ]]; then
    return 0
  fi
  /usr/local/bin/synapse skills list --json 2>/dev/null | python3 -c "$(cat <<'PY'
import json, sys
blob = sys.stdin.read()
data = None
try:
    data = json.loads(blob)
except json.JSONDecodeError:
    decoder = json.JSONDecoder()
    for index, char in enumerate(blob):
        if char != "{":
            continue
        try:
            data, _end = decoder.raw_decode(blob[index:])
            break
        except json.JSONDecodeError:
            data = None
if not isinstance(data, dict):
    raise SystemExit(0)
for s in data.get("registered") or []:
    if not isinstance(s, dict):
        continue
    sid = str(s.get("id") or "").strip()
    pkg = str(s.get("packageName") or sid).strip()
    if sid:
        print(f"{sid}\t{pkg}")
PY
)" 2>/dev/null || true
}

# Shared remove-after-pick fragment. Expects $id set. Uses --yes to skip CLI confirm.
corebrum_skills_remove_followup_fragment() {
  cat <<'EOF'
printf '\n'
printf '%s\n' "Removing $id …"
synapse skills remove --yes "$id"
ec=$?
printf '\n'
if [ "$ec" -eq 0 ]; then
  printf '%s\n' "Removed $id."
  printf '%s\n' "Restart AI agents if they still show tools from that skill."
  if command -v notify-send >/dev/null 2>&1; then
    notify-send "Corebrum Skills" "Removed $id. Restart AI agents if needed." || true
  fi
else
  printf 'Remove failed (%s).\n' "$ec"
fi
printf '\n'
read -r -p "Press Enter to close. "
exit "$ec"
EOF
}

corebrum_skills_list_script() {
  if [[ "${COREBRUM_SKILLS_STUB:-0}" == 1 ]]; then
    local rows pick id pkg
    rows="$(corebrum_skills_registered_rows)"
    if [[ -z "$rows" ]]; then
      cat <<'EOF'
printf '%s\n' "No registered skills."
printf '\n'
printf '%s\n' "Press Enter to close."
EOF
      return 0
    fi
    pick="${COREBRUM_SKILLS_QUERY:-}"
    cat <<EOF
printf '%s\n' "Registered skills:"
$(
  i=1
  while IFS=$'\t' read -r id pkg; do
    [[ -n "$id" ]] || continue
    printf 'printf '"'"'%%s\\n'"'"' "%s) %s  (%s)"\n' "$i" "$id" "$pkg"
    i=$((i + 1))
  done <<<"$rows"
)
printf '%s\n' "Number to remove, or Enter to close."
EOF
    if [[ -n "$pick" ]]; then
      case "$pick" in
        */*|@*)
          id="$pick"
          ;;
        *)
          if [[ "$pick" =~ ^[0-9]+$ ]]; then
            id="$(printf '%s\n' "$rows" | awk -v n="$pick" 'NR == n { print $1; exit }')"
          else
            id="$pick"
          fi
          ;;
      esac
      if [[ -n "$id" ]]; then
        cat <<EOF
printf '%s\n' "Removing $(printf '%q' "$id")"
synapse skills remove --yes $(printf '%q' "$id")
printf '%s\n' "Restart AI agents if they still show tools from that skill."
printf '\n'
printf '%s\n' "Press Enter to close."
EOF
        return 0
      fi
    fi
    cat <<'EOF'
printf '\n'
printf '%s\n' "Press Enter to close."
EOF
    return 0
  fi
  cat <<EOF
set +e
rows="\$(synapse skills list --json 2>/dev/null | python3 -c '
import json, sys
blob = sys.stdin.read()
data = None
try:
    data = json.loads(blob)
except json.JSONDecodeError:
    decoder = json.JSONDecoder()
    for index, char in enumerate(blob):
        if char != "{":
            continue
        try:
            data, _end = decoder.raw_decode(blob[index:])
            break
        except json.JSONDecodeError:
            data = None
if not isinstance(data, dict):
    raise SystemExit(0)
for s in data.get("registered") or []:
    if not isinstance(s, dict):
        continue
    sid = str(s.get("id") or "").strip()
    pkg = str(s.get("packageName") or sid).strip()
    if sid:
        print(f"{sid}\\t{pkg}")
' 2>/dev/null || true)"
if [ -z "\$rows" ]; then
  printf '%s\n' "No registered skills."
  printf '\n'
  read -r -p "Press Enter to close. "
  exit 0
fi
printf '%s\n' "Registered skills:"
i=1
ids=""
while IFS=\$'\t' read -r sid pkg; do
  [ -n "\$sid" ] || continue
  printf '%s\n' "\$i) \$sid  (\$pkg)"
  ids="\$ids
\$i \$sid"
  i=\$((i + 1))
done <<< "\$rows"
count=\$((i - 1))
printf '\n'
printf '%s\n' "Enter a number to remove that skill, or press Enter to close."
read -r -p "Remove (1-\$count): " pick
if [ -z "\$pick" ]; then
  exit 0
fi
case "\$pick" in
  */*|@*)
    id="\$pick"
    ;;
  *)
    id="\$(printf '%s\n' "\$ids" | awk -v n="\$pick" '\$1 == n { print \$2; exit }')"
    if [ -z "\$id" ]; then
      # Allow typing the registered id directly.
      if printf '%s\n' "\$rows" | awk -F '\t' -v n="\$pick" '\$1 == n { found=1 } END { exit found ? 0 : 1 }'; then
        id="\$pick"
      else
        printf '%s\n' "That number or id was not in the list."
        read -r -p "Press Enter to close. "
        exit 1
      fi
    fi
    ;;
esac
$(corebrum_skills_remove_followup_fragment)
EOF
}

corebrum_skills_remove_script() {
  if [[ "${COREBRUM_SKILLS_STUB:-0}" == 1 ]]; then
    local ref="${COREBRUM_SKILLS_QUERY:-}" rows resolved
    if [[ -z "$ref" ]]; then
      # Same inventory + optional pick as List.
      corebrum_skills_list_script
      return 0
    fi
    if [[ "$ref" =~ ^[0-9]+$ ]]; then
      rows="$(corebrum_skills_registered_rows)"
      resolved="$(printf '%s\n' "$rows" | awk -v n="$ref" 'NR == n { print $1; exit }')"
      [[ -n "$resolved" ]] && ref="$resolved"
    fi
    cat <<EOF
synapse skills remove --yes $(printf '%q' "$ref")
printf '%s\n' "Restart AI agents if they still show tools from that skill."
printf '\n'
printf '%s\n' "Press Enter to close."
EOF
    return 0
  fi
  # Same picker as List, without requiring a separate List step.
  corebrum_skills_list_script
}

corebrum_skills_command() {
  local choice="$1" ref
  case "$choice" in
    List)
      corebrum_skills_list_script
      ;;
    Search)
      corebrum_skills_search_script
      ;;
    Install)
      corebrum_skills_install_script
      ;;
    Remove)
      corebrum_skills_remove_script
      ;;
    *)
      return 0
      ;;
  esac
}

corebrum_skills_hold() {
  local script="$1"
  # Search/Install/List/Remove already include the close prompt.
  if [[ "$script" == *"Restart AI agents so they load the new skill tools."* ]] \
    || [[ "$script" == *"No marketplace skills matched"* ]] \
    || [[ "$script" == *"Pick a skill to install"* ]] \
    || [[ "$script" == *"Number to remove"* ]] \
    || [[ "$script" == *"Enter a number to remove"* ]] \
    || [[ "$script" == *"No registered skills."* ]] \
    || [[ "$script" == *"Restart AI agents if they still show tools from that skill."* ]]; then
    printf '%s\n' "$script"
    return 0
  fi
  cat <<EOF
set +e
${script}
ec=\$?
set -e
printf '\\n'
read -r -p 'Press Enter to close. '
exit "\$ec"
EOF
}

corebrum_skills_terminal() {
  local script
  script="$(corebrum_skills_hold "$1")"
  if [[ "${COREBRUM_SKILLS_STUB:-0}" == 1 ]]; then
    printf '%s\n' "$script"
    return 0
  fi
  exec /usr/local/bin/corebrum-terminal bash --login -c "$script"
}

corebrum_skills_open() {
  local choice="" script
  if ! corebrum_skills_ready; then
    return 0
  fi
  if [[ "${COREBRUM_SKILLS_STUB:-0}" == 1 ]]; then
    if [[ -n "${COREBRUM_SKILLS_CHOICE:-}" ]]; then
      script="$(corebrum_skills_command "$COREBRUM_SKILLS_CHOICE")"
      [[ -n "$script" ]] || return 0
      corebrum_skills_terminal "$script"
      return 0
    fi
    corebrum_skills_labels
    return 0
  fi
  choice="$(corebrum_skills_labels | fuzzel \
    --config /etc/corebrum/fuzzel/fuzzel.ini \
    --dmenu \
    --prompt 'Corebrum Skills  ' \
    --width 48 \
    --lines 8)" || return 0
  [[ -n "$choice" ]] || return 0
  script="$(corebrum_skills_command "$choice")"
  [[ -n "$script" ]] || return 0
  corebrum_skills_terminal "$script"
}

usage() {
  cat <<'EOF'
Usage: corebrum-skills-menu refresh|open|dep-hints TEXT|search-rows QUERY|data-dir
EOF
}

cmd="${1:-}"
case "$cmd" in
  refresh) corebrum_skills_refresh ;;
  open) corebrum_skills_open ;;
  dep-hints) corebrum_skills_dep_hints "${2:-}" ;;
  search-rows) corebrum_skills_search_rows "${2:-}" ;;
  data-dir) corebrum_skills_data_dir ;;
  -h | --help | help) usage ;;
  *)
    usage >&2
    exit 1
    ;;
esac
