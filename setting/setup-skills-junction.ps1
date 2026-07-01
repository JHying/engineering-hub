# ============================================================
# 設定 Claude Code Skills Junction
#
# 用途：將 ~/.claude/skills/ 連結到指定的 skills 目錄，
#       讓 Claude Code 直接讀取該目錄下的所有 skill。
#
# 使用方式：
#   .\setup-skills-junction.ps1
#   .\setup-skills-junction.ps1 -SkillsSource "D:\my-path\skills"
# ============================================================

param(
    [string]$SkillsSource
)

$junctionTarget = "$env:USERPROFILE\.claude\skills"

if (-not $SkillsSource) {
    $SkillsSource = Read-Host "請輸入 skills 來源目錄路徑"
}

# 確認來源目錄存在
if (-not (Test-Path $SkillsSource)) {
    Write-Error "來源目錄不存在：$SkillsSource"
    exit 1
}

# 若 junction / 目錄已存在，先移除
if (Test-Path $junctionTarget) {
    $existing = Get-Item $junctionTarget
    if ($existing.LinkType -eq "Junction") {
        Write-Host "移除舊 junction：$junctionTarget"
        Remove-Item $junctionTarget -Force
    } else {
        Write-Error "$junctionTarget 已存在且不是 junction，請手動處理後再執行。"
        exit 1
    }
}

# 建立新 junction
New-Item -ItemType Junction -Path $junctionTarget -Target $SkillsSource | Out-Null
Write-Host "Junction 建立成功"
Write-Host "  $junctionTarget"
Write-Host "  -> $SkillsSource"
Write-Host ""
Write-Host "已載入 skills："
Get-ChildItem $SkillsSource -Directory | ForEach-Object { Write-Host "  /$($_.Name)" }
