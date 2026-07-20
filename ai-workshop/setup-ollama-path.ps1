# setup-ollama-path.ps1 — Add ai-workshop/Tools to the user PATH so `ollama` works in any shell
#
# Purpose:
#   docker-compose.yml here only runs ollama inside a container (no native
#   ollama.exe on the host). Tools\ollama.cmd wraps `docker exec -it ollama ollama`.
#   Adding Tools\ to the user-level PATH makes `ollama` resolve from cmd.exe,
#   PowerShell, and Git Bash alike — no PowerShell profile edits required.
#
# Usage:
#   Run once after `docker compose up -d` in this directory:
#     powershell -ExecutionPolicy Bypass -File .\setup-ollama-path.ps1
#   Then open a new terminal window to pick up the updated PATH.

$ErrorActionPreference = 'Stop'

$toolsDir = Join-Path $PSScriptRoot 'Tools'
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
$entries  = $userPath -split ';' | Where-Object { $_ }

$alreadyPresent = $entries | Where-Object { $_.TrimEnd('\') -ieq $toolsDir.TrimEnd('\') }

if ($alreadyPresent) {
    Write-Host "Already on PATH, skipping: $toolsDir"
} else {
    $newPath = ($entries + $toolsDir) -join ';'
    [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
    Write-Host "Added to user PATH: $toolsDir"
}

Write-Host ''
Write-Host 'Open a new terminal window (cmd / PowerShell / Git Bash) then try: ollama list'
