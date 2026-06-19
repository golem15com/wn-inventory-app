# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Inventory** ([whereiput.it](https://whereiput.it)) is a personal/household inventory catalog for
physical things — cables, tools, batteries, devices — scattered across many places. You record
**what** you own, **which category** it belongs to, and **where** it physically lives (a Location
inside an Area), then find it instantly by searching instead of hunting through drawers and boxes.

It is built as a `Golem15\Inventory` plugin on the **Golem15 Stack** (WinterCMS — a Laravel-based
CMS forked from October CMS), with a Vue SPA front-end and a fast, permission-scoped search powered
by Typesense via Laravel Scout.

**Core Value:** Type the name of a thing and immediately see where it is — across every Area you have
access to. If everything else fails, search-to-location must work.

## Key Commands

### Environment Setup

```bash
# Local install (non-interactive, defaults to sqlite)
./backend-init.sh

# Or with env var overrides
DB_CONNECTION=mysql DB_DATABASE=mydb ADMIN_PASSWORD=secret ./backend-init.sh

# Manual setup
php artisan winter:env          # Generate .env file
php artisan winter:up           # Run migrations and create admin account
php artisan winter:mirror public --relative  # Create symlinks

# Self-hosting via Docker — see docs/SELF-HOSTING.md (light SQLite or full Postgres+Typesense)
```

### Development Commands
```bash
# Database
php artisan winter:up           # Run all migrations
php artisan winter:down         # Drop all tables
php artisan migrate             # Run pending migrations

# Cache
php artisan cache:clear
php artisan queue:clear

# Testing & quality
php artisan winter:test Golem15.Inventory  # Run Inventory plugin tests
composer test                   # Run PHPUnit tests
composer lint                   # Check syntax
composer sniff                  # Check code standards (PSR-1, PSR-2, PSR-4)

# Inventory
php artisan inventory:reindex   # Rebuild the Typesense index for Items (run after Tag/Category/Area renames)

# Apparatus
php artisan g15:sane-git            # Skip-worktree for git submodules
php artisan g15:sane-git --insane   # Revert skip-worktree
php artisan apparatus:mail-export   # Export mail templates
php artisan apparatus:mail-import   # Import mail templates
php artisan apparatus:mail-reset    # Reset mail templates to plugin defaults

# User
php artisan user:create                       # Create a backend user
php artisan user:process-scheduled-deletions  # GDPR: process expired scheduled deletions
```

### Git Submodules

Plugins and apps are managed as git submodules for independent version control. `.gitmodules` uses
public HTTPS URLs so an anonymous `git clone --recurse-submodules` works without credentials.

**6 Golem15 plugins** in `plugins/golem15/`:

| Dir | Repo | Role |
|-----|------|------|
| `apparatus` | `oc-apparatus-plugin` | Foundation framework (DI, scenarios, backend utils) — required by the others |
| `user` | `wn-user-plugin` | Frontend accounts, JWT API auth, OAuth, 2FA, GDPR |
| `backend` | `wn-backend-plugin` | Golem15-branded backend login + branding defaults |
| `golem` | `wn-golem-plugin` | AI integration (multiple engines, photo/face recognition via CompreFace) |
| `translate` | `wn-translate-plugin` | Multilingual support (fork of Winter.Translate) |
| `inventory` | `wn-inventory-plugin` | **The app itself** — Areas, Locations, Items, search, API |

**3 application submodules** (not WinterCMS plugins):

| Dir | Repo | Role |
|-----|------|------|
| `vue-inventory-app` | `vue-inventory-app` | The Vue SPA front-end (primary UI) |
| `inventory-mcp` | `inventory-mcp` | MCP server — search/CRUD/AI photo-assist from Claude Desktop/Code, Codex, any MCP client |
| `ha-inventory-addon` | `ha-inventory-addon` | Home Assistant integration (voice/automation) |

```bash
# After cloning
git submodule update --init --recursive

# Update all to latest
git submodule update --remote --merge

# Work on a specific plugin (commit to its own repo, then bump the superproject ref)
cd plugins/golem15/inventory
git checkout master && git pull
# ...changes, commit, push...
cd ../../../
git add plugins/golem15/inventory
git commit -m "Update inventory submodule reference"
```

Use `ssu` for submodule management. **Naming:** apparatus uses `oc-apparatus-plugin` (October
compatibility naming); all other Golem15 plugins use `wn-{name}-plugin`.

## Architecture & Structure

### WinterCMS Foundation
- **Core Modules**: System, Backend, CMS (in `modules/`)
- **Laravel**: 9.x · **Storm**: Winter's Laravel buffer layer · **PHP**: >= 8.4

### The Inventory Plugin (`plugins/golem15/inventory/`)

The domain model is **Area → Location → Item**:
- **Area** — a top-level place you have access to (the unit of permission scoping). `AreaEditor`
  grants per-Area access; `area_editors` is the join.
- **Location** — a physical spot inside an Area (drawer, shelf, box).
- **Item** — a thing, with an `ItemCategory` and many `Tag`s; lives in a Location.
- **AI credentials** — `UserAiCredential` / `OrgAiCredential` hold BYOK AI provider keys (per-user
  or shared org-wide) for the photo-assist flow.
