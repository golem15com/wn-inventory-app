#!/bin/bash
set -e
cd "$(dirname "$0")/.."

# ============================================================================
# scripts/reset-gsd.sh
# ============================================================================
# Turn a freshly-cloned, re-pointed Golem15 starter stack into a fresh GSD
# client project in one invocation (SCAF-01).
#
# Usage:
#   git clone <starter>            # clone the starter stack
#   git checkout <starter-tag>     # e.g. v1.1.8 -- recorded as descent baseline
#   git remote set-url origin <empty-client-repo>.git
#   bash scripts/reset-gsd.sh [--dry-run]
#   /gsd-new-project               # author the client's first milestone
#
# This script is DESTRUCTIVE: it deletes local tags, git-mv's the starter's
# planning docs into an archive, and rewrites STATE.md. It therefore leads with
# a strict freshness guard (D-09) and supports --dry-run (D-12).
#
# It DOES NOT rewrite git history. Tags are cleared and docs archived via
# tracked git mv -- everything stays in history (D-11).
# ============================================================================

# --- Flag parsing ------------------------------------------------------------
# --dry-run: print every archive/delete/reset action, touch nothing (D-12).
DRY_RUN=0
for arg in "$@"; do
    [ "$arg" = "--dry-run" ] && DRY_RUN=1
done

# run(): route every mutating step through here so --dry-run touches nothing.
run() {
    if [ "$DRY_RUN" = "1" ]; then
        echo "[dry-run] would: $*"
    else
        eval "$@"
    fi
}

echo "=== reset-gsd.sh ==="
if [ "$DRY_RUN" = "1" ]; then
    echo "==> DRY RUN: no files will be created, moved, or deleted."
fi

# --- STEP 1: FRESHNESS GUARD (D-09) -----------------------------------------
# Runs FIRST, before any mutation, and runs even under --dry-run. Refuse unless
# BOTH hold: (a) origin URL does not contain wn-starter-app, (b) the remote is
# empty (git ls-remote returns nothing). The empty-remote check IS the guard --
# there is no typed-confirmation prompt.
echo ""
echo "==> Step 1: freshness guard"
ORIGIN_URL="$(git config --get remote.origin.url || echo '')"

case "$ORIGIN_URL" in
    *wn-starter-app*)
        echo "Refusing: origin still points at the starter app ($ORIGIN_URL)."
        echo "Repoint origin to your fresh, empty client repo first:"
        echo "  git remote set-url origin git@github.com:your-org/your-client-app.git"
        exit 1
        ;;
esac

if [ -z "$ORIGIN_URL" ]; then
    echo "Refusing: no 'origin' remote configured. Point origin at your fresh client repo first."
    exit 1
fi

if [ -n "$(git ls-remote origin 2>/dev/null)" ]; then
    echo "Refusing: remote '$ORIGIN_URL' is not empty (heads/tags present)."
    echo "reset-gsd.sh only runs against an empty, fresh origin -- the empty-remote check is the safety guard."
    exit 1
fi

echo "Guard passed: origin is '$ORIGIN_URL' and the remote is empty."

# --- STEP 2: DETECT DESCENT TAG (D-07/D-08) ---------------------------------
# Detected from the CURRENTLY checked-out HEAD, BEFORE any tag deletion. The
# user's pre-run `git checkout <starter-tag>` is what selects the milestone
# baseline (SCAF-06 / D-02) -- there is no --milestone flag or picker.
echo ""
echo "==> Step 2: detect descent tag from current HEAD"
STARTER_TAG="$(git describe --tags --exact-match 2>/dev/null || git describe --tags 2>/dev/null || echo '(unknown)')"
echo "Descended-from tag: $STARTER_TAG"

# --- STEP 3: WRITE LINEAGE MARKER (D-07/D-08) -------------------------------
# Written BEFORE clearing tags (Step 4) -- load-bearing ordering. If tags were
# cleared first, the descent baseline would be unrecoverable.
echo ""
echo "==> Step 3: write .planning/STARTER-LINEAGE.md (before any tag deletion)"
RESET_DATE="$(date -u +%FT%TZ)"
run "cat > .planning/STARTER-LINEAGE.md <<LINEAGE_EOF
# Starter Lineage

Origin: Golem15 starter stack

Descended-from tag: ${STARTER_TAG}

Reset date: ${RESET_DATE}

