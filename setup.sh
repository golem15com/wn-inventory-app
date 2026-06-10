#!/bin/bash
set -e
cd "$(dirname "$0")"

# ============================================================================
# setup.sh — Golem15 Stack client-scaffold orchestrator
# ============================================================================
# The single documented entry point for spinning up a new client project from
# the Golem15 starter stack. In SCAFFOLD mode it chains four steps (D-01):
#
#   1. scripts/reset-gsd.sh           — reset the starter into a fresh GSD client
#                                        project (guarded; refuses the canonical
#                                        starter origin / non-empty remote).
#   2. git remote set-url origin ...  — re-point the SUPERPROJECT (backend) git
#                                        origin at --backend-repo.
#   3. backend-init.sh                — composer install, migrate, admin seed,
#                                        mirror (DB_*/ADMIN_* forwarded as env).
#   4. scripts/frontend-init.sh       — scaffold the Vue frontend submodule from
#                                        --name/--frontend-repo (skipped with
#                                        --no-frontend).
#
# MODES (D-03/D-04):
#   SCAFFOLD MODE   — triggered when --backend-repo OR --name is supplied.
#                     Non-interactive; runs the full chain above. Reset is
#                     IMPLICIT and guarded (no separate --reset ack flag).
#   INTERACTIVE MODE — bare `./setup.sh` with no flags. Prompts for name /
#                     backend-repo / frontend-repo. If BOTH repos are left blank
#                     (plain local dev onboarding) it falls through to a plain
#                     `backend-init.sh` local install — today's behavior, NO
#                     reset. If a repo is entered, it continues into scaffold mode.
#
# Usage:
#   ./setup.sh                                          # interactive
#   ./setup.sh --backend-repo=<url> --name=<client> \
#              [--frontend-repo=<url>] [--db=mysql] \
#              [--admin-password=secret] [--admin-login=admin] \
#              [--admin-email=a@b.c] [--no-frontend] [--dry-run]
#   ./setup.sh --backend-repo <url> --name <client> ...  # space form also works
#
# --dry-run (D-05) propagates end-to-end: reset-gsd.sh and frontend-init.sh
# receive --dry-run; the backend repoint + backend-init.sh steps are PRINT-ONLY.
#
# Forwarded to backend-init.sh (D-06): --db -> DB_CONNECTION, --admin-password ->
# ADMIN_PASSWORD, --admin-login -> ADMIN_LOGIN, --admin-email -> ADMIN_EMAIL.
# (Dropped per D-07: there is no backend-skip flag, no milestone flag, and no
#  reset acknowledgement flag — those were intentionally removed.)
# ============================================================================

# --- Flag parsing ------------------------------------------------------------
# Support BOTH --flag=value and --flag value forms (consistent with
# scripts/frontend-init.sh). Boolean flags: --dry-run, --no-frontend.
DRY_RUN=0
NO_FRONTEND=0
BACKEND_REPO=""
FRONTEND_REPO=""
NAME=""
DB=""
ADMIN_PASSWORD=""
ADMIN_LOGIN=""
ADMIN_EMAIL=""

# Detect "no args at all" up front — this is what selects INTERACTIVE mode.
ARGC=$#

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run)            DRY_RUN=1 ;;
        --no-frontend)        NO_FRONTEND=1 ;;
        --backend-repo=*)     BACKEND_REPO="${1#*=}" ;;
        --backend-repo)       shift; BACKEND_REPO="$1" ;;
        --frontend-repo=*)    FRONTEND_REPO="${1#*=}" ;;
        --frontend-repo)      shift; FRONTEND_REPO="$1" ;;
        --name=*)             NAME="${1#*=}" ;;
        --name)               shift; NAME="$1" ;;
        --db=*)               DB="${1#*=}" ;;
        --db)                 shift; DB="$1" ;;
        --admin-password=*)   ADMIN_PASSWORD="${1#*=}" ;;
        --admin-password)     shift; ADMIN_PASSWORD="$1" ;;
        --admin-login=*)      ADMIN_LOGIN="${1#*=}" ;;
        --admin-login)        shift; ADMIN_LOGIN="$1" ;;
        --admin-email=*)      ADMIN_EMAIL="${1#*=}" ;;
        --admin-email)        shift; ADMIN_EMAIL="$1" ;;
        *)
            echo "Unknown argument: $1"
            echo "Usage: ./setup.sh --backend-repo=<url> --name=<client> [--frontend-repo=<url>] \\"
            echo "                  [--db=<conn>] [--admin-password=<p>] [--admin-login=<l>] \\"
            echo "                  [--admin-email=<e>] [--no-frontend] [--dry-run]"
            echo "       ./setup.sh                 # interactive mode (no flags)"
            exit 1
            ;;
    esac
    shift
done

# run(): route every mutating step through here so --dry-run touches nothing.
run() {
    if [ "$DRY_RUN" = "1" ]; then
        echo "[dry-run] would: $*"
    else
        eval "$@"
    fi
}

# DRY_FLAG is appended to sub-scripts that understand --dry-run.
DRY_FLAG=""
[ "$DRY_RUN" = "1" ] && DRY_FLAG=" --dry-run"

echo "=== setup.sh ==="
if [ "$DRY_RUN" = "1" ]; then
    echo "==> DRY RUN: nothing destructive will run (no reset, repoint, install, or scaffold)."
fi

