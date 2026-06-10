# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **Golem15 Stack** starter project built on **WinterCMS** (Laravel-based CMS, forked from October CMS). It contains a comprehensive collection of custom Golem15 plugins for various functionality including payments, user management, AI integration, multilingual support, and content management.

## Key Commands

### Environment Setup

```bash
# Local install (non-interactive, defaults to sqlite)
./backend-init.sh

# Or with env var overrides
DB_CONNECTION=mysql DB_DATABASE=mydb ADMIN_PASSWORD=secret ./backend-init.sh

# Client-scaffold orchestrator (interactive, or flag-driven):
# resets the stack -> repoints backend origin -> backend-init.sh -> scripts/frontend-init.sh.
# Bare `./setup.sh` is interactive; blank repos fall through to a local install with no reset.
./setup.sh

# Helper scripts live in scripts/ (frontend-init.sh, all-develop.sh, reset-gsd.sh)

# Manual commands
php artisan <command>
composer <command>

# Fix permissions if needed
jinify

# Initial setup
php artisan winter:env          # Generate .env file
php artisan winter:up           # Run migrations and create admin account
php artisan winter:mirror public --relative  # Create symlinks
```

### Development Commands
```bash
# Database
php artisan winter:up           # Run all migrations
php artisan winter:down         # Drop all tables
php artisan migrate             # Run pending migrations

# Cache Management
php artisan cache:clear
php artisan queue:clear

# Testing
php artisan winter:test         # Run Winter CMS core tests
php artisan winter:test Golem15.PaymentGateway  # Run specific plugin tests
composer test                   # Run PHPUnit tests
composer lint                   # Check syntax
composer sniff                  # Check code standards (PSR-1, PSR-2, PSR-4)

# Payment Gateway Commands
php artisan pg:cancel-created-payments
php artisan pg:cancel-placed-orders
php artisan pg:finish-orders
php artisan pg:update-currencies
php artisan pg:update-metadata

# Apparatus Commands
php artisan g15:sane-git        # Skip worktree for git modules
php artisan g15:sane-git --insane  # Revert skip worktree
php artisan apparatus:mail-export   # Export mail templates
php artisan apparatus:mail-import   # Import mail templates
php artisan apparatus:mail-reset    # Reset mail templates

# User Plugin Commands
php artisan user:process-scheduled-deletions  # GDPR: Process scheduled user deletions

# WebSockets
php artisan websockets:test-push
```

### Git Submodules

All plugins are managed as git submodules for independent version control:
- **19 Golem15 plugins** in `plugins/golem15/`
- **2 Winter plugins** in `plugins/winter/` (debugbar, location)

```bash
# Initial setup after cloning this repository
git submodule update --init --recursive

# Update all plugins to latest versions
git submodule update --remote --merge

# Or use the helper script
./scripts/update-submodules.sh

# Working on a specific plugin
cd plugins/golem15/apparatus
git checkout master
git pull
# Make changes, commit, push to plugin repository
cd ../../../
git add plugins/golem15/apparatus
git commit -m "Update apparatus submodule reference"
```

**Naming Conventions:**
- Apparatus uses `oc-apparatus-plugin` (OctoberCMS compatibility naming)
- All other Golem15 plugins use `wn-{pluginname}-plugin` naming

## Architecture & Structure

### WinterCMS Foundation
- **Core Modules**: System, Backend, CMS (in `modules/` directory)
- **Laravel Version**: Laravel 9.x
- **Storm Library**: Winter's buffer layer between Laravel and Winter to minimize breaking changes
- **PHP Requirement**: >= 8.4

### Golem15 Plugins (in `plugins/golem15/`)

**Core Framework:**
- **Apparatus**: Foundation framework providing dependency injection, scenario-based workflows, backend utilities, form widgets, and various helper classes. Required by most other plugins.
- **User**: Enhanced user authentication with JWT support, GDPR compliance (scheduled deletions), OAuth integration (Laravel Socialite)

**Payment & Commerce:**
- **PaymentGateway**: Complete payment processing system with finite state machines, order management, shipping, quotes, and multi-currency support. Uses MoneyRight library for financial calculations.
- **PgStripe**: Stripe payment operator integration

**Content Management:**
- **Blog**: Blog system with posts, categories, RSS feeds
- **BlogHub**: Blog aggregation/hub functionality
- **FAQ**: FAQ management
- **Menu**: Navigation menu builder
- **SEO**: SEO optimization tools
- **Translate**: Multilingual support, locale management, message translation

