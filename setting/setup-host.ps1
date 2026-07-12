# setup-host.ps1 — 新主機一鍵接線（Windows）
#
# 用途：把本 repo 的可攜資產接回 Claude Code 的本機讀取位置：
#   1. memory/  → junction 至 ~/.claude/projects/{本 repo 的專案目錄名}/memory
#   2. skills/  → junction 至 ~/.claude/skills
#   （.claude/agents/ 由 Claude Code 直接從 repo 讀取，無需接線）
#
# 用法：clone repo 後，在任意位置執行
#   powershell -ExecutionPolicy Bypass -File <repo>\setting\setup-host.ps1
#
# 注意：Claude Code 專案目錄名 = repo 絕對路徑中 [:\/] 全部換成 '-'
#       （例 D:\Work\engineering-hub → D--Work-engineering-hub）。
#       若未來 Claude Code 改變命名規則，調整 $projName 推導即可。

$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path.TrimEnd('\')
$projName = ($repo -replace '[:\\/]', '-')
$claudeDir = Join-Path $env:USERPROFILE '.claude'
$projDir = Join-Path $claudeDir "projects\$projName"
New-Item -ItemType Directory -Force $projDir | Out-Null

function Connect-Link([string]$linkPath, [string]$target) {
    if (Test-Path $linkPath) {
        $item = Get-Item $linkPath -Force
        if ($item.LinkType -eq 'Junction') { Write-Host "已接線，略過：$linkPath"; return }
        $bak = "$linkPath.pre-link.bak"
        Write-Host "原位置已有資料，移至 $bak（如需合併請手動處理後刪除備份）"
        Move-Item $linkPath $bak
    }
    New-Item -ItemType Junction -Path $linkPath -Target $target | Out-Null
    Write-Host "已接線：$linkPath → $target"
}

Connect-Link (Join-Path $projDir 'memory') (Join-Path $repo 'memory')
Connect-Link (Join-Path $claudeDir 'skills') (Join-Path $repo 'skills')

Write-Host ''
Write-Host "完成。專案目錄名：$projName"
Write-Host '請開啟 Claude Code 於 repo 目錄下驗證 memory 與 skills 皆可讀取。'
