# syntax=docker/dockerfile:1
# =============================================================================
# Inventory SPA image (vue-inventory-app) — static `nuxt generate` + lean nginx.
# =============================================================================
# The Vue app has NO server/ dir (verified) → a fully static generate is safe.
# It addresses the backend with SAME-ORIGIN relative paths (/_inventory/api,
# /_user/api, /storage, ...) — the edge proxy unifies the origin in production,
# so this container serves ONLY the static bundle (no API proxying here).
#
# All deps are public npm (no private/keios deps) → NO BuildKit SSH secret.
# Build context is the repo ROOT (see docker-compose.yml); .dockerignore keeps
# vue-inventory-app/{node_modules,.nuxt,.output,dist} out so only SOURCE enters.
# =============================================================================

# --- Stage 1: build the static bundle with pnpm + nuxt generate --------------
FROM node:22-alpine AS builder
WORKDIR /spa

# Enable corepack-managed pnpm (version pinned by the SPA's packageManager field
# / lockfile). corepack ships with the node:22 image.
RUN corepack enable

# Copy only the SPA source (the .dockerignore excludes its build artifacts).
COPY vue-inventory-app/ /spa/

# Install pinned deps from the committed lockfile (T-11-27 supply-chain pin).
RUN pnpm install --frozen-lockfile

# Emit the fully static site to /spa/.output/public (Nuxt 4 static output).
# NUXT_SPA_MODE=1 forces ssr:false (see nuxt.config.ts) so protected client-auth
# routes are NOT prerendered into redirect-to-/login stubs — the self-host build
# must be a pure SPA that resolves auth in the browser from the cookie.
RUN NUXT_SPA_MODE=1 pnpm generate

# --- Stage 2: serve the static output via a lean nginx -----------------------
FROM nginx:alpine AS runtime
COPY --from=builder /spa/.output/public /usr/share/nginx/html
COPY docker/spa.nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
