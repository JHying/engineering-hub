#!/usr/bin/env bash
# setup-host.sh — 新主機一鍵接線（macOS / Linux）
# 用途與 setup-host.ps1 相同：memory/ 與 skills/ 以 symlink 接回 ~/.claude 對應位置。
# 用法：bash <repo>/setting/setup-host.sh
# 注意：Claude Code 專案目錄名 = repo 絕對路徑中 [:/] 換成 '-'
#       （例 /home/rita/engineering-hub → -home-rita-engineering-hub）。

set -euo pipefail
repo="$(cd "$(dirname "$0")/.." && pwd)"
proj_name="$(printf '%s' "$repo" | sed 's|[:/]|-|g')"
claude_dir="$HOME/.claude"
proj_dir="$claude_dir/projects/$proj_name"
mkdir -p "$proj_dir"

link() {
  local link_path="$1" target="$2"
  if [ -L "$link_path" ]; then echo "已接線，略過：$link_path"; return; fi
  if [ -e "$link_path" ]; then
    mv "$link_path" "$link_path.pre-link.bak"
    echo "原位置已有資料，移至 ${link_path}.pre-link.bak（如需合併請手動處理）"
  fi
  ln -s "$target" "$link_path"
  echo "已接線：$link_path → $target"
}

link "$proj_dir/memory" "$repo/memory"
link "$claude_dir/skills" "$repo/skills"

echo ""
echo "完成。專案目錄名：$proj_name"
