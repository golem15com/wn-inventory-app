#!/bin/bash
set -e

# =============================================================================
# Inventory self-host entrypoint (Phase 11, D-15)
# =============================================================================
# Reuses the backend-init.sh LOGIC (winter:env / key:generate / jwt:secret /
# winter:up / admin seed / winter:mirror) but with two net-new behaviours the
# init script does NOT have:
#
#   1. APP_KEY PERSISTENCE (Pitfall 6 / T-11-22): APP_KEY (and JWT_SECRET) are
#      generated exactly ONCE and written to a persisted .env on a mounted
#      volume. Every subsequent start READS the existing value — it is NEVER
#      regenerated, because rotating APP_KEY would orphan every 'encrypted'
#      BYOK api_key (DecryptException) and break realtime JWT auth.
#
#   2. FRONTEND admin seed (Pitfall 4 / D-15): backend-init seeds a BACKEND
#      admin only. AiGate checks a FRONTEND Golem15\User group with code 'admin'
#      ($user->groups->pluck('code')->contains('admin')). So we create that
#      frontend UserGroup + a default frontend admin user from ADMIN_EMAIL /
#      ADMIN_PASSWORD (no password is ever baked into the image, T-11-23).
# =============================================================================

PHP="php"
# Suppress E_DEPRECATED from vendor (Laravel 9.x on PHP 8.4), mirroring backend-init.
ARTISAN="$PHP -d error_reporting=8191 artisan"

APP_DIR="${APP_DIR:-/var/www/html}"
cd "$APP_DIR"

log() { echo "==> $*"; }

# The persisted .env lives on a MOUNTED VOLUME (compose sets ENV_FILE to a path
# under storage/, e.g. /var/www/html/storage/persisted.env) so APP_KEY survives
# container rebuilds/restarts (Pitfall 6). Laravel/Winter, however, only reads
# $APP_DIR/.env — so we keep the canonical env on the volume and SYMLINK the
# app's .env to it. Editing either reflects in both; the volume is the source of
# truth that the APP_KEY persistence below relies on.
PERSISTED_ENV="${ENV_FILE:-$APP_DIR/.env}"
ENV_FILE="$PERSISTED_ENV"
if [ "$PERSISTED_ENV" != "$APP_DIR/.env" ]; then
    mkdir -p "$(dirname "$PERSISTED_ENV")"
    # First boot: migrate any baked .env into the persisted location.
    if [ ! -f "$PERSISTED_ENV" ] && [ -f "$APP_DIR/.env" ] && [ ! -L "$APP_DIR/.env" ]; then
        cp "$APP_DIR/.env" "$PERSISTED_ENV"
    fi
    # Point the app's .env at the persisted file on the volume.
    rm -f "$APP_DIR/.env"
    ln -sf "$PERSISTED_ENV" "$APP_DIR/.env"
fi

# --- env helper (update-or-append a key in $ENV_FILE) ------------------------
set_env() {
    local key="$1" value="$2"
    if grep -qE "^${key}=" "$ENV_FILE"; then
        sed -i "s|^${key}=.*|${key}=${value}|" "$ENV_FILE"
    else
        echo "${key}=${value}" >> "$ENV_FILE"
    fi
}
get_env() {
    grep -E "^$1=" "$ENV_FILE" 2>/dev/null | head -n1 | cut -d= -f2-
}

# --- 1. .env bootstrap -------------------------------------------------------
if [ ! -f "$ENV_FILE" ]; then
    log "Creating persisted .env from .env.docker.example..."
    if [ -f "$APP_DIR/.env.docker.example" ]; then
        cp "$APP_DIR/.env.docker.example" "$ENV_FILE"
    else
        cp "$APP_DIR/.env.example" "$ENV_FILE"
    fi
fi

# Forward container env (compose-provided) into the persisted .env so artisan
# reads a consistent file. APP_KEY / JWT_SECRET are handled below (persist-once).
for k in APP_NAME APP_URL APP_DEBUG APP_LOCALE \
         DB_CONNECTION DB_HOST DB_PORT DB_DATABASE DB_USERNAME DB_PASSWORD \
         QUEUE_CONNECTION CACHE_DRIVER SESSION_DRIVER \
         SCOUT_DRIVER TYPESENSE_HOST TYPESENSE_PORT TYPESENSE_API_KEY; do
    val="$(printenv "$k" || true)"
    if [ -n "${val}" ]; then
        set_env "$k" "$val"
    fi
done

# SQLite (light profile): ensure the db file exists on the persisted volume.
DB_CONNECTION="$(get_env DB_CONNECTION)"
if [ "$DB_CONNECTION" = "sqlite" ]; then
    SQLITE_PATH="$(get_env DB_DATABASE)"
    [ -z "$SQLITE_PATH" ] && SQLITE_PATH="$APP_DIR/storage/database.sqlite"
    set_env DB_DATABASE "$SQLITE_PATH"
    mkdir -p "$(dirname "$SQLITE_PATH")"
    touch "$SQLITE_PATH"
    log "SQLite database: $SQLITE_PATH"
