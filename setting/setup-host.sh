#!/usr/bin/env bash
# setup-host.sh — One-click setup for a new host (macOS / Linux)
#
# Purpose:
#   Link this repository's portable assets back to Claude Code's local directories:
#     - memory/ -> ~/.claude/projects/{project-name}/memory
#     - skills/ -> ~/.claude/skills
#
# Usage:
#   bash <repo>/setting/setup-host.sh
#
# Note:
#   Claude Code project name = repository absolute path with all [:/] replaced by '-'
#   Example:
#     /home/rita/engineering-hub
#       ->
#     -home-rita-engineering-hub

set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
proj_name="$(printf '%s' "$repo" | sed 's|[:/]|-|g')"

claude_dir="$HOME/.claude"
proj_dir="$claude_dir/projects/$proj_name"

mkdir -p "$proj_dir"

link() {
    local link_path="$1"
    local target="$2"

    if [ -L "$link_path" ]; then
        echo "Already linked, skipping: $link_path"
        return
    fi

    if [ -e "$link_path" ]; then
        mv "$link_path" "$link_path.pre-link.bak"
        echo "Existing path detected. Moved to ${link_path}.pre-link.bak"
    fi

    ln -s "$target" "$link_path"
    echo "Linked: $link_path -> $target"
}

link "$proj_dir/memory" "$repo/memory"
link "$claude_dir/skills" "$repo/skills"

echo ""
echo "Setup completed."
echo "Project name: $proj_name"
echo "Please open Claude Code in the repository and verify that both memory and skills are available."