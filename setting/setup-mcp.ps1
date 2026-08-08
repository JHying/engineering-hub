# setup-mcp.ps1 - One-click setup for commonly-used MCP servers (Windows)
#
# Purpose:
#   Register 3 MCP servers used across projects/hosts (jira-mcp, playwright,
#   postman) at Claude Code user scope, so a new host only needs credentials
#   filled in once instead of re-typing `claude mcp add` by hand.
#
#   Credentials live in a separate, gitignored, host-local file
#   (mcp-secrets.local.json, next to this script) so this script itself never
#   carries secrets. To rotate a token, edit that file and re-run this script -
#   it removes and re-adds each server, so re-running is always safe.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File <repo>\setting\setup-mcp.ps1
#
# First run on a host:
#   - If this host already has jira-mcp/postman registered (e.g. this is the
#     host the config was first set up on), their existing env values are
#     extracted into mcp-secrets.local.json automatically.
#   - Otherwise a blank template is written; fill it in and re-run.
#
# Known issues worked around here (found by live testing, not documentation):
#   - On Windows, `claude` on PATH resolves to an npm-generated claude.ps1
#     shim that forwards $args to the bundled claude.exe. That forwarding
#     drops/mangles arguments for `claude mcp add` (reproducibly fails with
#     "missing required argument 'commandOrUrl'" even with correct syntax).
#     Calling the bundled claude.exe directly (resolved below) avoids this.
#     `claude mcp add-json` was also tested and found unreliable independent
#     of this issue ("Invalid configuration: Invalid input" even for minimal
#     valid JSON, via both the shim and the direct exe) - this script uses
#     the flag-based `claude mcp add` form instead, which tested reliably.
#   - Same class of bug in npm's own npm.ps1 shim: bare `npm ...` calls can
#     resolve to npm.ps1 instead of npm.cmd and silently mangle arguments
#     (reproducibly: `npm config get prefix` via the .ps1 shim errors with
#     "Unknown command: 'pm'"). This script calls `npm.cmd` explicitly
#     everywhere to sidestep the same class of issue.

$ErrorActionPreference = 'Stop'

