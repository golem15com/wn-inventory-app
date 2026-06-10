#!/bin/bash
# scripts/tag-approval-table.sh
# READ-ONLY D-04 tag-approval-table generator (Phase 16).
#
# Emits a four-column Markdown table to stdout for HUMAN sign-off BEFORE any tag is
# written (plan 16-05). One row per plugins/golem15/* submodule — Golem15 plugins are
# ours, so we can tag them. Winter upstreams (plugins/winter/*) are EXCLUDED: we do not
# own them and re-pin them to upstream tags in plan 16-04 instead of minting our own.
#
# Columns (D-04):
#   Plugin               = the submodule path
#   Pinned commit        = short SHA from `git submodule status`
#   version.yaml version = bash scripts/version-normalize.sh <path>  (D-05, sourced below)
#   Tag to create        = v<version>, with a D-06b marker if HEAD is already that exact tag
#
# This script MUTATES NOTHING. It executes no state-changing git verbs whatsoever
# (no checkout, no tag, no commit, no push, no reset, no merge) — it only reads git
# state and a version file. The annotated tags themselves are created by the operator
# after this table is approved, never in here.
#
# Usage:  bash scripts/tag-approval-table.sh
set -e
cd "$(dirname "$0")/.."

# Resolve the version via the D-05 normalizer (single source of version.yaml parsing).
NORMALIZE="$(dirname "$0")/version-normalize.sh"

echo "# Tag Approval Table (D-04)"
echo ""
echo "Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
echo ""
echo "Read-only. Approve before any annotated tag is created (plan 16-05)."
echo "Golem15 plugins only — Winter upstreams are re-pinned to upstream tags in plan 16-04."
echo ""
echo "| Plugin | Pinned commit | version.yaml version | Tag to create |"
echo "|--------|---------------|----------------------|---------------|"

# Enumerate from live git (NOT a hardcoded list); keep only plugins/golem15/* paths.
git submodule status | while IFS= read -r line; do
    rest="${line:1}"
    sha="$(echo "$rest" | awk '{print $1}')"
    path="$(echo "$rest" | awk '{print $2}')"
    short_sha="${sha:0:10}"

    # Golem15 = we own → can tag. Skip everything else (Winter upstreams etc.).
    case "$path" in
        plugins/golem15/*) ;;
        *) continue ;;
    esac

    # version.yaml version via the D-05 normalizer; tolerate a missing/unparsable file.
    ver="$(bash "$NORMALIZE" "$path" 2>/dev/null || echo "")"
    if [ -z "$ver" ]; then
        echo "| \`$path\` | $short_sha | (no version.yaml) | (none — fix version.yaml) |"
        continue
    fi

    tag="v$ver"

    # D-06b: if HEAD is already exactly this tag, mark it — only re-tag if the pin advances.
    exact_tag="$(git -C "$path" describe --tags --exact-match HEAD 2>/dev/null \
        || echo "(untagged at HEAD)")"
    if [ "$exact_tag" = "$tag" ]; then
        tag_cell="$tag (already tagged — re-tag only if pin advances)"
    else
        tag_cell="$tag"
    fi

    echo "| \`$path\` | $short_sha | $ver | $tag_cell |"
done
