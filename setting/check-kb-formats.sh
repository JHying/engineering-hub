#!/usr/bin/env bash
# check-kb-formats.sh
# Compares heading structure of KB format-file copies against the canonical
# versions in skills/update-kb/templates/formats/.
# A copy is OK when its heading sequence matches the canonical file, or when
# its frontmatter contains "customized: true" (intentional per-KB override).
# Missing copies and structural mismatches are reported as WARN.

set -u

root="$(cd "$(dirname "$0")/.." && pwd)"
canonical_dir="$root/skills/update-kb/templates/formats"
knowledge_dir="$root/knowledge"

format_keys=("spec-format.md" "impls-format.md" "qa-format.md")
format_paths=("specs/spec-format.md" "specs/impls/impls-format.md" "qa-records/qa-format.md")

headings() {
    awk '
        /^[[:space:]]*(```|~~~)/ { in_fence = !in_fence; next }
        !in_fence && /^#{1,6} / { print }
    ' "$1"
}

is_customized() {
    head -n 10 "$1" | grep -qE '^[[:space:]]*customized:[[:space:]]*true[[:space:]]*$'
}

warn_count=0

for i in "${!format_keys[@]}"; do
    key="${format_keys[$i]}"
    rel="${format_paths[$i]}"
    canonical="$canonical_dir/$key"

    if [ ! -f "$canonical" ]; then
        echo "[WARN] canonical missing: skills/update-kb/templates/formats/$key"
        warn_count=$((warn_count + 1))
        continue
    fi

    for kb in "$knowledge_dir"/*_KBs; do
        [ -d "$kb" ] || continue
        kb_name="$(basename "$kb")"
        [ "$kb_name" = "common_KBs" ] && continue

        copy="$kb/$rel"
        label="$kb_name/$rel"
        if [ ! -f "$copy" ]; then
            echo "[WARN] $label : missing (scaffolding incomplete?)"
            warn_count=$((warn_count + 1))
            continue
        fi
        if is_customized "$copy"; then
            echo "[OK]   $label (customized)"
            continue
        fi
        if [ "$(headings "$canonical")" = "$(headings "$copy")" ]; then
            echo "[OK]   $label"
        else
            echo "[WARN] $label : heading structure differs from canonical (mark 'customized: true' in frontmatter if intentional)"
            warn_count=$((warn_count + 1))
        fi
    done
done

echo ""
if [ "$warn_count" -gt 0 ]; then
    echo "check-kb-formats: $warn_count warning(s)."
else
    echo "check-kb-formats: all KB format copies consistent."
fi
