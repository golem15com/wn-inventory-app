#!/bin/bash
# scripts/submodule-state-report.sh
# READ-ONLY submodule state report generator (LTS-01, Phase 15).
# Enumerates every submodule git reports and emits a Markdown table of the full
# D-15 field set: checked-out commit, branch-vs-detached, declared branch,
# develop-vs-master divergence, existing tags, and working-tree cleanliness.
#
# This script MUTATES NOTHING. It runs zero checkout/tag/commit/push/reset/--remote
# git verbs. Phase 15 reports state only; Phase 16 acts on it.
#
# Usage:   bash scripts/submodule-state-report.sh
# Capture: bash scripts/submodule-state-report.sh > .planning/phases/15-prerequisites-submodule-review-gsd-reset-tooling/SUBMODULE-STATE-REPORT.md
set -e
cd "$(dirname "$0")/.."

GENERATED_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

# Parse the declared `branch =` for a given submodule path from .gitmodules.
# Prints the declared branch, or "master (default)" if no branch line exists.
declared_branch() {
    local path="$1" branch
    branch="$(git config -f .gitmodules \
        --get "submodule.${path}.branch" 2>/dev/null || true)"
    if [ -n "$branch" ]; then
        echo "$branch"
    else
        echo "master (default)"
    fi
}

echo "# Submodule State Report (raw)"
echo ""
echo "Generated: ${GENERATED_AT}"
echo ""
echo "Regenerate with: \`bash scripts/submodule-state-report.sh\`"
echo ""

echo "=== Per-Submodule State Table ==="
echo ""
echo "| Submodule | Flag | Checked-out commit | Branch vs detached | Declared branch | develop↔master (ahead/behind) | Describe / tags | Working tree |"
echo "|-----------|------|--------------------|--------------------|-----------------|-------------------------------|-----------------|--------------|"

# Enumerate from `git submodule status` (NOT a hardcoded list).
# Format per line: "<flag><sha> <path> (<describe>)" where flag is the leading char.
git submodule status | while IFS= read -r line; do
    # Leading flag char: ' '=clean, '+'=differs from index, '-'=uninitialized, 'U'=conflict.
    flag="${line:0:1}"
    [ "$flag" = " " ] && flag_label="clean ( )"
    [ "$flag" = "+" ] && flag_label="differs (+)"
    [ "$flag" = "-" ] && flag_label="uninit (-)"
    [ "$flag" = "U" ] && flag_label="conflict (U)"

    # Strip the leading flag char, then split "<sha> <path> (<describe>)".
    rest="${line:1}"
    sha="$(echo "$rest" | awk '{print $1}')"
    path="$(echo "$rest" | awk '{print $2}')"
    short_sha="${sha:0:10}"

    if [ ! -d "$path/.git" ] && [ ! -f "$path/.git" ]; then
        echo "| \`$path\` | $flag_label | $short_sha | (uninitialized) | $(declared_branch "$path") | n/a | n/a | n/a |"
        continue
    fi

    # branch-vs-detached: symbolic-ref is empty when HEAD is detached.
    symref="$(git -C "$path" symbolic-ref -q --short HEAD 2>/dev/null || true)"
    if [ -n "$symref" ]; then
        head_state="on branch \`$symref\`"
    else
        head_state="detached"
    fi

    decl="$(declared_branch "$path")"

    # develop-vs-master divergence. Not every submodule has both refs -> n/a tolerated.
    divergence="$(git -C "$path" rev-list --left-right --count \
        origin/develop...origin/master 2>/dev/null || echo "n/a")"
    if [ "$divergence" != "n/a" ]; then
        # rev-list --left-right --count emits "<left>\t<right>" = develop-ahead / master-ahead.
        d_ahead="$(echo "$divergence" | awk '{print $1}')"
        m_ahead="$(echo "$divergence" | awk '{print $2}')"
        divergence="develop +${d_ahead} / master +${m_ahead}"
    fi

    # existing tags: exact tag on HEAD, plus a count of all tags in the submodule.
    exact_tag="$(git -C "$path" describe --tags --exact-match HEAD 2>/dev/null \
        || echo "(untagged at HEAD)")"
    tag_count="$(git -C "$path" tag -l 2>/dev/null | grep -c . || true)"
    describe="$exact_tag (${tag_count} tags total)"

    # working-tree cleanliness: empty porcelain output = clean.
    if [ -z "$(git -C "$path" status --porcelain 2>/dev/null)" ]; then
        worktree="clean"
    else
        worktree="DIRTY"
    fi

    echo "| \`$path\` | $flag_label | $short_sha | $head_state | $decl | $divergence | $describe | $worktree |"
done

echo ""
echo "=== Legend ==="
echo ""
echo "**\`git submodule status\` leading flag char:**"
echo "- \` \` (space) = clean: checked-out commit matches the superproject index."
echo "- \`+\` = checked-out commit differs from the commit recorded in the index."
echo "- \`-\` = submodule is not initialized."
echo "- \`U\` = submodule has merge conflicts."
echo ""
echo "**\`git describe\` suffix semantics (the \`(...)\` in raw \`git submodule status\`):**"
echo "- bare \`vX.Y.Z\` = HEAD is exactly that tag (clean exact pin)."
echo "- \`vX.Y.Z-N-gHASH\` = HEAD is N commits past the named tag."
echo "- bare short-hash (e.g. \`f56471c\`) = UNTAGGED: no tag is reachable from HEAD."
echo ""
echo "**Declared branch:** parsed from \`.gitmodules\` \`branch =\`; \"master (default)\" means"
echo "no \`branch =\` line is declared for that submodule."
echo ""
echo "=== Done ==="
echo ""
echo "To capture this report, redirect output into the phase artifact:"
echo "  bash scripts/submodule-state-report.sh > .planning/phases/15-prerequisites-submodule-review-gsd-reset-tooling/SUBMODULE-STATE-REPORT.md"