**Advanced Features:**
- **AI**: AI integration with multiple engines (OpenAI, Perplexity), chat interfaces, prompt management
- **Chat**: Real-time chat functionality
- **WebSockets**: WebSocket support for real-time features
- **Quote**: Quote/estimation system
- **SiteManager**: Multi-site management
- **Sitemap**: XML sitemap generation
- **GitHub**: GitHub integration

**Form Widgets:**
- **KnobWidget**: Knob/dial form widget
- **DualFormField**: Dual input form field widget

### Plugin Dependencies

Key plugin dependencies (from `$require` arrays in Plugin.php):
- PaymentGateway → Apparatus, User
- Most plugins depend on Apparatus as the core framework

### Important Architectural Patterns

**Apparatus Framework Features:**
- **Scenario System**: Event-driven workflow engine (keios/apparatus, keios/laravel-apparatus)
- **Dependency Injection**: Automatic DI for CMS components via `apparatus.dependencyInjector`
- **Route Resolver**: Custom route resolution (`apparatus.route.resolver`)
- **Backend Injector**: CSS/JS injection for backend (`apparatus.backend.injector`)
- **Form Widgets**: ListToggle, KnobWidget with AJAX handlers
- **Twig Filters**: `ucfirst`, `human_date`

**PaymentGateway Architecture:**
- **Finite State Machine**: Payment and order states with event-driven transitions
- **Operators**: Pluggable payment providers (CashPayment, ManualTransferPayment, Stripe)
- **MoneyRight**: Financial calculations with proper decimal handling (keios/moneyright)
- **Item Formatters**: Generic and Adjustable item types
- **Mailer Subscribers**: Event-driven email notifications for payment/order state changes
- **Serialization Service**: JMS Serializer for metadata caching
- **Twig Filters**: `money`, `item_details`

**User Plugin:**
- **JWT Authentication**: Custom JWT guard using php-open-source-saver/jwt-auth
- **Multi-Model Support**: Golem15\User or Winter\User detection
- **Mail Blocking**: User-based email filtering
- **GDPR**: Privacy compliance with scheduled deletion command
- **Middleware**: `jwt.auth`, `jwt.refresh` for API routes

**Model Extension Pattern:**
Plugins extend other models dynamically using Winter's `extend()` method:
```php
User::extend(function ($model) {
    $model->hasMany['payments'] = [PaymentModel::class, 'key' => 'user_id'];
});
```

**Translation System:**
- Uses Golem15\Translate (fork of Winter.Translate)
- Apparatus auto-scans `plugins/*/*/components/*/*.htm` for translatable strings
- Translation filter: `{{ 'Original English String'|_ }}`

## Critical Framework Constraints

### WinterCMS Snowboard Framework
**IMPORTANT**: Snowboard framework does NOT support `data-request-success` attribute (removed as unsafe due to eval). Use JavaScript event handlers instead:

```javascript
// Instead of data-request-success="onSuccess()"
document.addEventListener('ajax:update', function(event) {
    if (event.detail.handler === 'onYourHandler') {
        // Your success code
    }
});
```

### Composer Plugin Merging
The project uses `wikimedia/composer-merge-plugin` to automatically merge plugin-level composer.json files. Plugin dependencies are managed individually in `plugins/*/*/composer.json`.

## Configuration Files

- `.env` - Environment configuration (generated from `.env.example`)
- `config/app.php`, `config/cms.php`, `config/database.php` - Main configs
- `config/dev/` - Development overrides
- Plugin configs in `plugins/golem15/*/config/`
- JWT config publishes to `config/jwt.php`, `config/auth.php`

## Scheduled Tasks

PaymentGateway registers scheduled tasks (see Plugin.php `registerSchedule`):
- `pg:cancel-sent-payments` - Daily
- `pg:cancel-created-payments` - Daily
- `pg:cancel-placed-orders` - Daily
- `pg:finish-orders` - Daily
- `pg:update-currencies` - Every 10 minutes

Configure Laravel scheduler via cron:
```bash
* * * * * cd /path/to/project && php artisan schedule:run >> /dev/null 2>&1
```

## Development Notes

- **PHP >= 8.4** required
- Payment system uses precise decimal arithmetic via MoneyRight (never float/double)
- Apparatus framework enables scenario-based workflows - check existing scenarios before creating ad-hoc solutions
- JWT tokens for API auth use `php-open-source-saver/jwt-auth` package
- File structure follows WinterCMS conventions: controllers, models, components in plugin root
- Backend forms/lists configuration in `plugins/*/models/*/fields.yaml` and `columns.yaml`
- Backend translation keys follow pattern: `plugin.namespace::lang.section.key`
