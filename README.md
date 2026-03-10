<p align="center">
    <img src=".github/assets/golem15-logo.png" alt="Golem15 Logo" width="120" />
</p>

<h1 align="center">Golem15 Starter</h1>

<p align="center">
    A battle-tested, full-stack CMS framework built on WinterCMS and Laravel.<br/>
    Ship content sites, SaaS apps, e-commerce stores, and API backends from a single codebase.
</p>

<p align="center">
    <strong>15 custom plugins</strong> &middot; <strong>One-command setup</strong> &middot; <strong>19+ production sites and counting</strong>
</p>

---

## What is this?

Golem15 Starter is the foundation we use to build and ship every project at [Golem15](https://golem15.com). It extends [WinterCMS](https://wintercms.com) (Laravel 9.x) with a curated set of plugins for payments, authentication, real-time features, AI, multilingual content, and more.

Instead of wiring up the same infrastructure for every new project, you clone this starter, run `./setup.sh`, and start building features.

**Projects built on this stack include:** personal portfolio APIs, automotive marketplaces, Bible quote apps, gaming communities, genealogy trees, e-commerce stores, travel guides, horoscope portals, language tools, mushroom identification sites, trade professional directories, taxi services, and tax management systems.

## Quick Start

```bash
# Clone with all plugin submodules
git clone <repository-url> my-project
cd my-project
git submodule update --init --recursive

# One-command setup (SQLite by default, zero config)
./setup.sh

# Start developing
php artisan serve
```

That's it. Open `http://localhost:8000` for the frontend and `/backend` for the admin panel (login: `admin` / `admin`).

### Setup options

All options are environment variables - no interactive prompts:

```bash
# Use MySQL instead of SQLite
DB_CONNECTION=mysql DB_DATABASE=mydb DB_USERNAME=root ./setup.sh

# Custom admin credentials
ADMIN_PASSWORD=secret ADMIN_EMAIL=me@example.com ./setup.sh

# Different PHP binary
PHP=php83 COMPOSER=composer83 ./setup.sh
```

### What `setup.sh` does

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
| **[Quote](plugins/golem15/quote)** | `icon-leaf` | AI-powered quote generation with scheduled daily generation and frontend display component. |

### Real-time & Communication

| Plugin | Icon | Description |
|--------|------|-------------|
| **[WebSockets](plugins/golem15/websockets)** | `icon-bolt` | Real-time communication via Centrifugo. Broadcasting, channel authorization, push notifications with VAPID keys. |
| **[Chat](plugins/golem15/chat)** | `icon-comments` | Real-time chat with decoupled context providers, channel management, and adapter registration for external plugins. |

### Developer Tools & Integrations

| Plugin | Icon | Description |
|--------|------|-------------|
| **[GitHub](plugins/golem15/github)** | `icon-github` | GitHub API integration - fetch issues/PRs, start work, close issues from the command line. |
| **[DualFormField](plugins/golem15/dualformfield)** | `icon-leaf` | Dual input form widget for paired values in backend forms. |
| **[KnobWidget](plugins/golem15/knobwidget)** | `icon-cog` | Knob/dial form widget for numeric input with AJAX handler support. |

### Bundled Winter Plugins

| Plugin | Purpose |
|--------|---------|
| **[Winter.Pages](plugins/winter/pages)** | Static page management |
| **[Winter.Blocks](plugins/winter/blocks)** | Content block system |
| **[Winter.Redirect](plugins/winter/redirect)** | URL redirect management |
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
│   ├── golem15/            # 15 Golem15 plugins (git submodules)
│   └── winter/             # 5 Winter plugins (git submodules)
├── themes/                 # CMS themes
├── storage/                # Cache, logs, uploads, SQLite DB
├── setup.sh                # One-command project setup
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

## Working with Submodules

Each plugin has its own git repository. To work on a specific plugin:

```bash
cd plugins/golem15/apparatus
git checkout develop
git pull origin develop

# Make changes, commit, push to the plugin repo
git add . && git commit -m "Your change"
git push

# Back in root - update the submodule reference
cd ../../..
git add plugins/golem15/apparatus
git commit -m "Update apparatus submodule"
```

Update all plugins at once:

```bash
git submodule update --remote --merge
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
