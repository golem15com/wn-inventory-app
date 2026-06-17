# syntax=docker/dockerfile:1
# =============================================================================
# Inventory (whereiput.it) — self-host image (Phase 11, D-13/D-14)
# =============================================================================
# A PHP 8.4 image that bakes a fully-resolved vendor/ at BUILD time. composer
# install runs here with the private keios SSH key mounted as a BuildKit *secret*
# (--mount=type=ssh) so the published image carries vendor/ and an outside
# self-hoster NEVER has to resolve the private VCS deps (D-14). The SSH key is
# never COPYed into a layer (T-11-21 / Pitfall 5).
#
#   Build:  DOCKER_BUILDKIT=1 docker build --ssh default -t inventory-app .
#
# Two-stage build: `builder` resolves vendor/ with composer; `runtime` is a lean
# php-fpm + nginx image (no composer, no SSH key) that COPYs the baked vendor/.
# =============================================================================

# -----------------------------------------------------------------------------
# Stage 1: builder — resolve vendor/ with the private SSH key as a build secret
# -----------------------------------------------------------------------------
FROM php:8.4-cli AS builder

# Build deps: git (composer VCS), unzip/zip (composer archives), patch (winter
# storm patch applied by the root post-install script), libs for the PHP
# extensions the stack compiles (zip, gd, pgsql, intl).
RUN apt-get update && apt-get install -y --no-install-recommends \
        git unzip zip patch openssh-client \
        libzip-dev libpng-dev libjpeg-dev libfreetype6-dev \
        libpq-dev libicu-dev libonig-dev libsqlite3-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j"$(nproc)" \
        pdo_sqlite pdo_mysql pdo_pgsql mbstring bcmath zip gd intl exif \
    && rm -rf /var/lib/apt/lists/*

# composer (pinned major) from the official image
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Trust github.com so the SSH-secret clone of the private keios VCS does not
# stall on an interactive host-key prompt.
RUN mkdir -p -m 0700 /root/.ssh \
    && ssh-keyscan github.com >> /root/.ssh/known_hosts 2>/dev/null

WORKDIR /app

# Copy the whole app (the .dockerignore keeps vendor/, .git, node_modules, .env,
# the SPA build, and .planning out of the context so the build stays lean).
COPY . /app

# Double composer run mirrors backend-init.sh: pass 1 resolves root deps + the
# wikimedia merge-plugin discovers plugins/*/*/composer.json (where Inventory now
# declares scout+typesense, Plan 11-05); pass 2 fully resolves the merged tree.
# --mount=type=ssh exposes the host SSH agent ONLY for the duration of the RUN
# layer — the key is never written to disk, never lands in an image layer.
ENV COMPOSER_ALLOW_SUPERUSER=1
RUN --mount=type=ssh \
        composer install --no-interaction --no-dev --no-scripts --no-progress \
        || composer update --no-interaction --no-dev --no-scripts --no-progress
RUN --mount=type=ssh \
        composer update --no-interaction --no-dev --no-progress --optimize-autoloader

# Apply the winter/storm PHP 8.4 null-offset patch the root scripts apply.
RUN patch -p1 -d vendor/winter/storm < patches/winter-storm-php84-null-offset.patch 2>/dev/null || true

# -----------------------------------------------------------------------------
# Stage 2: runtime — php-fpm + nginx, no composer, no SSH key, baked vendor/
# -----------------------------------------------------------------------------
FROM php:8.4-fpm AS runtime

# Runtime SHARED libs only (no compilers, no -dev headers) + nginx + supervisor.
# The PHP extensions are COMPILED in the builder stage and COPYed in below, so the
# lean runtime never recompiles them — it only needs the shared libs they link to.
RUN apt-get update && apt-get install -y --no-install-recommends \
        nginx supervisor \
        libzip5 libpng16-16 libjpeg62-turbo libfreetype6 \
        libpq5 libicu76 libonig5 libsqlite3-0 \
    && rm -rf /var/lib/apt/lists/*

# Bring the extensions built in stage 1 (pdo_*, mbstring, bcmath, zip, gd, intl,
# exif) and their enabling ini files, instead of recompiling in the runtime image.
COPY --from=builder /usr/local/lib/php/extensions /usr/local/lib/php/extensions
COPY --from=builder /usr/local/etc/php/conf.d/docker-php-ext-*.ini /usr/local/etc/php/conf.d/

# Sensible PHP production defaults (uploads for the AI photo path: 10MB cap +
# headroom; memory for composer-free artisan commands at boot).
RUN { \
        echo "upload_max_filesize=16M"; \
        echo "post_max_size=20M"; \
        echo "memory_limit=512M"; \
        echo "expose_php=Off"; \
    } > /usr/local/etc/php/conf.d/inventory.ini

WORKDIR /var/www/html

# Bring the app in WITHOUT vendor (the COPY below pulls the baked vendor/ from
# the builder, so the published runtime image carries fully-resolved private deps).
COPY . /var/www/html
COPY --from=builder /app/vendor /var/www/html/vendor

# nginx + supervisor + entrypoint config
COPY docker/nginx.conf /etc/nginx/sites-available/default
COPY docker/supervisord.conf /etc/supervisor/conf.d/inventory.conf
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh \
    && chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap 2>/dev/null || true

EXPOSE 80

# entrypoint persists APP_KEY, seeds the frontend admin, migrates, mirrors public;
# CMD starts supervisor (php-fpm + nginx). exec "$@" in the entrypoint runs CMD.
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/inventory.conf", "-n"]
