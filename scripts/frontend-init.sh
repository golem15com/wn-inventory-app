#!/bin/bash
set -e
cd "$(dirname "$0")/.."

# ============================================================================
# frontend-init.sh
# ============================================================================
# Scaffold a new client frontend from the Golem15 vue-starter-app submodule
# (D-09). This is the documented, default way to start a new client frontend:
# it renames the starter's identifiers, re-points the `vue-starter-app/`
# submodule git origin at the client's own repo, and syncs the superproject
# `.gitmodules` to match.
#
# Usage:
#   ./frontend-init.sh --name=<client> --repo=git@github.com:org/<client>.git [--dry-run]
#   ./frontend-init.sh --name <client> --repo <git-url> [--dry-run]
#
# What it does (each mutation routed through run(), so --dry-run touches nothing):
#   1. Rename identifiers in vue-starter-app/ (package.json `name`,
#      README title, nuxt.config.ts `site.name`/`app.head.title`, i18n welcome
#      strings, .env.example header) from "vue-starter-app" / "Vue Starter App"
#      to the client name. An A2 grep surfaces any remaining string sprawl.
#   2. Re-point the submodule origin: git -C vue-starter-app remote set-url
#      origin <--repo>.
#   3. Rewrite the superproject .gitmodules `url` for the vue-starter-app
#      submodule to <--repo>, then `git submodule sync --recursive` to
#      propagate into .git/config.
#
# This script is DESTRUCTIVE against the submodule origin + superproject
# .gitmodules. It therefore LEADS with a strict guard (runs even under
# --dry-run, T-17-18): require --name AND --repo, refuse a dirty
# vue-starter-app/ working tree, refuse if --repo equals the current starter
# origin (don't clobber the canonical starter), and refuse if the expected
# submodule is absent (T-17-19). Mirrors scripts/reset-gsd.sh.
#
# TODO(--dir): an optional `--dir=<new>` to also `git mv vue-starter-app <new>`
# (which updates the .gitmodules `path` too) is out of scope for now.
# ============================================================================

# --- Flag parsing ------------------------------------------------------------
# Support both --flag=value and --flag value forms. --dry-run prints every
# mutation and changes nothing (D-12).
DRY_RUN=0
NAME=""
REPO=""

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run)
            DRY_RUN=1
            ;;
        --name=*)
            NAME="${1#*=}"
            ;;
        --name)
            shift
            NAME="$1"
            ;;
        --repo=*)
            REPO="${1#*=}"
            ;;
        --repo)
            shift
            REPO="$1"
            ;;
        *)
            echo "Unknown argument: $1"
            echo "Usage: ./frontend-init.sh --name=<client> --repo=<git-url> [--dry-run]"
            exit 1
            ;;
    esac
    shift
done

# run(): route every mutating step through here so --dry-run touches nothing.
# Arguments are passed as a real argv (NOT through eval) so operator-supplied
# values — client name, repo URL — are never re-parsed as shell. Each sed below
# splices its variable in as a single literal argv token. `%q` keeps the dry-run
# preview faithful and safe.
run() {
    if [ "$DRY_RUN" = "1" ]; then
        printf '[dry-run] would:'
        printf ' %q' "$@"
        printf '\n'
    else
        "$@"
    fi
}

echo "=== frontend-init.sh ==="
if [ "$DRY_RUN" = "1" ]; then
    echo "==> DRY RUN: no files, remotes, or .gitmodules entries will be changed."
fi

SUBMODULE="vue-starter-app"
STARTER_ORIGIN="git@github.com:golem15com/vue-starter-app.git"

# --- STEP 1: GUARD (T-17-18 / T-17-19) --------------------------------------
# Runs FIRST, before any mutation, and runs even under --dry-run. Refuse unless
# every precondition holds. Mirrors reset-gsd.sh's leading freshness guard.
echo ""
echo "==> Step 1: guard"

# (a) require --name AND --repo
if [ -z "$NAME" ] || [ -z "$REPO" ]; then
    echo "Refusing: both --name and --repo are required."
    echo "  ./frontend-init.sh --name=<client> --repo=git@github.com:org/<client>.git [--dry-run]"
    exit 1
fi

# (b) the expected submodule must exist (T-17-19: don't mutate the wrong superproject)
if [ ! -d "$SUBMODULE" ]; then
    echo "Refusing: expected submodule directory '$SUBMODULE/' not found in $(pwd)."
    echo "Run this from the inventory superproject root where .gitmodules + $SUBMODULE/ live."
    exit 1
fi
if ! grep -q "submodule \"$SUBMODULE\"" .gitmodules 2>/dev/null; then
    echo "Refusing: .gitmodules does not declare the '$SUBMODULE' submodule."
    echo "This does not look like the Golem15 starter superproject — aborting."
    exit 1
fi

# (c) refuse a dirty submodule working tree (don't rename over uncommitted work)
if [ -n "$(git -C "$SUBMODULE" status --porcelain 2>/dev/null)" ]; then
    echo "Refusing: '$SUBMODULE/' has uncommitted changes. Commit or stash them first:"
    git -C "$SUBMODULE" status --short
    exit 1
fi

# (d) origin guard: refuse if --repo equals the canonical starter origin
CURRENT_ORIGIN="$(git -C "$SUBMODULE" config --get remote.origin.url || echo '')"
if [ "$REPO" = "$STARTER_ORIGIN" ] || [ "$REPO" = "$CURRENT_ORIGIN" ]; then
    echo "Refusing: --repo '$REPO' is the current starter origin."
    echo "Point --repo at the client's OWN fresh repo so the canonical starter is not clobbered."
    exit 1
