# setup-host.ps1 — One-click setup for new host (Windows)
#
# Purpose:
#   Link this repository's portable assets back to Claude Code's local directories:
#     1. memory/ -> junction to ~/.claude/projects/{project-name}/memory
#     2. skills/ -> junction to ~/.claude/skills
#   (.claude/agents/ is loaded directly from the repository, so no junction is required.)
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File <repo>\setting\setup-host.ps1
#
# Note:
#   Claude Code project name = repository absolute path with all [:\/] replaced by '-'.

$ErrorActionPreference = 'Stop'

$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path.TrimEnd('\')
$projName = ($repo -replace '[:\\/]', '-')

$claudeDir = Join-Path $env:USERPROFILE '.claude'
$projDir   = Join-Path $claudeDir "projects\$projName"

New-Item -ItemType Directory -Force $projDir | Out-Null

function Connect-Link([string]$linkPath, [string]$target) {
    if (Test-Path $linkPath) {
        $item = Get-Item $linkPath -Force

        if ($item.LinkType -eq 'Junction') {
            Write-Host "Already linked, skipping: $linkPath"
            return
        }

        $bak = "$linkPath.pre-link.bak"
        Write-Host "Existing path detected. Moving it to $bak"
        Move-Item $linkPath $bak
    }

    New-Item -ItemType Junction -Path $linkPath -Target $target | Out-Null
    Write-Host "Linked: $linkPath -> $target"
}

Connect-Link (Join-Path $projDir 'memory') (Join-Path $repo 'memory')
Connect-Link (Join-Path $claudeDir 'skills') (Join-Path $repo 'skills')

Write-Host ""
Write-Host "Setup completed."
Write-Host "Project name: $projName"
Write-Host "Please open Claude Code in the repository and verify that both memory and skills are available."