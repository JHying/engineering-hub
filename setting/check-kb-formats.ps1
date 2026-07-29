# check-kb-formats.ps1
# Compares heading structure of KB format-file copies against the canonical
# versions in skills/update-kb/templates/formats/.
# A copy is OK when its heading sequence matches the canonical file, or when
# its frontmatter contains "customized: true" (intentional per-KB override).
# Missing copies and structural mismatches are reported as WARN.

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$canonicalDir = Join-Path $root "skills\update-kb\templates\formats"
$knowledgeDir = Join-Path $root "knowledge"

$formatMap = [ordered]@{
    "spec-format.md"  = "specs\spec-format.md"
    "impls-format.md" = "specs\impls\impls-format.md"
    "qa-format.md"    = "qa-records\qa-format.md"
}

function Get-Headings($path) {
    $inFence = $false
    foreach ($line in (Get-Content $path -Encoding UTF8)) {
        if ($line -match '^\s*(```|~~~)') { $inFence = -not $inFence; continue }
        if (-not $inFence -and $line -match '^#{1,6} ') { $line }
    }
}

function Test-Customized($path) {
    $head = Get-Content $path -Encoding UTF8 -TotalCount 10
    return ($head -match '^\s*customized:\s*true\s*$').Count -gt 0
}

$warnCount = 0

foreach ($entry in $formatMap.GetEnumerator()) {
    $canonicalPath = Join-Path $canonicalDir $entry.Key
    if (-not (Test-Path $canonicalPath)) {
        Write-Output "[WARN] canonical missing: skills/update-kb/templates/formats/$($entry.Key)"
        $warnCount++
        continue
    }
    $canonicalHeadings = Get-Headings $canonicalPath

    $kbs = Get-ChildItem $knowledgeDir -Directory |
        Where-Object { $_.Name -like "*_KBs" -and $_.Name -ne "common_KBs" }

    foreach ($kb in $kbs) {
        $copyPath = Join-Path $kb.FullName $entry.Value
        $label = "$($kb.Name)/$($entry.Value -replace '\\','/')"
        if (-not (Test-Path $copyPath)) {
            Write-Output "[WARN] $label : missing (scaffolding incomplete?)"
            $warnCount++
            continue
        }
        if (Test-Customized $copyPath) {
            Write-Output "[OK]   $label (customized)"
            continue
        }
        $copyHeadings = Get-Headings $copyPath
        $diff = Compare-Object $canonicalHeadings $copyHeadings -SyncWindow 0
        if ($diff) {
            Write-Output "[WARN] $label : heading structure differs from canonical (mark 'customized: true' in frontmatter if intentional)"
            $warnCount++
        } else {
            Write-Output "[OK]   $label"
        }
    }
}

Write-Output ""
if ($warnCount -gt 0) {
    Write-Output "check-kb-formats: $warnCount warning(s)."
} else {
    Write-Output "check-kb-formats: all KB format copies consistent."
}
