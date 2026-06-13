# Self-Hosting Inventory (whereiput.it)

A turnkey Docker path for running your own Inventory instance. The published
image bakes a fully-resolved `vendor/` at build time, so you never resolve the
private Golem15 composer dependencies yourself.

## TL;DR

```bash
# 1. Build the image (needs the keios SSH key as a BuildKit secret — D-14)
DOCKER_BUILDKIT=1 docker build --ssh default -t inventory-app .

# 2. Configure
cp .env.docker.example .env.docker
#   edit ADMIN_EMAIL + a STRONG ADMIN_PASSWORD (and TYPESENSE_API_KEY for full)

# 3a. Light — SQLite, zero external services
docker compose --profile light up

# 3b. Full — Postgres + Typesense + queue worker
docker compose --profile full up
```

Then open <http://localhost:8088>.

---

## Building the image (D-14 — private deps baked in)

Inventory depends on private Golem15 packages (`keios/laravel-apparatus` via a
private GitHub VCS). `composer install` runs **at build time** with your SSH key
mounted as a **BuildKit secret** — the key is exposed only for that build step
and is **never** written into an image layer:

```bash
DOCKER_BUILDKIT=1 docker build --ssh default -t inventory-app .
```

- `DOCKER_BUILDKIT=1` enables BuildKit (required for `--mount=type=ssh`).
- `--ssh default` forwards your local SSH agent. Make sure your key with access
  to the private repos is loaded: `ssh-add -l`.
- The resulting image carries a complete `vendor/`. A self-hoster who pulls the
  image never needs SSH access — only the original **builder** does.

If the build fails with `Permission denied (publickey)`, your agent does not
have a key authorized for the private VCS — add it with `ssh-add`.

To build via compose instead:

```bash
DOCKER_BUILDKIT=1 docker compose --profile light build --ssh default
```

---

## Profiles (D-13)

### `light` — the zero-infra baseline

- **SQLite** database (a file on the persisted `storage` volume).
- **sync** queue (jobs run inline; no worker process).
- **No Typesense** by default — search degrades to the scoped DB-search
  fallback (Inventory's Plugin guards Scout with `class_exists`, so a missing
  search engine disables Typesense rather than breaking search).

```bash
docker compose --profile light up
```

Optional Typesense in light mode: run the `typesense-light` service and set
`SCOUT_DRIVER=typesense` in `.env.docker`:

```bash
docker compose --profile light --profile light-search up
```

### `full` — production-like

- **Postgres** database.
- **Typesense** search engine (`SCOUT_DRIVER=typesense`, wired automatically).
- A dedicated **queue worker** (`php artisan queue:work`).

```bash
docker compose --profile full up
```

After first boot, populate the search index from inside the app container:

```bash
docker compose --profile full exec app-full php artisan inventory:reindex
```

---

## Environment variables

All configured in `.env.docker` (copy from `.env.docker.example`):

| Variable | Purpose |
|----------|---------|
| `APP_KEY` | **Leave blank.** Generated ONCE on first boot and persisted. Must never rotate (see below). |
| `JWT_SECRET` | **Leave blank.** Generated once and persisted alongside `APP_KEY`. |
| `DB_CONNECTION` / `DB_*` | Set automatically by the profile (SQLite for light, Postgres for full). |
| `POSTGRES_DB/USER/PASSWORD` | Credentials for the `postgres` service (full profile). |
| `SCOUT_DRIVER` | `typesense` (full / opt-in light) or unset (light DB fallback). |
| `TYPESENSE_API_KEY` | Typesense admin key (full / light-search). |
| `ADMIN_EMAIL` / `ADMIN_PASSWORD` | The seeded frontend admin (D-15). Set a strong password. |
| `APP_PORT` | Host port mapped to the container (default `8088`). |

---

## APP_KEY must stay permanent (Pitfall 6)

`APP_KEY` encrypts every stored **BYOK API key** at rest. The entrypoint
generates it **once** and writes it to the persisted `storage` volume, then
reads the same value on every later start — it is never regenerated.

**If you rotate `APP_KEY`, every saved BYOK key is orphaned** (it can no longer
be decrypted) and realtime JWT auth breaks. When migrating to a new host, copy
the persisted `storage` volume (which holds `persisted.env` with `APP_KEY`)
along with your data.

---

## The admin seed & BYOK (D-15)

On first boot the entrypoint creates a **frontend** `admin` user group and a
default admin user from `ADMIN_EMAIL` / `ADMIN_PASSWORD`:

- **The seeded admin** can use AI immediately via the global Golem path (if a
  global vision model is configured) — they pass the AI gate by group membership.
- **Non-admin users** bring their own key: in the app, go to **Settings → AI**,
  pick a provider (Claude or OpenAI), and paste their own API key. The key is
  encrypted at rest with `APP_KEY`. Once saved, that user can use the AI
  photo-recognition (recognize) flow.

No password is baked into the image — it comes from your env. The seed is
**idempotent**: re-running with a different `ADMIN_PASSWORD` does **not**
overwrite an existing user. Change the password **in-app** instead.

---

## Restarting

The named volumes (`app_light_state` / `app_full_state`, `postgres_data`,
`typesense_data`) persist your data, `APP_KEY`, and `JWT_SECRET` across
restarts. After `docker compose ... down && ... up`, your `APP_KEY` is unchanged
and previously-saved BYOK keys still decrypt.

To wipe everything and start fresh, remove the volumes:

```bash
docker compose --profile light down -v
```