$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path.TrimEnd('\')
$secretsPath = Join-Path $repo 'setting\mcp-secrets.local.json'

# ------------------------------------------------------------------
# Resolve the real claude.exe, bypassing the buggy claude.ps1 shim
# ------------------------------------------------------------------
function Resolve-ClaudeExe {
    $cmd = Get-Command claude -ErrorAction SilentlyContinue
    if (-not $cmd) {
        throw "claude CLI not found on PATH. Install Claude Code first."
    }
    if ($cmd.Source -like '*.ps1') {
        $shimDir = Split-Path $cmd.Source -Parent
        $nested = Join-Path $shimDir 'node_modules\@anthropic-ai\claude-code\bin\claude.exe'
        if (Test-Path $nested) {
            return $nested
        }
        Write-Warning "claude resolves to a .ps1 shim and the bundled claude.exe was not found at the expected path ($nested). Falling back to the shim, but 'mcp add' is known to fail through it on some hosts."
        return $cmd.Source
    }
    return $cmd.Source
}

$claudeExe = Resolve-ClaudeExe
Write-Host "Using claude executable: $claudeExe"

# ------------------------------------------------------------------
# Load or bootstrap the local secrets file
# ------------------------------------------------------------------
function Get-ExistingEnv([string]$serverName, [string]$key) {
    $claudeJsonPath = Join-Path $env:USERPROFILE '.claude.json'
    if (-not (Test-Path $claudeJsonPath)) { return '' }
    try {
        $cfg = Get-Content $claudeJsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $entry = $cfg.mcpServers.$serverName
        if ($entry -and $entry.env -and $entry.env.$key) {
            return $entry.env.$key
        }
    } catch {}
    return ''
}

if (-not (Test-Path $secretsPath)) {
    Write-Host "No local secrets file found - bootstrapping $secretsPath"
    $secrets = [ordered]@{
        jira    = [ordered]@{
            JIRA_URL       = (Get-ExistingEnv 'jira-mcp' 'JIRA_URL')
            JIRA_USERNAME  = (Get-ExistingEnv 'jira-mcp' 'JIRA_USERNAME')
            JIRA_API_TOKEN = (Get-ExistingEnv 'jira-mcp' 'JIRA_API_TOKEN')
        }
        postman = [ordered]@{
            POSTMAN_API_KEY = (Get-ExistingEnv 'postman' 'POSTMAN_API_KEY')
        }
    }
    ($secrets | ConvertTo-Json -Depth 5) | Set-Content -Path $secretsPath -Encoding utf8
    Write-Host "Wrote $secretsPath"

    $anyBlank = (-not $secrets.jira.JIRA_URL) -or (-not $secrets.jira.JIRA_USERNAME) `
        -or (-not $secrets.jira.JIRA_API_TOKEN) -or (-not $secrets.postman.POSTMAN_API_KEY)
    if ($anyBlank) {
        Write-Host ""
        Write-Host "Some values could not be auto-detected from this host's existing config."
        Write-Host "Fill in the blank fields in $secretsPath, then re-run this script."
        exit 0
    } else {
        Write-Host "Auto-filled from this host's existing MCP config."
    }
}

$secrets = Get-Content $secretsPath -Raw -Encoding UTF8 | ConvertFrom-Json

function Test-Required([string]$label, [string]$value) {
    if ([string]::IsNullOrWhiteSpace($value)) {
        Write-Host "Missing value: $label (edit $secretsPath and re-run)"
        return $false
    }
    return $true
}

$ok = $true
$ok = (Test-Required 'jira.JIRA_URL' $secrets.jira.JIRA_URL) -and $ok
$ok = (Test-Required 'jira.JIRA_USERNAME' $secrets.jira.JIRA_USERNAME) -and $ok
$ok = (Test-Required 'jira.JIRA_API_TOKEN' $secrets.jira.JIRA_API_TOKEN) -and $ok
$ok = (Test-Required 'postman.POSTMAN_API_KEY' $secrets.postman.POSTMAN_API_KEY) -and $ok
if (-not $ok) {
    Write-Host "Fill in the missing values above and re-run this script."
    exit 1
}

# ------------------------------------------------------------------
# Register (idempotent: remove any existing entry, then add fresh)
# ------------------------------------------------------------------
function Register-McpServer {
    param(
        [string]$Name,
        [string[]]$EnvArgs,
        [string]$Command,
        [string[]]$CommandArgs
    )

    try { & $claudeExe mcp remove $Name -s user *> $null } catch {}

    $addArgs = @('mcp', 'add', $Name, '-s', 'user') + $EnvArgs + @('-t', 'stdio', '--', $Command) + $CommandArgs
    & $claudeExe @addArgs
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Failed to register $Name (exit $LASTEXITCODE)"
        return $false
    }
    Write-Host "Registered: $Name"
    return $true
}

# jira-mcp: Docker image, credentials passed through as env vars
$null = Register-McpServer -Name 'jira-mcp' `
    -EnvArgs @('-e', "JIRA_URL=$($secrets.jira.JIRA_URL)", '-e', "JIRA_USERNAME=$($secrets.jira.JIRA_USERNAME)", '-e', "JIRA_API_TOKEN=$($secrets.jira.JIRA_API_TOKEN)") `
    -Command 'cmd' `
    -CommandArgs @('/c', 'docker run -i --rm -e JIRA_URL -e JIRA_USERNAME -e JIRA_API_TOKEN ghcr.io/sooperset/mcp-atlassian:latest')

# playwright + postman both need npm/node on PATH. Skip gracefully (not a
# hard crash) if this host doesn't have it, so the script still completes
# and registers whatever it can (e.g. jira-mcp, which only needs Docker).
if (-not (Get-Command npm.cmd -ErrorAction SilentlyContinue)) {
    Write-Warning "npm.cmd not found on PATH - skipping playwright and postman (install Node.js, then re-run this script to add them)."
} else {
    # playwright: no credentials; resolve the global npm bin path dynamically
    # (it lives under this user's npm prefix, so it can't be hardcoded across hosts)
    #
    # Note: call npm.cmd explicitly, not bare `npm`. On this host (and likely any
    # host with the same npm-generated shim layout) bare `npm` resolves to
    # npm.ps1, which has the same broken $args-forwarding issue documented above
    # for claude.ps1 (reproducibly: `npm config get prefix` via the .ps1 shim
    # fails with "Unknown command: 'pm'" - it mangles the arguments). npm.cmd
    # does not have this problem.
    $npmPrefix = (& npm.cmd config get prefix).Trim()
    $playwrightCmd = Join-Path $npmPrefix 'playwright-mcp-server.cmd'
    if (-not (Test-Path $playwrightCmd)) {
        Write-Host "playwright-mcp-server not found - installing @executeautomation/playwright-mcp-server globally..."
        & npm.cmd install -g '@executeautomation/playwright-mcp-server'
    }
    $null = Register-McpServer -Name 'playwright' -EnvArgs @() -Command $playwrightCmd -CommandArgs @()

    # postman: no local install needed, npx resolves it on demand
    $null = Register-McpServer -Name 'postman' `
        -EnvArgs @('-e', "POSTMAN_API_KEY=$($secrets.postman.POSTMAN_API_KEY)") `
        -Command 'npx' `
        -CommandArgs @('-y', '@postman/postman-mcp-server')
}

Write-Host ""
Write-Host "Done. Verifying:"
& $claudeExe mcp list | Select-String 'jira-mcp|playwright|postman'
Write-Host ""
Write-Host "To rotate credentials later: edit $secretsPath, then re-run this script."