# --- INTERACTIVE MODE (D-03) -------------------------------------------------
# Bare `./setup.sh` with no args prompts for the three inputs in a sensible
# order (name -> backend-repo -> frontend-repo), blanks allowed. If BOTH repos
# come back blank, fall through to a plain local install (NO reset). Otherwise
# the entered values feed straight into scaffold mode below.
if [ "$ARGC" -eq 0 ]; then
    echo ""
    echo "==> Interactive setup. Leave both repos blank for a plain local dev install."
    printf "Client name (slug, e.g. acme) [blank for local install]: "
    read -r NAME
    printf "Backend (superproject) git repo URL [blank = local install]: "
    read -r BACKEND_REPO
    printf "Frontend git repo URL [blank = skip frontend scaffold]: "
    read -r FRONTEND_REPO

    # Both repos blank -> today's behavior: plain local install, no reset.
    if [ -z "$BACKEND_REPO" ] && [ -z "$FRONTEND_REPO" ]; then
        echo ""
        echo "==> No repos given — running a plain local install (backend-init.sh), no reset."
        exec bash backend-init.sh
    fi
    # A repo was entered -> continue into scaffold mode with the prompted values.
    echo ""
    echo "==> Repo(s) supplied — proceeding with client scaffold."
fi

# --- SCAFFOLD MODE GUARD -----------------------------------------------------
# Runs even under --dry-run (mirrors frontend-init.sh's leading guard). In
# scaffold mode both --name and --backend-repo are required. The reset origin
# guard itself is NOT re-implemented here — step 1 delegates to reset-gsd.sh.
echo ""
echo "==> Guard: validate scaffold inputs"
if [ -z "$NAME" ] || [ -z "$BACKEND_REPO" ]; then
    echo "Refusing: scaffold mode requires both --name and --backend-repo."
    echo "  ./setup.sh --backend-repo=git@github.com:org/<client>.git --name=<client> [--frontend-repo=<url>]"
    echo "  (Or run bare ./setup.sh for interactive / plain local install.)"
    exit 1
fi
echo "Guard passed: name='$NAME', backend-repo='$BACKEND_REPO', frontend-repo='${FRONTEND_REPO:-(none)}'."

# --- STEP 1: RESET (implicit, guarded, D-04) ---------------------------------
# Delegate to scripts/reset-gsd.sh; do NOT bypass its origin/empty-remote guard.
# Propagate --dry-run. Under `set -e` a refused reset aborts setup.
echo ""
echo "==> Step 1: reset starter into a fresh client project (scripts/reset-gsd.sh)"
run "bash scripts/reset-gsd.sh${DRY_FLAG}"

# --- STEP 2: BACKEND ORIGIN REPOINT (D-01) -----------------------------------
# Re-point the SUPERPROJECT origin to --backend-repo. Print-only under --dry-run
# (D-05): the repoint goes through run(), which echoes instead of executing.
echo ""
echo "==> Step 2: re-point the superproject (backend) origin to '$BACKEND_REPO'"
run "git remote set-url origin \"$BACKEND_REPO\""

# --- STEP 3: BACKEND INSTALL (D-01) ------------------------------------------
# Forward --db/--admin-* into backend-init.sh as env vars. Print-only under
# --dry-run. Do NOT pass --reset — the reset already ran in step 1.
echo ""
echo "==> Step 3: install the backend (backend-init.sh)"
BACKEND_ENV=""
[ -n "$DB" ]             && BACKEND_ENV="$BACKEND_ENV DB_CONNECTION=\"$DB\""
[ -n "$ADMIN_PASSWORD" ] && BACKEND_ENV="$BACKEND_ENV ADMIN_PASSWORD=\"$ADMIN_PASSWORD\""
[ -n "$ADMIN_LOGIN" ]    && BACKEND_ENV="$BACKEND_ENV ADMIN_LOGIN=\"$ADMIN_LOGIN\""
[ -n "$ADMIN_EMAIL" ]    && BACKEND_ENV="$BACKEND_ENV ADMIN_EMAIL=\"$ADMIN_EMAIL\""
run "${BACKEND_ENV# }${BACKEND_ENV:+ }bash backend-init.sh"

# --- STEP 4: FRONTEND SCAFFOLD (D-01) ----------------------------------------
# Skipped entirely with --no-frontend. Otherwise delegate to
# scripts/frontend-init.sh, forwarding --name/--repo and propagating --dry-run.
echo ""
if [ "$NO_FRONTEND" = "1" ]; then
    echo "==> Step 4: frontend scaffold SKIPPED (--no-frontend)."
elif [ -z "$FRONTEND_REPO" ]; then
    echo "==> Step 4: frontend scaffold SKIPPED (no --frontend-repo supplied)."
else
    echo "==> Step 4: scaffold the frontend (scripts/frontend-init.sh)"
    run "bash scripts/frontend-init.sh --name=\"$NAME\" --repo=\"$FRONTEND_REPO\"${DRY_FLAG}"
fi

# --- CLOSING NEXT-STEP BLOCK -------------------------------------------------
echo ""
echo "=== setup done ==="
echo "Client '$NAME' scaffolded: starter reset, backend origin -> '$BACKEND_REPO', backend installed."
if [ "$NO_FRONTEND" != "1" ] && [ -n "$FRONTEND_REPO" ]; then
    echo "Frontend submodule scaffolded -> '$FRONTEND_REPO'."
fi
echo "Next steps:"
echo "  1. Review the working tree + .gitmodules diff, then commit the scaffolded state."
echo "  2. Run /gsd-new-project to author the client's first milestone."
if [ "$DRY_RUN" = "1" ]; then
    echo "(dry-run: nothing was actually reset, repointed, or installed.)"
fi