fi

echo "Guard passed: name='$NAME', repo='$REPO', $SUBMODULE/ clean, current origin='$CURRENT_ORIGIN'."

# --- STEP 2: SURFACE STRING SPRAWL (A2) -------------------------------------
# Grep for both the slug and the title-case name so nothing is missed beyond the
# files rewritten in Step 3. Anything surfaced here that Step 3 does NOT touch is
# reported for the operator to handle.
echo ""
echo "==> Step 2: scan for 'vue-starter-app' / 'Vue Starter App' string sprawl (A2)"
grep -rn "vue-starter-app\|Vue Starter App" "$SUBMODULE" \
    --exclude-dir=node_modules --exclude-dir=.nuxt --exclude-dir=.git 2>/dev/null \
    || echo "  (none found)"
echo "  Note: occurrences that are PATHS (e.g. a comment referencing the <inventory>/$SUBMODULE"
echo "  directory) are intentionally left alone — only app identifiers are renamed below."

# Title-case display name for the README title / site.name / head title / i18n.
# Derive a human label from the slug: replace - and _ with spaces, capitalise words.
DISPLAY_NAME="$(echo "$NAME" | sed -E 's/[-_]+/ /g' | awk '{ for (i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2) } 1')"
echo "  Slug: '$NAME'  ->  Display name: '$DISPLAY_NAME'"

# --- STEP 3: RENAME IDENTIFIERS ---------------------------------------------
# Each rewrite routed through run() so --dry-run is a true no-op. sed -i in-place;
# anchored patterns so we only touch the identifier occurrences, not paths.
echo ""
echo "==> Step 3: rename app identifiers (slug + display name)"

# package.json "name" (load-bearing)
if [ -f "$SUBMODULE/package.json" ]; then
    run sed -i -E 's/("name"[[:space:]]*:[[:space:]]*")vue-starter-app(")/\1'"$NAME"'\2/' "$SUBMODULE/package.json"
fi

# README title (first-line H1)
if [ -f "$SUBMODULE/README.md" ]; then
    run sed -i -E '1s/^# vue-starter-app[[:space:]]*$/# '"$NAME"'/' "$SUBMODULE/README.md"
fi

# nuxt.config.ts site.name + app.head.title (display name).
# NOTE: this rewrites the CLIENT's checkout at scaffold time — frontend-init.sh
# is not the starter's 17-01 single-owner; it mutates a fork.
if [ -f "$SUBMODULE/nuxt.config.ts" ]; then
    run sed -i "s/Vue Starter App/$DISPLAY_NAME/g" "$SUBMODULE/nuxt.config.ts"
fi

# i18n welcome strings (display name) — en + pl.
for loc in en pl; do
    LOC_FILE="$SUBMODULE/i18n/locales/$loc.json"
    if [ -f "$LOC_FILE" ]; then
        run sed -i "s/Vue Starter App/$DISPLAY_NAME/g" "$LOC_FILE"
    fi
done

# .env.example header comment (slug).
if [ -f "$SUBMODULE/.env.example" ]; then
    run sed -i -E 's/^# vue-starter-app /# '"$NAME"' /' "$SUBMODULE/.env.example"
fi

echo "  Renamed: package.json name, README title, nuxt.config (site.name + head title),"
echo "  i18n en/pl welcome strings, .env.example header."

# --- STEP 4: RE-POINT SUBMODULE ORIGIN --------------------------------------
echo ""
echo "==> Step 4: re-point the $SUBMODULE submodule origin to the client repo"
run git -C "$SUBMODULE" remote set-url origin "$REPO"

# --- STEP 5: SYNC SUPERPROJECT .gitmodules ----------------------------------
# Rewrite ONLY the vue-starter-app submodule's `url =` line, then propagate the
# new url into .git/config via `git submodule sync --recursive`.
echo ""
echo "==> Step 5: update superproject .gitmodules url + git submodule sync"
# Set the submodule's url to the literal $REPO via `git config -f`. Writing the
# config key directly (not a sed substitution) keeps a URL containing '&', '#',
# or '\' literal and cannot corrupt .gitmodules (WR-02).
run git config -f .gitmodules submodule.vue-starter-app.url "$REPO"
run git submodule sync --recursive "$SUBMODULE"

# --- STEP 6: CLOSING NEXT-STEP BLOCK ----------------------------------------
echo ""
echo "=== frontend-init done ==="
echo "The $SUBMODULE submodule is now '$NAME', pointed at '$REPO'."
echo "Next steps:"
echo "  1. Review the rename + .gitmodules diff:   git diff -- .gitmodules; git -C $SUBMODULE diff"
echo "  2. Commit inside the submodule, then push to the client repo:"
echo "       git -C $SUBMODULE add -A && git -C $SUBMODULE commit -m \"chore: scaffold $NAME from starter\""
echo "       git -C $SUBMODULE push -u origin HEAD"
echo "  3. Advance the superproject gitlink + commit .gitmodules:"
echo "       git add .gitmodules $SUBMODULE && git commit -m \"chore: scaffold $NAME frontend\""
if [ "$DRY_RUN" = "1" ]; then
    echo "(dry-run: nothing was actually renamed, re-pointed, or synced.)"
fi
