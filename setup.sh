#!/bin/bash
set -e

# ============================================================================
# Golem15 Stack - Non-interactive Setup
# ============================================================================
# Usage:
#   ./setup.sh                          # defaults: sqlite, admin/admin
#   DB_CONNECTION=mysql ./setup.sh      # use mysql instead
#   ADMIN_PASSWORD=secret ./setup.sh    # custom admin password
#
# Environment variables (all optional, defaults in .env.example):
#   DB_CONNECTION, DB_HOST, DB_PORT, DB_DATABASE, DB_USERNAME, DB_PASSWORD
#   ADMIN_EMAIL, ADMIN_LOGIN, ADMIN_PASSWORD, ADMIN_FIRST_NAME, ADMIN_LAST_NAME
# ============================================================================

# --- PHP / Composer binaries --------------------------------------------------
# Override with: PHP=php83 COMPOSER=composer83 ./setup.sh

PHP="${PHP:-php}"
COMPOSER="${COMPOSER:-composer}"

echo "Using: $PHP ($($PHP -r 'echo PHP_VERSION;'))"

# Suppress E_DEPRECATED warnings from vendor code (Laravel 9.x on PHP 8.4+)
# 8191 = E_ALL & ~E_DEPRECATED & ~E_USER_DEPRECATED
ARTISAN="$PHP -d error_reporting=8191 artisan"

# --- Git submodules ----------------------------------------------------------

echo ""
echo "==> Initializing git submodules..."
git submodule update --init --recursive

# --- Environment file (before composer so post-update-cmd scripts can boot) ---

# Helper: update or append a key in .env
set_env() {
    local key="$1" value="$2"
    if grep -q "^${key}=" .env; then
        sed -i "s|^${key}=.*|${key}=${value}|" .env
    else
        echo "${key}=${value}" >> .env
    fi
}

if [ ! -f .env ]; then
    echo ""
    echo "==> Creating .env from .env.example..."
    cp .env.example .env
fi

# Apply DB_CONNECTION override (default to sqlite for quick local setup)
DB_CONNECTION="${DB_CONNECTION:-sqlite}"
set_env DB_CONNECTION "$DB_CONNECTION"

# Forward any DB env vars the caller set
[ -n "${DB_HOST+x}" ]     && set_env DB_HOST "$DB_HOST"
[ -n "${DB_PORT+x}" ]     && set_env DB_PORT "$DB_PORT"
[ -n "${DB_DATABASE+x}" ] && set_env DB_DATABASE "$DB_DATABASE"
[ -n "${DB_USERNAME+x}" ] && set_env DB_USERNAME "$DB_USERNAME"
[ -n "${DB_PASSWORD+x}" ] && set_env DB_PASSWORD "$DB_PASSWORD"

# SQLite: create the database file if needed
if [ "$DB_CONNECTION" = "sqlite" ]; then
    SQLITE_PATH="${DB_DATABASE:-storage/database.sqlite}"
    if [[ "$SQLITE_PATH" != /* ]]; then
        SQLITE_PATH="$(pwd)/$SQLITE_PATH"
    fi
    set_env DB_DATABASE "$SQLITE_PATH"
    mkdir -p "$(dirname "$SQLITE_PATH")"
    touch "$SQLITE_PATH"
    echo "==> SQLite database: $SQLITE_PATH"
fi

# --- Composer (double-run for wikimedia/composer-merge-plugin) ----------------
# First run: install root deps + merge-plugin resolves plugin deps. --no-scripts
#   suppresses root scripts, but the merge plugin's internal update may still
#   trigger post-update-cmd. jms/serializer is pinned in root require to prevent
#   doctrine/instantiator version conflicts during partial-update resolution.
# Second run: safety net - ensures all merged deps are fully resolved.

echo ""
echo "==> Installing composer dependencies (pass 1 - root deps)..."
$COMPOSER install --no-interaction --no-scripts

echo ""
echo "==> Installing composer dependencies (pass 2 - plugin deps via merge plugin)..."
$COMPOSER update --no-interaction

# --- App key -----------------------------------------------------------------

echo ""
echo "==> Generating application key..."
$ARTISAN key:generate --force --no-interaction

# --- Directories -------------------------------------------------------------

mkdir -p storage/temp/protected/paymentgateway

# --- Database migration ------------------------------------------------------

echo ""
echo "==> Running migrations (winter:up)..."
$ARTISAN winter:up

# --- Admin user seeding ------------------------------------------------------

ADMIN_EMAIL="${ADMIN_EMAIL:-admin@example.com}"
ADMIN_LOGIN="${ADMIN_LOGIN:-admin}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-admin}"
ADMIN_FIRST_NAME="${ADMIN_FIRST_NAME:-Admin}"
ADMIN_LAST_NAME="${ADMIN_LAST_NAME:-Person}"

echo ""
echo "==> Configuring admin user ($ADMIN_LOGIN / $ADMIN_EMAIL)..."

$ARTISAN tinker --execute="
    \$admin = \Backend\Models\User::where('login', 'admin')->first();
    if (\$admin) {
        \$admin->email      = '${ADMIN_EMAIL}';
        \$admin->login      = '${ADMIN_LOGIN}';
        \$admin->password   = '${ADMIN_PASSWORD}';
        \$admin->password_confirmation = '${ADMIN_PASSWORD}';
        \$admin->first_name = '${ADMIN_FIRST_NAME}';
        \$admin->last_name  = '${ADMIN_LAST_NAME}';
        \$admin->save();
        echo \"Admin user updated.\n\";
    } else {
        \$seeder = new \Backend\Database\Seeds\SeedSetupAdmin;
        \$seeder->setDefaults([
            'email'     => '${ADMIN_EMAIL}',
            'login'     => '${ADMIN_LOGIN}',
            'password'  => '${ADMIN_PASSWORD}',
            'firstName' => '${ADMIN_FIRST_NAME}',
            'lastName'  => '${ADMIN_LAST_NAME}',
        ]);
        \$seeder->run();
        echo \"Admin user created.\n\";
    }
"

# --- Public assets -----------------------------------------------------------

echo ""
echo "==> Mirroring public assets..."
$ARTISAN winter:mirror public --relative

# --- Git status cleanup -------------------------------------------------------

echo ""
echo "==> Marking module changes as skip-worktree (git status sanity)..."
$ARTISAN g15:sane-git

# --- Done --------------------------------------------------------------------

echo ""
echo "============================================"
echo "  Setup complete!"
echo "  Admin: $ADMIN_LOGIN / $ADMIN_EMAIL"
echo "  Run:   $PHP artisan serve"
echo "============================================"