- **ApiToken** — per-user tokens for the JSON API / MCP server.

**JSON API:** `/_inventory/api/v1/*` (defined in the plugin's `routes.php`).
**Search:** Typesense via `laravel/scout` — Items are indexed; `inventory:reindex` rebuilds.
**Permissions:** all access is **permission-scoped per-Area, enforced server-side including in search
results** — a user must never see another Area's items. This is the security-critical invariant.

**Tables** (all `golem15_inventory_*`): `areas`, `locations`, `items`, `item_categories`, `tags`,
`items_tags`, `area_editors`, `api_tokens`, `user_ai_credentials`, `org_ai_credentials`.

### Plugin Dependencies
- Most plugins declare `Golem15.Apparatus` in their `$require` array (WinterCMS enforces load order).
- Inventory builds on Apparatus + User; AI features use the Golem plugin.

### Important Architectural Patterns

**Apparatus Framework:**
- **Scenario System**: event-driven workflow engine (`keios/laravel-apparatus`) — check existing
  scenarios before writing ad-hoc multi-step logic.
- **Dependency Injection**: components implementing `NeedsDependencies` get `inject*` methods called
  automatically (`apparatus.dependencyInjector`, on `cms.page.initComponents`).
- **Route Resolver / Backend Injector**: custom route resolution + backend CSS/JS injection.
- **API token auth**: `token.auth` middleware → `Models/PersonalApiToken.php`.
- **Twig filters**: `ucfirst`, `human_date`, `raw_safe` (HTMLPurifier-backed — use instead of `|raw`
  for user HTML).

**User Plugin:**
- **JWT**: custom guard via `php-open-source-saver/jwt-auth`; `jwt.auth` / `jwt.refresh` middleware on
  API routes.
- **OAuth** (`laravel/socialite`), **2FA** (`pragmarx/google2fa` + `bacon/bacon-qr-code`),
  **WebAuthn** (`lbuchs/webauthn`), **reCAPTCHA** (`google/recaptcha`).
- **GDPR**: scheduled deletion via `user:process-scheduled-deletions`.
- **Multi-model**: detects `Golem15\User` or `Winter\User`.

**Model Extension Pattern:** plugins extend other models dynamically (no inheritance coupling):
```php
User::extend(function ($model) {
    $model->hasMany['items'] = [Item::class, 'key' => 'user_id'];
});
```

**Translation System:** `Golem15\Translate` (fork of Winter.Translate). Apparatus auto-scans
`plugins/*/*/components/*/*.htm` for translatable strings. Template syntax: `{{ 'English string'|_ }}`.

## Critical Framework Constraints

### WinterCMS Snowboard Framework
Snowboard does **not** support the `data-request-success` attribute (removed as unsafe — eval). Use
JS event handlers instead. (Relevant only for CMS-side JS; the Vue SPA is the primary front-end.)

```javascript
document.addEventListener('ajax:update', function (event) {
    if (event.detail.handler === 'onYourHandler') {
        // success code
    }
});
```

### Composer Plugin Merging
`wikimedia/composer-merge-plugin` auto-merges each plugin's `composer.json` into the root dependency
tree. Plugin dependencies live in `plugins/*/*/composer.json`. (Root `composer.json` declares PHP
`>=8.1`, but the runtime requirement is **>= 8.4**.)

## Configuration Files

- `.env` — runtime config (generated from `.env.example`); see `docs/SELF-HOSTING.md` for `.env.docker`
- `config/app.php`, `config/cms.php`, `config/database.php` — main configs
- `config/dev/` — development overrides
- Plugin configs in `plugins/golem15/*/config/`
- JWT config publishes to `config/jwt.php`, `config/auth.php` (User plugin)
- Search: `TYPESENSE_*` env vars + `laravel/scout` config (Inventory)

## Development Notes

- **PHP >= 8.4** required
- Search-to-location is the core value — never regress it; keep the Typesense index in sync
  (`inventory:reindex` after bulk renames).
- Per-Area permission scoping must be enforced **server-side, including in search results**.
- Apparatus scenarios over ad-hoc workflows — check existing ones first.
- File structure follows WinterCMS conventions (controllers, models, components in plugin root);
  backend forms/lists in `models/*/fields.yaml` and `columns.yaml`.
- Backend translation keys: `plugin.namespace::lang.section.key`.

## Standards & Conventions

- **PSR-1/PSR-2** via `phpcs.xml`, with WinterCMS exceptions: `PSR1.Methods.CamelCapsMethodName`
  excluded (allows AJAX handlers like `onSave`, `onDelete`); `Generic.Files.LineLength` excluded.
- **Methods**: `camelCase`; **AJAX handlers**: `on{Action}`; **plugin hooks**: `pluginDetails()`,
  `registerComponents()`, `registerMarkupTags()`, `registerPermissions()`, etc.
- **EditorConfig**: 4-space indent, LF line endings, UTF-8, trailing whitespace trimmed, final newline.
