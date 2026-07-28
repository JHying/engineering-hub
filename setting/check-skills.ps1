# check-skills.ps1 - Skill consistency check ("three-point alignment")
# For each skills/<name>/:
#   1. SKILL.md exists with exact uppercase filename (portability on case-sensitive FS)
#   2. frontmatter version == CHANGELOG.md top entry version
#   3. every references/*.md linked from SKILL.md exists
#   4. warn on orphan reference files (exist but never linked) and files > 250 lines
# Exit code: number of FAIL findings (0 = all pass). WARNs do not affect exit code.

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$skillsDir = Join-Path $repoRoot 'skills'
$failCount = 0

if (-not (Test-Path $skillsDir)) {
    Write-Output "[FAIL] skills directory not found: $skillsDir"
    exit 1
}

foreach ($dir in (Get-ChildItem $skillsDir -Directory)) {
    $name = $dir.Name
    $problems = @()
    $warnings = @()

    # 1. SKILL.md exact-case check
    $candidates = @(Get-ChildItem $dir.FullName -File | Where-Object { $_.Name -ieq 'SKILL.md' })
    if ($candidates.Count -eq 0) {
        Write-Output "[FAIL] $name : SKILL.md missing"
        $failCount++
        continue
    }
    if (-not ($candidates | Where-Object { $_.Name -ceq 'SKILL.md' })) {
        $problems += "filename is '$($candidates[0].Name)', expected exact 'SKILL.md'"
    }
    $skillPath = $candidates[0].FullName
    $content = Get-Content $skillPath -Raw -Encoding UTF8

    # 2. frontmatter version vs CHANGELOG top version
    $ver = $null
    if ($content -match '(?m)^version:\s*"?([0-9][\w.\-]*)"?') { $ver = $Matches[1] }
    if (-not $ver) { $problems += 'no version field in frontmatter' }

    $clPath = Join-Path $dir.FullName 'CHANGELOG.md'
    if (Test-Path $clPath) {
        $cl = Get-Content $clPath -Raw -Encoding UTF8
        $clVer = $null
        if ($cl -match '##\s*\[([0-9][\w.\-]*)\]') { $clVer = $Matches[1] }
        if (-not $clVer) { $problems += 'no version entry found in CHANGELOG.md' }
        elseif ($ver -and ($ver -ne $clVer)) { $problems += "frontmatter version $ver != CHANGELOG top entry $clVer" }
    } else {
        $problems += 'CHANGELOG.md missing'
    }

    # 3. linked references must exist
    $linked = @([regex]::Matches($content, 'references/[A-Za-z0-9._\-]+\.md') |
        ForEach-Object { $_.Value } | Sort-Object -Unique)
    foreach ($link in $linked) {
        if (-not (Test-Path (Join-Path $dir.FullName $link))) {
            $problems += "broken link: $link"
        }
    }

    # 4. orphan / oversized reference files
    $refDir = Join-Path $dir.FullName 'references'
    if (Test-Path $refDir) {
        foreach ($rf in (Get-ChildItem $refDir -File -Filter *.md)) {
            $rel = 'references/' + $rf.Name
            if ($linked -notcontains $rel) { $warnings += "orphan reference file (not linked from SKILL.md): $rel" }
            $lineCount = (Get-Content $rf.FullName | Measure-Object -Line).Lines
            if ($lineCount -gt 250) { $warnings += "$rel is $lineCount lines (> 250, consider splitting)" }
        }
    }

    if ($problems.Count -eq 0) {
        Write-Output "[OK]   $name ($ver)"
    } else {
        foreach ($p in $problems) { Write-Output "[FAIL] $name : $p" }
        $failCount += $problems.Count
    }
    foreach ($w in $warnings) { Write-Output "[WARN] $name : $w" }
}

Write-Output ''
if ($failCount -eq 0) { Write-Output 'check-skills: all skills consistent.' }
else { Write-Output "check-skills: $failCount failure(s) found." }
exit $failCount
