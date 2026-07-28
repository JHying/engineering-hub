#!/usr/bin/env bash
# check-skills.sh - Skill consistency check ("three-point alignment")
# Mirror of check-skills.ps1; see that file for the check list.
# Exit code: number of FAIL findings (0 = all pass). WARNs do not affect exit code.

set -u
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
skills_dir="$repo_root/skills"
fail_count=0

if [ ! -d "$skills_dir" ]; then
  echo "[FAIL] skills directory not found: $skills_dir"
  exit 1
fi

for dir in "$skills_dir"/*/; do
  name="$(basename "$dir")"
  problems=()
  warnings=()

  # 1. SKILL.md exact-case check (ls is case-sensitive listing even on Windows)
  actual="$(ls "$dir" | grep -i '^skill\.md$' | head -1 || true)"
  if [ -z "$actual" ]; then
    echo "[FAIL] $name : SKILL.md missing"
    fail_count=$((fail_count + 1))
    continue
  fi
  if [ "$actual" != "SKILL.md" ]; then
    problems+=("filename is '$actual', expected exact 'SKILL.md'")
  fi
  skill_path="$dir$actual"

  # 2. frontmatter version vs CHANGELOG top version
  ver="$(grep -m1 -E '^version:' "$skill_path" | sed -E 's/^version:[[:space:]]*"?([0-9][A-Za-z0-9._-]*)"?.*/\1/' || true)"
  [ -z "$ver" ] && problems+=("no version field in frontmatter")

  cl_path="${dir}CHANGELOG.md"
  if [ -f "$cl_path" ]; then
    cl_ver="$(grep -m1 -oE '##[[:space:]]*\[[0-9][A-Za-z0-9._-]*\]' "$cl_path" | grep -oE '[0-9][A-Za-z0-9._-]*' || true)"
    if [ -z "$cl_ver" ]; then
      problems+=("no version entry found in CHANGELOG.md")
    elif [ -n "$ver" ] && [ "$ver" != "$cl_ver" ]; then
      problems+=("frontmatter version $ver != CHANGELOG top entry $cl_ver")
    fi
  else
    problems+=("CHANGELOG.md missing")
  fi

  # 3. linked references must exist
  linked="$(grep -oE 'references/[A-Za-z0-9._-]+\.md' "$skill_path" | sort -u || true)"
  while IFS= read -r link; do
    [ -z "$link" ] && continue
    if [ ! -f "$dir$link" ]; then
      problems+=("broken link: $link")
    fi
  done <<< "$linked"

  # 4. orphan / oversized reference files
  if [ -d "${dir}references" ]; then
    for rf in "${dir}references"/*.md; do
      [ -e "$rf" ] || continue
      rel="references/$(basename "$rf")"
      if ! grep -qxF "$rel" <<< "$linked"; then
        warnings+=("orphan reference file (not linked from SKILL.md): $rel")
      fi
      lines="$(wc -l < "$rf")"
      if [ "$lines" -gt 250 ]; then
        warnings+=("$rel is $lines lines (> 250, consider splitting)")
      fi
    done
  fi

  if [ "${#problems[@]}" -eq 0 ]; then
    echo "[OK]   $name ($ver)"
  else
    for p in "${problems[@]}"; do echo "[FAIL] $name : $p"; done
    fail_count=$((fail_count + ${#problems[@]}))
  fi
  for w in "${warnings[@]}"; do echo "[WARN] $name : $w"; done
done

echo ""
if [ "$fail_count" -eq 0 ]; then
  echo "check-skills: all skills consistent."
else
  echo "check-skills: $fail_count failure(s) found."
fi
exit "$fail_count"
