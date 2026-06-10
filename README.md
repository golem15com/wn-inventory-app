<p align="center">
    <img src=".github/assets/golem15-logo.png" alt="Golem15 Logo" width="120" />
</p>

<h1 align="center">Golem15 Starter</h1>

<p align="center">
    A battle-tested, full-stack CMS framework built on WinterCMS and Laravel.<br/>
    Ship content sites, SaaS apps, e-commerce stores, and API backends from a single codebase.
</p>

<p align="center">
    <strong>18 custom plugins</strong> &middot; <strong>One-command setup</strong> &middot; <strong>19+ production sites and counting</strong>
</p>

---

## What is this?

Golem15 Starter is the foundation we use to build and ship every project at [Golem15](https://golem15.com). It extends [WinterCMS](https://wintercms.com) (Laravel 9.x) with a curated set of plugins for payments, authentication, real-time features, AI, multilingual content, and more.

Instead of wiring up the same infrastructure for every new project, you clone this starter, run `./backend-init.sh`, and start building features. (For provisioning a brand-new client project end to end, `./setup.sh` is the scaffold orchestrator — see [Setup options](#setup-options).)

**Projects built on this stack include:** personal portfolio APIs, automotive marketplaces, Bible quote apps, gaming communities, genealogy trees, e-commerce stores, travel guides, horoscope portals, language tools, mushroom identification sites, trade professional directories, taxi services, and tax management systems.

## Quick Start

> **Important:** Always **fork** this repository before starting a new project. The starter is a template - your project should live in its own repo so you can evolve independently while still being able to pull upstream improvements.

```bash
# 1. Fork this repo on GitHub/Gitea, then clone your fork
git clone <your-fork-url> my-project
cd my-project
git submodule update --init --recursive

# 2. One-command local install (SQLite by default, zero config)
./backend-init.sh

# 3. Start developing
php artisan serve
```

That's it. Open `http://localhost:8000` for the frontend and `/backend` for the admin panel (login: `admin` / `admin`).

### Setup options

The local installer (`./backend-init.sh`) takes all options as environment variables - no interactive prompts:

```bash
# Use MySQL instead of SQLite
DB_CONNECTION=mysql DB_DATABASE=mydb DB_USERNAME=root ./backend-init.sh

# Custom admin credentials
ADMIN_PASSWORD=secret ADMIN_EMAIL=me@example.com ./backend-init.sh

# Different PHP binary
PHP=php83 COMPOSER=composer83 ./backend-init.sh
```

For provisioning a fresh client project (reset the stack, repoint the backend origin, then
install backend + scaffold the Vue frontend), use the `./setup.sh` orchestrator instead. Run
it bare for interactive prompts, or pass flags (`--name`, `--backend-repo`, `--frontend-repo`,
`--db`, `--admin-*`, `--no-frontend`, `--dry-run`). The frontend/branch helpers live under
`scripts/` (`scripts/frontend-init.sh`, `scripts/all-develop.sh`).

### What `backend-init.sh` does

1. Initializes git submodules (all plugins)
2. Creates `.env` from `.env.example`
3. Installs Composer dependencies (two-pass for plugin dependency merging)
4. Generates application key
5. Runs database migrations
6. Seeds admin user
7. Mirrors public assets
8. Cleans up git status for module directories

## Plugin Architecture

Every plugin is a **git submodule** with its own repository, versioning, and composer dependencies. The root project uses [`wikimedia/composer-merge-plugin`](https://github.com/wikimedia/composer-merge-plugin) to automatically merge plugin-level `composer.json` files.

### Core Plugins

| Plugin | Icon | Description |
|--------|------|-------------|
| **[Apparatus](plugins/golem15/apparatus)** | `icon-cogs` | Foundation framework. Dependency injection, scenario-based workflows, route resolver, backend injector, job management, console tools. Required by most plugins. |
| **[User](plugins/golem15/user)** | `icon-user` | Enhanced authentication with JWT support, OAuth (Laravel Socialite), GDPR-compliant scheduled deletions, user impersonation, mail blocking, and API export. |

### Payment & Commerce

| Plugin | Icon | Description |
|--------|------|-------------|
| **[PaymentGateway](plugins/golem15/paymentgateway)** | `icon-money` | Complete payment processing with finite state machines, order management, shipping, multi-currency support, and precise decimal arithmetic via MoneyRight. 20+ mail templates. |
| **[PGStripe](plugins/golem15/pgstripe)** | `icon-stripe` | Stripe payment operator with Payment Intents API, 3DS2 support, webhook handling, and test/live mode configuration. |

### Content & SEO

| Plugin | Icon | Description |
|--------|------|-------------|
| **[FAQ](plugins/golem15/faq)** | `icon-question-circle` | FAQ management with backend editor and frontend component. |
| **[Sitemap](plugins/golem15/sitemap)** | `icon-sitemap` | XML sitemap generation with definition editor and multilingual support. |
| **[Translate](plugins/golem15/translate)** | `icon-language` | Full multilingual system - locale picker, message translation, 9 multilingual form widgets, AI-powered translation helpers, theme/page/mail template translation. |
| **[Journal](plugins/golem15/journal)** | `icon-book` | Headless-capable blog/content system - posts, categories, RSS, JSON API (`/_journal/api/v1`), multilingual, menu-item integration. Powers the Vue starter's blog. |
| **[Quote](plugins/golem15/quote)** | `icon-leaf` | AI-powered quote generation with scheduled daily generation and frontend display component. |

### Real-time & Communication

| Plugin | Icon | Description |
|--------|------|-------------|
| **[WebSockets](plugins/golem15/websockets)** | `icon-bolt` | Real-time communication via Centrifugo. Broadcasting, channel authorization, push notifications with VAPID keys. |
| **[Chat](plugins/golem15/chat)** | `icon-comments` | Real-time chat with decoupled context providers, channel management, and adapter registration for external plugins. |
| **[ChatVideo](plugins/golem15/chatvideo)** | `icon-video-camera` | Video-call layer on top of Chat - WebRTC signaling over Centrifugo channels. |
| **[UserFriends](plugins/golem15/userfriends)** | `icon-users` | Social graph for User - friend requests, acceptance, and relationship management. |

### Developer Tools & Integrations

| Plugin | Icon | Description |
|--------|------|-------------|
| **[GitHub](plugins/golem15/github)** | `icon-github` | GitHub API integration - fetch issues/PRs, start work, close issues from the command line. |
| **[DualFormWidget](plugins/golem15/dualformwidget)** | `icon-leaf` | Dual input form widget for paired values in backend forms. |
| **[KnobWidget](plugins/golem15/knobwidget)** | `icon-cog` | Knob/dial form widget for numeric input with AJAX handler support. |

### Bundled Winter Plugins

| Plugin | Purpose |
|--------|---------|
| **[Winter.Location](plugins/winter/location)** | Country & state data |
| **[Winter.Debugbar](plugins/winter/debugbar)** | Debug toolbar for development |

### Plugin Dependency Graph

```
Apparatus ─────────────┬──── PaymentGateway ──── PGStripe
                       │
User ──────────────────┼──── WebSockets ──── Chat
                       │
                       ├──── GitHub
                       └──── Quote (+ AI)
```

## Project Structure

```
.
├── config/                 # App configuration
├── modules/                # WinterCMS core (system, backend, cms)
├── plugins/
│   ├── golem15/            # 18 Golem15 plugins (git submodules)
│   └── winter/             # 2 Winter plugins (debugbar, location) (git submodules)
├── themes/                 # CMS themes
├── storage/                # Cache, logs, uploads, SQLite DB
├── backend-init.sh         # One-command local install
├── setup.sh                # Client-scaffold orchestrator
├── scripts/                # Helpers (frontend-init.sh, all-develop.sh, reset-gsd.sh, ...)
├── CLAUDE.md               # AI assistant instructions
└── composer.json            # Root deps + plugin merge config
```

## Common Commands

```bash
# Database
php artisan winter:up               # Run all migrations
php artisan winter:down             # Drop all tables
php artisan migrate                 # Run pending migrations

# Cache
php artisan cache:clear
php artisan queue:clear

# Testing
php artisan winter:test                        # Run core tests
php artisan winter:test Golem15.PaymentGateway # Test specific plugin
composer test                                  # PHPUnit
composer lint                                  # Syntax check
composer sniff                                 # PSR code standards

# Payment operations
php artisan pg:cancel-created-payments
php artisan pg:cancel-placed-orders
php artisan pg:finish-orders
php artisan pg:update-currencies

# Translation
php artisan translate:scan                     # Scan for translatable strings
php artisan translate:export                   # Export translations
php artisan translate:plugin-translate-ai      # AI-assisted translation

# User management
php artisan user:process-scheduled-deletions   # GDPR: process deletions

# WebSockets
php artisan websockets:health                  # Check Centrifugo status
php artisan websockets:test-push               # Test push notification

# Git helpers
php artisan g15:sane-git                       # Clean git status for modules
php artisan g15:sane-git --insane              # Revert skip-worktree

# Mail templates
php artisan apparatus:mail-export
php artisan apparatus:mail-import
php artisan apparatus:mail-reset
```

## Working with Submodules (SSU)

This project manages 21 git submodules (18 Golem15 plugins, 2 Winter plugins, and the `vue-starter-app` frontend). We strongly recommend [**SSU**](https://ssu.pxpx.co.uk) (Smart Submodule Updater) instead of raw git commands - it handles branch detection, conflict resolution, parallel fetching, and automatic backups.

### Install SSU

```bash
curl -fsSL https://ssu.pxpx.co.uk | bash
```

This downloads the latest binary for your platform and installs it to `~/.local/bin`. Restart your shell or add it to your PATH.

### Daily workflow

```bash
# See the state of every submodule at a glance
ssu status
```

```
┌──────────────────────────────────────┬───────────────┬─────────────┬──────────────┐
│Path                                  │Branch         │Behind       │Status        │
├──────────────────────────────────────┼───────────────┼─────────────┼──────────────┤
│plugins/golem15/apparatus             │develop        │0            │current       │
│plugins/golem15/paymentgateway        │develop        │3            │behind        │
│plugins/golem15/user                  │develop        │0            │current       │
│plugins/golem15/journal               │master         │2            │behind        │
└──────────────────────────────────────┴───────────────┴─────────────┴──────────────┘
```

**Status meanings:**
- **current** - Up to date, nothing to do
- **behind** - Remote has new commits, run `ssu update` to pull them in
- **ahead** - You have unpushed local commits, run `ssu push` to publish them
- **modified** - Uncommitted local changes in the submodule
- **missing** - Submodule directory is empty, run `git submodule update --init`

```bash
# Pull latest changes for all submodules (parallel fetch, auto-merge)
ssu update

# Push any submodules that have unpushed commits
ssu push

# Commit updated submodule pointers in the root project
ssu project
ssu project -m "chore: update plugins to latest"

# Preview what would happen without changing anything
ssu update --dry-run
ssu push --dry-run

# Run a command across all submodules
ssu exec -- git log --oneline -3

# Fix detached HEAD states (common after git submodule update)
ssu checkout

# Fully automatic mode for CI/CD (no prompts)
ssu update --auto && ssu push --auto
```

### SSU vs raw git

| Task | Raw git | SSU |
|------|---------|-----|
| Check status | `git submodule foreach 'git status'` | `ssu status` |
| Update all | `git submodule update --remote --merge` | `ssu update` |
| Push all | Manual `cd` into each submodule | `ssu push` |
| Commit pointers | `git add plugins/... && git commit` | `ssu project` |
| Conflict handling | Manual | Automatic with backups |
| Parallel fetching | No | Yes (8 jobs default) |

### Manual workflow (without SSU)

If you prefer raw git commands:

```bash
cd plugins/golem15/apparatus
git checkout develop && git pull

# Make changes, commit, push
git add . && git commit -m "Your change" && git push

# Update root project reference
cd ../../..
git add plugins/golem15/apparatus
git commit -m "Update apparatus submodule"
```

## Scheduled Tasks

The PaymentGateway registers automatic maintenance tasks:

| Task | Frequency |
|------|-----------|
| Cancel sent payments | Daily |
| Cancel created payments | Daily |
| Cancel placed orders | Daily |
| Finish completed orders | Daily |
| Update currency rates | Every 10 minutes |

Enable the Laravel scheduler via cron:

```bash
* * * * * cd /path/to/project && php artisan schedule:run >> /dev/null 2>&1
```

## Requirements

- **PHP** >= 8.4
- **Composer** 2.x
- **Database**: SQLite (default), MySQL, or PostgreSQL
- **Optional**: Centrifugo (for WebSockets), Stripe account (for payments)

## Built on

- [WinterCMS](https://wintercms.com) - Open-source CMS platform
- [Laravel 9.x](https://laravel.com) - PHP framework
- [Storm Library](https://github.com/wintercms/storm) - Stability layer between Laravel and Winter

## License

MIT