This project was scaffolded from the Golem15 starter stack via scripts/reset-gsd.sh.
The descent above is recorded only in these planning docs; local git tags were
cleared during reset and full commit history was preserved.
LINEAGE_EOF"

# --- STEP 4: CLEAR LOCAL TAGS (D-10) ----------------------------------------
# Local tags only. The freshness guard (D-09) guarantees no remote tags exist,
# so there is no remote push / push --delete. Superproject tags only -- this
# does not recurse into submodules.
echo ""
echo "==> Step 4: clear local tags (superproject only, no remote push)"
run "git tag -l | xargs -r git tag -d"

# --- STEP 5: KEEP-HISTORY GUARANTEE (D-11) ----------------------------------
# This script never re-initializes, squashes, or rewrites the commit tree.
# Tags are cleared and docs archived via tracked git mv -- all history remains
# recoverable.

# --- STEP 6: CREATE ARCHIVE DIR (D-05) --------------------------------------
echo ""
echo "==> Step 6: create archive directory"
run "mkdir -p .planning/archive/starter-stack"

# --- STEP 7: ARCHIVE THE STARTER DOC SET (D-04) -----------------------------
# Move EXACTLY these into .planning/archive/starter-stack/ via tracked git mv
# (D-05 requires tracked moves; D-11 keeps everything in history). Each move is
# guarded by an existence check so partial states / re-runs do not hard-fail
# under set -e, and each is routed through the dry-run helper.
echo ""
echo "==> Step 7: archive starter planning docs (tracked git mv)"
ARCHIVE_TARGETS="PROJECT.md ROADMAP.md REQUIREMENTS.md MILESTONES.md RETROSPECTIVE.md phases audit debug quick milestones"
for target in $ARCHIVE_TARGETS; do
    if [ -e ".planning/$target" ]; then
        run "git mv \".planning/$target\" .planning/archive/starter-stack/"
    else
        echo "  skip: .planning/$target not present"
    fi
done

# --- STEP 8: KEEP SET LEFT UNTOUCHED (D-03) ---------------------------------
# .planning/codebase/ and .planning/research/ describe the inherited stack and
# stay in place. config.json and STATE.md also stay (they are reset in place
# below, not archived).
echo ""
echo "==> Step 8: keep set untouched (codebase/, research/, config.json, STATE.md)"

# --- STEP 9: RESET STATE.md FRESH (D-03/D-06) -------------------------------
# Overwrite STATE.md with an empty/zeroed template so /gsd-new-project can
# repopulate it for the client's first milestone.
echo ""
echo "==> Step 9: reset .planning/STATE.md to an empty template"
run "cat > .planning/STATE.md <<STATE_EOF
---
gsd_state_version: 1.0
milestone: null
milestone_name: null
status: fresh
stopped_at: null
last_updated: \"${RESET_DATE}\"
last_activity: null
progress:
  total_phases: 0
  completed_phases: 0
  total_plans: 0
  completed_plans: 0
  percent: 0
---

# Project State

This project was reset from the Golem15 starter stack (see the lineage marker).
Run /gsd-new-project to author your client's first milestone.
STATE_EOF"

# --- STEP 10: RESET config.json FRESH (D-03/D-06) ---------------------------
# Clear only clearly project-specific keys to framework default. project_code is
# the sole project-specific key; the rest (model_profile, workflow.*, git.*,
# mode, granularity) are framework defaults and are left intact. Idempotent
# sed in the setup.sh set_env spirit; if project_code is already null, nothing
# changes and we say so.
echo ""
echo "==> Step 10: reset config.json project-specific keys to framework default"
if grep -Eq '"project_code"[[:space:]]*:[[:space:]]*null' .planning/config.json; then
    echo "  config.json is already framework-default (project_code: null) -- leaving untouched."
else
    run "sed -i -E 's/(\"project_code\"[[:space:]]*:[[:space:]]*)[^,}]+/\1null/' .planning/config.json"
fi

# --- STEP 11: CLOSING NEXT-STEP BLOCK ---------------------------------------
echo ""
echo "=== Reset complete ==="
echo ".planning/ retains config.json + empty STATE.md + codebase/ + research/."
echo "Starter docs archived to .planning/archive/starter-stack/; lineage recorded in .planning/ (see the lineage marker written in step 3)."
echo "Run /gsd-new-project to author your client's first milestone."
if [ "$DRY_RUN" = "1" ]; then
    echo "(dry-run: nothing was actually created, moved, or deleted.)"
fi
