# check-memory-link.ps1 - SessionStart hook
#
# Purpose:
#   On every Claude Code session start, check whether the CURRENT project's
#   ~/.claude/projects/{project}/memory folder is already linked (junction) to
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
# cases above (create dir, or create a junction over an empty/nonexistent
# folder). It never deletes or migrates real content on its own.
#
# Registered as a user-level SessionStart hook (~/.claude/settings.json) so it
# fires no matter which directory `claude` is launched from.

$ErrorActionPreference = 'Stop'

# Windows PowerShell 5.1 defaults stdout to the system ANSI codepage (e.g. Big5)
# when not attached to a real console (as when the hook runner pipes it) -
# without this, non-ASCII systemMessage text comes out mangled. Kept even
# though messages are ASCII-only now, in case that ever changes.
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$claudeDir = Join-Path $env:USERPROFILE '.claude'
$logFile = Join-Path $claudeDir 'hook-log\memory-link-check.log'
$cwd = (Get-Location).Path.TrimEnd('\')

function Write-HookLog($reason) {
    try {
        $dir = Split-Path $logFile -Parent
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force $dir | Out-Null }
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`t$cwd`t$reason" | Out-File -FilePath $logFile -Append -Encoding utf8
    } catch {}
}

function Emit-Json($obj) {
    $obj | ConvertTo-Json -Depth 5 -Compress
    exit 0
}

# Every exit path goes through here so the hook always shows up in-conversation
# (systemMessage is the one hook output field the UI guarantees to display).
function Emit-Status($reason, $displayText) {
    Write-HookLog $reason
    Emit-Json @{ systemMessage = "[memory-link-check] ran - $displayText" }
}

$anchorFile = Join-Path $claudeDir 'kb-root.txt'

if (-not (Test-Path $anchorFile)) {
    # setup-host.ps1 has never run on this host - nothing to link against yet.
    Emit-Status 'no-anchor' 'KB host anchor not set yet, skipping'
}

$kbRoot = (Get-Content $anchorFile -Raw).Trim()
$hubMemory = Join-Path $kbRoot 'memory'

if (-not (Test-Path $hubMemory)) {
    # Anchor points somewhere that no longer has a memory/ folder - stale anchor, bail quietly.
    Emit-Status 'stale-anchor' "KB anchor is stale, skipping (KB ROOT: $kbRoot, memory folder not found)"
}

$projName = ($cwd -replace '[:\\/]', '-')
$projDir = Join-Path $claudeDir "projects\$projName"
$memPath = Join-Path $projDir 'memory'

# Don't try to relink the hub project onto itself.
if ($cwd -eq $kbRoot) {
    Emit-Status 'is-hub-itself' "current directory is the Hub project itself, skipping (KB ROOT: $kbRoot)"
}

if (Test-Path $memPath) {
    $item = Get-Item $memPath -Force
    if ($item.LinkType -eq 'Junction') {
        Emit-Status 'already-linked' "memory already linked to Knowledge Hub (KB ROOT: $kbRoot)"   # already linked, nothing to do
    }

    $ignoreMarker = Join-Path $memPath '.link-ignored'
    if (Test-Path $ignoreMarker) {
        Emit-Status 'ignored-by-user' "previously ignored by user, skipping (KB ROOT: $kbRoot)"   # user already said "ignore" for this project, don't re-nag every session
    }

    $files = Get-ChildItem $memPath -Force -File -ErrorAction SilentlyContinue
    if (-not $files -or $files.Count -eq 0) {
        # Empty real folder - safe to replace with a junction, no data at risk.
        Remove-Item $memPath -Recurse -Force
        New-Item -ItemType Junction -Path $memPath -Target $hubMemory | Out-Null
        Emit-Status 'linked-empty-folder' "empty folder, junction created (KB ROOT: $kbRoot)"
    }

    # Real content exists - needs classification + de-identification judgment.
    # Surface it to Claude via additionalContext; do not touch the folder.
    Write-HookLog 'needs-user-decision'
    $fileNames = ($files | ForEach-Object { $_.Name }) -join ', '
    Emit-Json @{
        systemMessage = "[memory-link-check] ran - existing memory content detected, awaiting user decision (KB ROOT: $kbRoot)"
        hookSpecificOutput = @{
            hookEventName    = 'SessionStart'
            additionalContext = "[memory-link-check] The current project's ($cwd) memory folder is not yet linked to the shared Knowledge Hub ($hubMemory), and contains existing content: $fileNames. These files need human judgment to classify as 'cross-project general' vs 'project-specific' and de-identify before merging - proactively ask the user whether to handle this now (general content gets merged into the shared hub and converted to a junction; project-specific content stays put or is handled per the user's instruction). If the user chooses to ignore, create an empty file at $memPath\.link-ignored so this stops being prompted every session."
        }
    }
}
else {
    # Folder doesn't exist yet at all - link immediately, nothing to lose.
    New-Item -ItemType Directory -Force $projDir | Out-Null
    New-Item -ItemType Junction -Path $memPath -Target $hubMemory | Out-Null
    Emit-Status 'linked-new-folder' "folder did not exist, junction created (KB ROOT: $kbRoot)"
}
