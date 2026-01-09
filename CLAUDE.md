# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **Golem15 Stack** starter project built on **WinterCMS** (Laravel-based CMS, forked from October CMS). It contains a comprehensive collection of custom Golem15 plugins for various functionality including payments, user management, AI integration, multilingual support, and content management.

## Key Commands

### Environment Setup
```bash
# Use legacy PHP/Composer (important!)
php-legacy artisan <command>
composer-legacy <command>

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
composer test                   # Run PHPUnit tests
composer lint                   # Check syntax
composer sniff                  # Check code standards (PSR-1, PSR-2, PSR-4)

# Payment Gateway Commands
php artisan pg:cancel-created-payments
php artisan pg:cancel-placed-orders
php artisan pg:finish-orders
php artisan pg:update-currencies
php artisan pg:update-metadata

# Git Modules Management
php artisan g15:sane-git        # Skip worktree for git modules
php artisan g15:sane-git --insane  # Revert skip worktree

# WebSockets
php artisan websockets:test-push
```

## Architecture & Structure

### WinterCMS Foundation
- **Core Modules**: System, Backend, CMS (in `modules/` directory)
- **Laravel Version**: Laravel 9.x
- **Storm Library**: Winter's buffer layer between Laravel and Winter to minimize breaking changes
- **PHP Requirement**: >= 8.1

### Golem15 Plugins (19 total in `plugins/golem15/`)

**Core Framework:**
- **Apparatus**: Foundation framework providing dependency injection, scenario-based workflows, backend utilities, form widgets, and various helper classes. Required by most other plugins.
- **User**: Enhanced user authentication with JWT support, GDPR compliance, OAuth integration (Laravel Socialite)

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
- **AI**: AI integration with multiple engines, chat interfaces, prompt management
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

Key plugin dependencies (from `require` arrays):
- PaymentGateway → Apparatus, User
- Most plugins depend on Apparatus as the core framework

### Important Architectural Patterns

**Apparatus Framework Features:**
- **Scenario System**: Event-driven workflow engine (keios/apparatus, keios/laravel-apparatus)
- **Dependency Injection**: Automatic DI for CMS components via `apparatus.dependencyInjector`
- **Route Resolver**: Custom route resolution (`apparatus.route.resolver`)
- **Backend Injector**: CSS/JS injection for backend (`apparatus.backend.injector`)
- **Form Widgets**: ListToggle, KnobWidget with AJAX handlers

**PaymentGateway Architecture:**
- **Finite State Machine**: Payment and order states with event-driven transitions
- **Operators**: Pluggable payment providers (CashPayment, ManualTransferPayment, Stripe)
- **MoneyRight**: Financial calculations with proper decimal handling (keios/moneyright)
- **Item Formatters**: Generic and Adjustable item types
- **Mailer Subscribers**: Event-driven email notifications for payment/order state changes
- **Serialization Service**: JMS Serializer for metadata caching

**User Plugin:**
- **JWT Authentication**: Custom JWT guard using php-open-source-saver/jwt-auth
- **Multi-Model Support**: Golem15\User or Winter\User detection
- **Mail Blocking**: User-based email filtering
- **GDPR**: Privacy compliance configuration

**Translation System:**
- Uses Golem15\Translate (fork of Winter.Translate)
- Supports locale-based message management
- Theme and component scanning for translatable strings
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

### Asset Compilation
Winter CMS uses Laravel Mix for asset compilation (see `modules/system/package.json` and `modules/backend/package.json`).

## Translation Guidelines

Use the `|_` filter for translating strings in templates:
```twig
{{ 'This should contain original english strings'|_ }}
```

Backend translation keys follow pattern: `plugin.namespace::lang.section.key`

## Testing

Tests are located in:
- `plugins/golem15/paymentgateway/tests/` (functional and unit tests)
- Core tests in `modules/*/tests/`

Run specific plugin tests:
```bash
php artisan winter:test Golem15.PaymentGateway
```

## Configuration Files

- `.env` - Environment configuration (generated from `.env.example`)
- `config/app.php`, `config/cms.php`, `config/database.php` - Main configs
- `config/dev/` - Development overrides
- Plugin configs in `plugins/golem15/*/config/`

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

- **Always use `php-legacy` and `composer-legacy`** as specified in global config
- Payment system uses precise decimal arithmetic via MoneyRight (never float/double)
- Apparatus framework enables scenario-based workflows - check existing scenarios before creating ad-hoc solutions
- JWT tokens for API auth use `php-open-source-saver/jwt-auth` package
- File structure follows WinterCMS conventions: controllers, models, components in plugin root
- Backend forms/lists configuration in `plugins/*/models/*/fields.yaml` and `columns.yaml`
