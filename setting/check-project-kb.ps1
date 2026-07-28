# check-project-kb.ps1 - SessionStart hook
#
# Purpose:
#   Suggest which project KB (a knowledge/*_KBs folder in the Knowledge Hub)
#   the CURRENT working directory belongs to, by matching each _KBs folder's
#   source-codex/cross/service-map.md local-path column against the current
#   directory. Read-only - never writes anything, never touches skill.md.
#
#   Silent when there is no KB root anchor yet (see check-memory-link.ps1,
#   which already reports that case) or when no _KBs matches this directory -
#   this hook only speaks up when it has a concrete suggestion, so it doesn't
#   nag on every unrelated project on the host.
#
# Registered as a user-level SessionStart hook (~/.claude/settings.json) so it
# fires no matter which directory `claude` is launched from.

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$claudeDir = Join-Path $env:USERPROFILE '.claude'
$anchorFile = Join-Path $claudeDir 'kb-root.txt'
$cwd = (Get-Location).Path.TrimEnd('\').Replace('/', '\')

if (-not (Test-Path $anchorFile)) {
    exit 0
}

$kbRoot = (Get-Content $anchorFile -Raw).Trim()
$knowledgeDir = Join-Path $kbRoot 'knowledge'

if (-not (Test-Path $knowledgeDir)) {
    exit 0
}

$matchedKBs = @()

Get-ChildItem $knowledgeDir -Directory -Filter '*_KBs' -ErrorAction SilentlyContinue | ForEach-Object {
    $serviceMap = Join-Path $_.FullName 'source-codex\cross\service-map.md'
    if (-not (Test-Path $serviceMap)) { return }

    foreach ($line in (Get-Content $serviceMap -ErrorAction SilentlyContinue)) {
        if ($line -notmatch '^\s*\|') { continue }
        $cols = $line -split '\|' | ForEach-Object { $_.Trim() }
        if ($cols.Count -lt 3) { continue }

        $localPath = $cols[2].Replace('/', '\').TrimEnd('\')
        # Only treat cells that look like an actual absolute path as data rows -
        # this skips the header row and the "----" separator row without relying
        # on matching any particular header text/language.
        if ($localPath -notmatch '^[A-Za-z]:\\') { continue }

        if ($localPath.StartsWith($cwd, [System.StringComparison]::OrdinalIgnoreCase)) {
            $matchedKBs += $_.Name
            break
        }
    }
}

$matchedKBs = $matchedKBs | Select-Object -Unique

if ($matchedKBs.Count -eq 0) {
    exit 0
}

$suggestion = $matchedKBs -join ', '

@{
    systemMessage      = "[project-kb-check] ran - suggested default project KB: $suggestion (derived by matching local paths in service-map.md; suggestion only)"
    hookSpecificOutput = @{
        hookEventName     = 'SessionStart'
        additionalContext = "[project-kb-check] By matching local paths in each _KBs folder's service-map.md under the Knowledge Hub, the current working directory ($cwd) appears to correspond to project KB: $suggestion. When running my-work-agent or similar flows that require selecting a project KB, if the user hasn't specified one explicitly, proactively suggest this value for confirmation - but always defer to the user's actual choice; do not auto-skip the question."
    }
} | ConvertTo-Json -Depth 5 -Compress

exit 0