fi

# --- 2. APP_KEY (generate ONCE, persist, never rotate — Pitfall 6) -----------
EXISTING_KEY="$(get_env APP_KEY)"
if [ -z "$EXISTING_KEY" ] && [ -n "${APP_KEY:-}" ]; then
    # Operator supplied APP_KEY via env on first boot — honour & persist it.
    EXISTING_KEY="$APP_KEY"
    set_env APP_KEY "$APP_KEY"
fi
if [ -z "$EXISTING_KEY" ]; then
    log "Generating APP_KEY ONCE and persisting (it must never rotate)..."
    $ARTISAN key:generate --force --no-interaction
else
    log "APP_KEY already persisted — reusing (NOT regenerating)."
fi

# --- 3. JWT_SECRET (generate ONCE, persist) ----------------------------------
if ! grep -qE '^JWT_SECRET=.+' "$ENV_FILE"; then
    log "Generating JWT secret ONCE..."
    $ARTISAN jwt:secret --force --no-interaction || true
    if ! grep -qE '^JWT_SECRET=.+' "$ENV_FILE"; then
        JWT_SECRET_VALUE=$($PHP -r 'echo rtrim(strtr(base64_encode(random_bytes(48)), "+/", "__"), "=");')
        set_env JWT_SECRET "$JWT_SECRET_VALUE"
    fi
fi
$ARTISAN config:clear >/dev/null 2>&1 || true

# --- 4. Directories the stack expects ----------------------------------------
mkdir -p storage/temp/protected/paymentgateway storage/framework/cache \
         storage/framework/sessions storage/framework/views storage/logs
chown -R www-data:www-data storage bootstrap 2>/dev/null || true

# --- 5. Wait for the database (full profile: Postgres may still be booting) ---
if [ "$DB_CONNECTION" != "sqlite" ]; then
    log "Waiting for database ($DB_CONNECTION) to accept connections..."
    for i in $(seq 1 30); do
        if $ARTISAN db:show >/dev/null 2>&1; then
            break
        fi
        sleep 2
    done
fi

# --- 6. Migrations -----------------------------------------------------------
log "Running migrations (winter:up)..."
$ARTISAN winter:up

# --- 7. FRONTEND admin seed (D-15 — net-new vs backend-init) -----------------
# Create the FRONTEND Golem15\User group with code 'admin' (the one AiGate
# checks) + a default frontend admin user from env, idempotently. NO password
# literal is baked into the image — it comes from ADMIN_PASSWORD (T-11-23).
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@example.com}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-}"
ADMIN_USERNAME="${ADMIN_USERNAME:-admin}"
ADMIN_FIRST_NAME="${ADMIN_FIRST_NAME:-Admin}"
ADMIN_LAST_NAME="${ADMIN_LAST_NAME:-Person}"

if [ -z "$ADMIN_PASSWORD" ]; then
    log "WARNING: ADMIN_PASSWORD is empty — skipping frontend admin seed."
    log "         Set ADMIN_EMAIL + ADMIN_PASSWORD and restart to seed the admin."
else
    log "Seeding frontend admin group + user ($ADMIN_EMAIL)..."
    $ARTISAN tinker --execute="
        \$group = \Golem15\User\Models\UserGroup::where('code', 'admin')->first();
        if (!\$group) {
            \$group = new \Golem15\User\Models\UserGroup;
            \$group->forceFill([
                'name'        => 'Admin',
                'code'        => 'admin',
                'description' => 'Inventory AI-enabled administrators (D-15).',
            ]);
            \$group->save();
            echo \"Created frontend admin group.\n\";
        }
        \$user = \Golem15\User\Models\User::where('email', '${ADMIN_EMAIL}')->first();
        if (!\$user) {
            \$user = new \Golem15\User\Models\User;
            \$user->email                 = '${ADMIN_EMAIL}';
            \$user->username              = '${ADMIN_USERNAME}';
            \$user->first_name            = '${ADMIN_FIRST_NAME}';
            \$user->last_name             = '${ADMIN_LAST_NAME}';
            \$user->password              = '${ADMIN_PASSWORD}';
            \$user->password_confirmation = '${ADMIN_PASSWORD}';
            \$user->is_activated          = true;
            \$user->activated_at          = now();
            \$user->forceSave();
            echo \"Created frontend admin user.\n\";
        } else {
            echo \"Frontend admin user already exists (password unchanged).\n\";
        }
        if (!\$user->groups->pluck('code')->contains('admin')) {
            \$user->groups()->attach(\$group->id);
            echo \"Attached admin group to user.\n\";
        }
    "
fi

# --- 8. Public assets --------------------------------------------------------
log "Mirroring public assets (winter:mirror)..."
$ARTISAN winter:mirror public --relative >/dev/null 2>&1 || $ARTISAN winter:mirror public --relative

$ARTISAN config:clear >/dev/null 2>&1 || true

log "Boot complete — handing off to CMD."
# exec the container CMD (supervisord → php-fpm + nginx).
exec "$@"
