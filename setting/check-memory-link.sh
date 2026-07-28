#!/usr/bin/env bash
# check-memory-link.sh - SessionStart hook (macOS / Linux)
#
# Purpose:
#   On every Claude Code session start, check whether the CURRENT project's
#   ~/.claude/projects/{project}/memory folder is already linked (symlink) to
#   the shared Knowledge Hub memory store. If not yet linked:
#     - empty/nonexistent folder  -> link immediately, silently (nothing to lose)
#     - has real local content    -> do NOT touch it; emit additionalContext so
#                                     Claude can ask the user in-conversation
#                                     whether to migrate (content classification
#                                     and de-identification needs judgment, not
#                                     something this script should decide)
#     - user previously said "ignore" (marker file present) -> stay silent
#
# This script is deterministic and side-effect-free except for the two safe
# cases above (create dir, or create a symlink over an empty/nonexistent
# folder). It never deletes or migrates real content on its own.
#
# Registered as a user-level SessionStart hook (~/.claude/settings.json) so it
# fires no matter which directory `claude` is launched from.
#
# Counterpart of setting/check-memory-link.ps1 (Windows); keep both in sync.
# Written for bash 3.2 (macOS default) compatibility: no associative arrays,
# no mapfile/readarray.

set -euo pipefail

claude_dir="$HOME/.claude"
log_file="$claude_dir/hook-log/memory-link-check.log"
cwd="$(pwd)"

write_hook_log() {
    local reason="$1"
    mkdir -p "$(dirname "$log_file")" 2>/dev/null || true
    printf '%s\t%s\t%s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$cwd" "$reason" >> "$log_file" 2>/dev/null || true
}

json_escape() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
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

# Every exit path goes through here so the hook always shows up in-conversation
# (systemMessage is the one hook output field the UI guarantees to display).
emit_status() {
    local reason="$1"
    local display_text="$2"
    write_hook_log "$reason"
    printf '{"systemMessage":"[memory-link-check] ran - %s"}\n' "$(json_escape "$display_text")"
    exit 0
}

anchor_file="$claude_dir/kb-root.txt"

if [ ! -f "$anchor_file" ]; then
    # setup-host.sh has never run on this host - nothing to link against yet.
    emit_status "no-anchor" "KB host anchor not set yet, skipping"
fi

kb_root="$(cat "$anchor_file")"
hub_memory="$kb_root/memory"

if [ ! -d "$hub_memory" ]; then
    # Anchor points somewhere that no longer has a memory/ folder - stale anchor, bail quietly.
    emit_status "stale-anchor" "KB anchor is stale, skipping (KB ROOT: $kb_root, memory folder not found)"
fi

proj_name="$(printf '%s' "$cwd" | sed 's|[:/]|-|g')"
proj_dir="$claude_dir/projects/$proj_name"
mem_path="$proj_dir/memory"

# Don't try to relink the hub project onto itself.
if [ "$cwd" = "$kb_root" ]; then
    emit_status "is-hub-itself" "current directory is the Hub project itself, skipping (KB ROOT: $kb_root)"
fi

if [ -e "$mem_path" ]; then
    if [ -L "$mem_path" ]; then
        emit_status "already-linked" "memory already linked to Knowledge Hub (KB ROOT: $kb_root)"   # already linked, nothing to do
    fi

    ignore_marker="$mem_path/.link-ignored"
    if [ -e "$ignore_marker" ]; then
        emit_status "ignored-by-user" "previously ignored by user, skipping (KB ROOT: $kb_root)"   # user already said "ignore" for this project, don't re-nag every session
    fi

    files=()
    while IFS= read -r -d '' f; do
        files+=("$(basename "$f")")
    done < <(find "$mem_path" -maxdepth 1 -type f -print0 2>/dev/null)

    if [ "${#files[@]}" -eq 0 ]; then
        # Empty real folder - safe to replace with a symlink, no data at risk.
        rm -rf "$mem_path"
        ln -s "$hub_memory" "$mem_path"
        emit_status "linked-empty-folder" "empty folder, symlink created (KB ROOT: $kb_root)"
    fi

    # Real content exists - needs classification + de-identification judgment.
    # Surface it to Claude via additionalContext; do not touch the folder.
    write_hook_log "needs-user-decision"
    file_names="$(join_by ', ' "${files[@]}")"
    ctx="[memory-link-check] The current project's ($cwd) memory folder is not yet linked to the shared Knowledge Hub ($hub_memory), and contains existing content: $file_names. These files need human judgment to classify as 'cross-project general' vs 'project-specific' and de-identify before merging - proactively ask the user whether to handle this now (general content gets merged into the shared hub and converted to a symlink; project-specific content stays put or is handled per the user's instruction). If the user chooses to ignore, create an empty file at $mem_path/.link-ignored so this stops being prompted every session."
    printf '{"systemMessage":"[memory-link-check] ran - existing memory content detected, awaiting user decision (KB ROOT: %s)","hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' \
        "$(json_escape "$kb_root")" "$(json_escape "$ctx")"
    exit 0
else
    # Folder doesn't exist yet at all - link immediately, nothing to lose.
    mkdir -p "$proj_dir"
    ln -s "$hub_memory" "$mem_path"
    emit_status "linked-new-folder" "folder did not exist, symlink created (KB ROOT: $kb_root)"
fi
