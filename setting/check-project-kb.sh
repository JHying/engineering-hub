#!/usr/bin/env bash
# check-project-kb.sh - SessionStart hook (macOS / Linux)
#
# Purpose:
#   Suggest which project KB (a knowledge/*_KBs folder in the Knowledge Hub)
#   the CURRENT working directory belongs to, by matching each _KBs folder's
#   source-codex/cross/service-map.md local-path column against the current
#   directory. Read-only - never writes anything, never touches skill.md.
#
#   Silent when there is no KB root anchor yet (see check-memory-link.sh,
#   which already reports that case) or when no _KBs matches this directory -
#   this hook only speaks up when it has a concrete suggestion, so it doesn't
#   nag on every unrelated project on the host.
#
# Registered as a user-level SessionStart hook (~/.claude/settings.json) so it
# fires no matter which directory `claude` is launched from.
#
# Counterpart of setting/check-project-kb.ps1 (Windows); keep both in sync.
# Written for bash 3.2 (macOS default) compatibility: no associative arrays,
# no mapfile/readarray.

set -euo pipefail

claude_dir="$HOME/.claude"
anchor_file="$claude_dir/kb-root.txt"
cwd="$(pwd)"

[ -f "$anchor_file" ] || exit 0

kb_root="$(cat "$anchor_file")"
knowledge_dir="$kb_root/knowledge"

[ -d "$knowledge_dir" ] || exit 0

json_escape() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    printf '%s' "$s"
}

trim() {
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s' "$s"
}

join_by() {
    local sep="$1"; shift
    local out="$1"; shift
    for item in "$@"; do
        out="$out$sep$item"
    done
    printf '%s' "$out"
}

matched_kbs=()

for dir in "$knowledge_dir"/*_KBs; do
    [ -d "$dir" ] || continue
    service_map="$dir/source-codex/cross/service-map.md"
    [ -f "$service_map" ] || continue

    matched_this_kb=0
    while IFS= read -r line; do
        [[ "$line" =~ ^[[:space:]]*\| ]] || continue
        IFS='|' read -ra cols <<< "$line"
        [ "${#cols[@]}" -ge 3 ] || continue

        local_path="$(trim "${cols[2]}")"
        # Only treat cells that look like an actual absolute path (Unix or
        # Windows-style, since the Hub is shared across hosts) as data rows -
        # this skips the header row and the "----" separator row without
        # relying on matching any particular header text/language.
        [[ "$local_path" =~ ^(/|[A-Za-z]:[\\/]) ]] || continue

        if [[ "$local_path" == "$cwd"* ]]; then
            matched_this_kb=1
            break
        fi
    done < "$service_map"

    if [ "$matched_this_kb" -eq 1 ]; then
        matched_kbs+=("$(basename "$dir")")
    fi
done

[ "${#matched_kbs[@]}" -gt 0 ] || exit 0

suggestion="$(join_by ', ' "${matched_kbs[@]}")"
ctx="[project-kb-check] By matching local paths in each _KBs folder's service-map.md under the Knowledge Hub, the current working directory ($cwd) appears to correspond to project KB: $suggestion. When running sdlc-agent or similar flows that require selecting a project KB, if the user hasn't specified one explicitly, proactively suggest this value for confirmation - but always defer to the user's actual choice; do not auto-skip the question."

printf '{"systemMessage":"[project-kb-check] ran - suggested default project KB: %s (derived by matching local paths in service-map.md; suggestion only)","hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' \
    "$(json_escape "$suggestion")" "$(json_escape "$ctx")"

exit 0
