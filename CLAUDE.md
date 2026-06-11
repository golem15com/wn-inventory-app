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
- **18 Golem15 plugins** in `plugins/golem15/`
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
- **Backend**: Golem15-branded backend login page and branding defaults
- **Golem**: Clean, extendable AI integration for WinterCMS (multiple engines, chat interfaces, prompt management)

**Payment & Commerce:**
- **PaymentGateway**: Complete payment processing system with finite state machines, order management, shipping, quotes, and multi-currency support. Uses MoneyRight library for financial calculations.
- **PgStripe**: Stripe payment operator integration

**Content Management:**
- **Journal**: Headless-capable blog/content platform — posts, categories, RSS, JSON API (`/_journal/api/v1`), multilingual
- **FAQ**: FAQ management
- **Sitemap**: XML sitemap generation
- **Translate**: Multilingual support, locale management, message translation (fork of Winter.Translate)
- **Quote**: AI-powered quote/estimation generation with scheduled daily generation

**Real-time & Social:**
- **WebSockets**: WebSocket support for real-time features (Centrifugo broadcasting, channel authorization, push)
- **Chat**: Real-time chat functionality
- **ChatVideo**: Video and audio calling for Golem15 Chat conversations
- **UserFriends**: User-to-user friendship system with friend requests and friends list

**Developer Tools:**
- **GitHub**: GitHub integration (fetch issues/PRs, start/close work from the CLI)

**Form Widgets:**
- **KnobWidget**: Knob/dial form widget
- **DualFormWidget**: Dual input form widget for paired values in backend forms

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

<!-- GSD:project-start source:PROJECT.md -->
## Project

**Inventory**

A personal/household inventory catalog for physical things — cables, tools, batteries, devices — scattered across many places. You record **what** you own, **which category** it belongs to, and **where** it physically lives (a Location inside an Area), then find it instantly by searching instead of hunting through drawers, boxes, and cupboards. Built as a new `JZ\Inventory` plugin on the Golem15 stack, with a Vue SPA (`vue-inventory-app`) front-end and a fast, permission-scoped search powered by Typesense via Laravel Scout (reused from the Journal plugin).

**Core Value:** Type the name of a thing and immediately see where it is — across every Area you have access to. If everything else fails, search-to-location must work.

### Constraints

- **Tech stack**: PHP >= 8.4, WinterCMS ~1.2 / Laravel 9.x backend; Vue SPA front-end — Golem15 stack standard, non-negotiable for core plugins.
- **Plugin namespace**: `JZ\Inventory` in `plugins/jz/inventory` — submodule already created and registered in `.gitmodules`.
- **Search**: Typesense via Laravel Scout, reusing the Journal plugin's infrastructure — avoid a second search stack.
- **Security**: All access permission-scoped per-Area, enforced server-side including in search results — a user must never see another Area's items.
- **Snowboard caveat**: WinterCMS Snowboard does not support `data-request-success` (use JS event handlers) — relevant only if any CMS-side JS is touched; the SPA is the primary front-end.
- **Submodules**: Both plugin and Vue app are git submodules (use `ssu` for management); changes commit to their own repos plus a superproject reference bump.
<!-- GSD:project-end -->

<!-- GSD:stack-start source:codebase/STACK.md -->
## Technology Stack

## Languages
- PHP >= 8.4 (project requirement; base composer.json declares `>=8.1` but chatvideo enforces `^8.4`)
- Twig (CMS template engine via WinterCMS)
- JavaScript (frontend themes, Snowboard framework, LiveKit client JS)
## Runtime
- PHP >= 8.4 (note: root `composer.json` declares `>=8.1`; runtime requirement is 8.4 per `plugins/golem15/chatvideo/composer.json` and `CLAUDE.md`)
- Web server: Apache (.htaccess present) or any PHP-capable server
- Composer (lockfile: `composer.lock` — present and committed)
## Frameworks
- WinterCMS ~1.2 — full CMS framework (forked from OctoberCMS)
- Laravel 9.x (`^9.1`) — underlying HTTP framework, ORM, queues, events
- PHPUnit ^9.5.8 (`composer test` / `php artisan winter:test`)
- Mockery ^1.4.4 — mocking library
- FakerPHP ^1.9.2 — test data generation
- dms/phpunit-arraysubset-asserts ^0.1.0|^0.2.1 — extra assertion helpers
- PHPStan ^1.12 + Larastan ^2.9 (config: `phpstan.neon`, baseline: `phpstan-baseline.neon`)
- squizlabs/php_codesniffer ^3.2 (config: `phpcs.xml`, standard: PSR-1/PSR-2 with WinterCMS exceptions)
- php-parallel-lint ^1.0 — syntax checking
- enlightn/security-checker ^1.10 — dependency vulnerability scanning
- pheromone/phpcs-security-audit ^2.0 — security pattern scanning
- No dedicated frontend build toolchain in the PHP backend (themes build their own assets independently)
- Wikimedia Composer Merge Plugin ~2.1.0 — auto-merges `plugins/*/*/composer.json` into root dependency tree
- cweagans/composer-patches ^2.0 — applies `patches/winter-storm-php84-null-offset.patch` post-install/update
## Key Dependencies
- `keios/laravel-apparatus` dev-develop — Apparatus scenario/DI framework (private VCS: `git@github.com:golem15com/laravel-apparatus.git`)
- `winter/storm` ~1.2.0 — Laravel buffer layer
- `laravel/framework` ^9.1 — HTTP, ORM, queues, events
- `keios/moneyright` ~1.0.9 — financial arithmetic (never float; requires `make_currencies.php` post-install)
- `keios/oc-trait-financial` ~1.0@dev — financial trait (private: `https://github.com/golem15com/wn-financial-trait.git`)
- `jms/serializer` ^3.0 — JMS Serializer for PaymentGateway metadata caching
- `yohang/finite` 1.1.* — finite state machine (private VCS: `https://keiosweb@bitbucket.org/keiosweb/finite.git`)
- `ramsey/uuid` 4.9.2 — UUID generation for payments
- `moontoast/math` * — arbitrary precision math
- `hashids/hashids` 5.* — ID obfuscation
- `symfony/options-resolver` * — options resolution
- `php-open-source-saver/jwt-auth` 1.* — JWT authentication guard
- `firebase/php-jwt` ^5.0||^6.0||^7.0 — JWT token encoding/decoding (used by user, websockets, chatvideo)
- `laravel/socialite` ^5.6 — OAuth provider (Google, Facebook, GitHub login)
- `google/recaptcha` ^1.2 — form spam protection
- `pragmarx/google2fa` ^8.0 — TOTP two-factor authentication
- `bacon/bacon-qr-code` ^2.0 — QR code for 2FA setup
- `lbuchs/webauthn` ^2.0 — WebAuthn/FIDO2 device authentication
- `stripe/stripe-php` ^16.0 — Stripe SDK
- `intervention/image` dev-main — image manipulation (Apparatus plugin)
- `laravel/scout` ^10.0 — Laravel Scout search driver (Journal plugin)
- `typesense/typesense-php` ^4.9 — Typesense search client (Journal plugin, optional)
- `agence104/livekit-server-sdk` ^1.3.5 — LiveKit server SDK for video calling (ChatVideo plugin)
- Centrifugo (external service) — WebSocket server; communicated via HTTP API and `firebase/php-jwt`
- `intervention/image` dev-main — image manipulation
- `hashids/hashids` 5.0.2 — URL-safe ID obfuscation
- `ezyang/htmlpurifier` ^4.17 — HTML sanitization (`raw_safe` Twig filter)
- `league/iso3166` ^4.3 — ISO 3166 country codes (Location plugin)
- `barryvdh/laravel-debugbar` ^3.15.0 — debug toolbar (dev only, winter/debugbar plugin)
## Configuration
- `.env` — primary runtime config (generated from `.env.example`)
- `config/app.php`, `config/database.php`, `config/cms.php`, `config/queue.php`, `config/mail.php`, `config/filesystems.php`, `config/broadcasting.php`, `config/cache.php`, `config/session.php`
- `config/dev/` — development overrides
- JWT config published to `config/jwt.php` and `config/auth.php` by the User plugin
- `APP_KEY` — Laravel app encryption key
- `DB_CONNECTION`, `DB_DATABASE` (default: sqlite)
- `JWT_SECRET` — JWT signing secret (`php artisan jwt:secret`)
- `wikimedia/composer-merge-plugin` merges all `plugins/*/*/composer.json` into the root dependency resolution (configured in `composer.json` `extra.merge-plugin`)
- `composer.json` scripts: `post-install-cmd` and `post-update-cmd` apply `patches/winter-storm-php84-null-offset.patch`
- `patches.lock.json` — patch tracking file
## Platform Requirements
- PHP >= 8.4
- Composer
- SQLite (default local) or MySQL/PostgreSQL for production
- Centrifugo WebSocket server (for chat/WebSocket features)
- LiveKit server (for video calling features, ChatVideo plugin)
- Typesense server (optional, for Journal full-text search)
- CompreFace server (optional, for face recognition in Golem plugin)
- PHP >= 8.4 web server (Apache or nginx)
- MySQL or PostgreSQL recommended (SQLite supported)
- Centrifugo WebSocket server (required for real-time features)
- Laravel cron scheduler: `* * * * * php artisan schedule:run`
- Queue worker for broadcast jobs (`BROADCAST_QUEUE=broadcasts`)
- AWS S3 (optional, configured via `AWS_*` env vars, requires Winter.DriverAWS plugin)
- Redis (optional, supported for cache, session, and queue drivers)
<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->
## Conventions

## Standards
- `PSR1.Methods.CamelCapsMethodName.NotCamelCaps` — excluded (allows WinterCMS snake_case handler methods like `onSave`, `onDelete`)
- `Generic.Files.LineLength` — excluded (no line length limit enforced)
- Partial template files (`*/components/*/*`, `*/controllers/*/*`, `*/partials/*`) are exempt from several spacing and closing-tag rules
## Naming Patterns
- Regular methods: `camelCase` — `getItemCount()`, `createFinancialAttributes()`
- WinterCMS AJAX handlers: `onSave()`, `onDelete()`, `onProcessOrder()` (snake_case prefix `on`)
- WinterCMS plugin registration hooks: `pluginDetails()`, `registerComponents()`, `registerMarkupTags()`, `registerFormWidgets()`
## Database Table Naming
- `golem15_apparatus_jobs`
- `golem15_apparatus_personal_api_tokens`
- `golem15_paymentgateway_payments`
- `golem15_paymentgateway_orders`
- `golem15_paymentgateway_currencies`
## Plugin File Organization
## WinterCMS Plugin Registration Patterns
## Backend Translation Key Pattern
## Backend Controller Patterns
## Model Patterns
## Backend YAML Configuration
## Component Patterns
## Snowboard AJAX Constraint
## Twig Filters
- `ucfirst` — PHP built-in
- `human_date` — calls `HumanDateExtension::humanDateFilter()`
- `raw_safe` — HTMLPurifier-backed sanitizer; use instead of `|raw` for user-generated HTML
- `money` — formats a MoneyRight `Money` object via `MoneyFormatter::format()`
- `item_details` — formats a cart item via `ItemFormatter::format()`
## Migration Files
## Error Handling
## EditorConfig
- Indent: 4 spaces (no tabs)
- Line endings: LF
- Charset: UTF-8
- Trailing whitespace: trimmed
- Final newline: required
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->
## Architecture

## Pattern Overview
- Laravel 9.x application with WinterCMS (fork of October CMS) as the CMS layer
- All custom functionality lives in plugins (`plugins/golem15/`, `plugins/winter/`) registered with WinterCMS's `System\Classes\PluginBase`
- Every plugin has a `Plugin.php` entry point with `register()` (service container bindings) and `boot()` (event listeners, model extensions) lifecycle methods
- Plugins declare explicit dependencies via `public $require = ['Author.PluginName']` arrays — WinterCMS enforces load order
- Cross-plugin model extension uses Winter's `extend()` static method (no direct inheritance coupling)
- Apparatus plugin (`plugins/golem15/apparatus`) is the mandatory foundation framework; almost every other plugin requires it
## Layers
- Purpose: Provide CMS, backend panel, and system infrastructure
- Location: `modules/system/`, `modules/backend/`, `modules/cms/`
- Contains: Route handling, plugin loader, model base classes, backend UI, Twig template engine, migration runner
- Depends on: Laravel 9.x, Winter\Storm (the Laravel buffer layer)
- Used by: All plugins
- Purpose: Foundation services shared by all Golem15 plugins — DI, route resolver, backend asset injection, scenario system, Twig filters, API token auth, mail export/import
- Location: `plugins/golem15/apparatus/`
- Contains: `Classes/DependencyInjector.php`, `Classes/RouteResolver.php`, `Classes/BackendInjector.php`, `Classes/HtmlSanitizer.php`, `Middleware/TokenAuthenticate.php`, `Middleware/ForceJsonResponse.php`, `Middleware/BlogUrlValidationMiddleware.php`, `Models/PersonalApiToken.php`
- Depends on: WinterCMS core, `keios/laravel-apparatus` (scenario system via Composer VCS), `intervention/image`, `ezyang/htmlpurifier`
- Used by: All Golem15 plugins that declare `Golem15.Apparatus` in `$require`
- Purpose: Frontend user accounts, JWT API authentication, GDPR compliance, OAuth (Socialite), two-factor auth, role/group management, mail blocking
- Location: `plugins/golem15/user/`
- Contains: `Classes/AuthManager.php`, `Guards/JwtAuthGuard.php`, `Classes/TwoFactor/TwoFactorService.php`, `Models/User.php`, `Models/MailBlocker.php`, `Models/TrustedDevice.php`, routes at `routes.php` (`/_user/api/v1/*`)
- Depends on: `Golem15.Apparatus`, `php-open-source-saver/jwt-auth`, `laravel/socialite`
- Used by: `Golem15.PaymentGateway`, `Golem15.Chat`, `Golem15.WebSockets`
- Purpose: Full payment processing lifecycle with FSM-driven state transitions, pluggable payment operators, order/shipping management, multi-currency support
- Location: `plugins/golem15/paymentgateway/`
- Contains: `core/Operator.php` (abstract FSM base), `core/Order.php` (order FSM), `core/PaymentGatewayServiceProvider.php`, `operators/CashPayment.php`, `operators/ManualTransferPayment.php`, `traits/FiniteStateMachine.php`, `support/MoneyFormatter.php`, `support/CurrencyConverter.php`, `support/GenericItemFormatter.php`, `support/AdjustableItemFormatter.php`, `core/SerializationService.php`
- Depends on: `Golem15.Apparatus`, `Golem15.User`, `yohang/finite` (FSM), `keios/moneyright` (money arithmetic), `jms/serializer`, `ramsey/uuid`, `hashids/hashids`
- Used by: `Golem15.PgStripe`
- Purpose: Domain-specific functionality (blog/journal, FAQ, translate, sitemap, chat, websockets, AI/golem, quote, github, form widgets)
- Location: `plugins/golem15/{journal,faq,translate,sitemap,chat,websockets,golem,quote,github,knobwidget,dualformwidget,backend,userfriends,chatvideo}/`
- Contains: Plugin-specific models, controllers, components, console commands
- Depends on: Various combinations of `Golem15.Apparatus`, `Golem15.Translate`, `Golem15.Chat`, `Golem15.User`, `Golem15.WebSockets`, `Golem15.Golem`
- Used by: CMS themes, client applications
- Purpose: Vue/Nuxt frontend application (optional, per-client scaffold)
- Location: `vue-starter-app/` (git submodule)
- Contains: Nuxt 4 app (`app/`), shared components (`shared/`), i18n (`i18n/`), Playwright tests (`tests/`)
- Depends on: Backend API routes exposed by User plugin and other plugins
- Used by: End users
## Plugin Dependency Graph
```
```
- `Winter.Debugbar` — debug toolbar
- `Winter.Location` — location/country data
## Data Flow
- No global frontend state manager — server-side rendered CMS pages with Twig
- Backend panel state is session-based (Laravel sessions)
- API authentication state via JWT tokens stored client-side
- Plugin settings stored in `system_settings` table, loaded via `Settings::instance()` singletons
## Key Abstractions
- Purpose: Single entry point for each plugin; WinterCMS discovers and loads these automatically
- Examples: `plugins/golem15/apparatus/Plugin.php`, `plugins/golem15/paymentgateway/Plugin.php`, `plugins/golem15/user/Plugin.php`
- Pattern: `register()` binds singletons to the Laravel container; `boot()` attaches event listeners and extends other models/controllers
- Purpose: Auto-inject services into CMS components at page init time, without manual `app()->make()` calls
- File: `plugins/golem15/apparatus/classes/DependencyInjector.php`
- Pattern: Component implements `Golem15\Apparatus\Contracts\NeedsDependencies`; any method prefixed `inject` is called automatically via container resolution on `cms.page.initComponents` event
- Purpose: Decouple plugins — PaymentGateway adds relations to User without modifying User plugin code
- Pattern used throughout `Plugin::boot()`:
```php
```
- Also used to extend backend controllers with `addDynamicMethod()`:
```php
```
- Purpose: Enforce valid payment and order state transitions; fire domain events on each transition
- Library: `yohang/finite` 1.1.* (via Bitbucket VCS in `plugins/golem15/paymentgateway/composer.json`)
- Trait: `plugins/golem15/paymentgateway/traits/FiniteStateMachine.php` — mixed into `Operator` and `core/Order.php`
- Pattern: Class implements abstract `stateMachineConfig()` returning an array of states and transitions; `initStateMachine()` initializes the `ExtendedStateMachine`
- Purpose: Pluggable payment providers — each operator wraps a `Payment` model and drives its FSM
- Base class: `plugins/golem15/paymentgateway/core/Operator.php` (abstract)
- Built-in operators: `operators/CashPayment.php`, `operators/ManualTransferPayment.php`
- External operator example: `plugins/golem15/pgstripe/` (separate plugin, requires `Golem15.PaymentGateway`)
- Operators are registered in `config`: `$this->app['config']->set('golem15.paymentgateway.operators', [CashPayment::class, ManualTransferPayment::class])`; external operators append to this array in their own `Plugin::register()`
- Purpose: Event-driven workflow engine for complex multi-step business processes
- Library: `keios/laravel-apparatus` (private VCS at `git@github.com:golem15com/laravel-apparatus.git`)
- Registered via: `LaravelApparatusServiceProvider` in `Apparatus/Plugin::register()`
- Exposes: `Resolver` facade aliased globally
- Purpose: Precise decimal arithmetic for all financial calculations — never use PHP float
- Library: `keios/moneyright` ~1.0.9 in `plugins/golem15/paymentgateway/`
- Facades: `MoneyFormatter` (Twig `money` filter), `CurrencyConverter`, `DetailsFormatter`
- Currency exchange: `FixerCurrencyExchange`, `NbpCurrencyExchange` (Polish National Bank), `YahooCurrencyExchange` in `plugins/golem15/paymentgateway/support/`
- Purpose: Multilingual frontend content
- Plugin: `plugins/golem15/translate/` (fork of `Winter.Translate`)
- Template syntax: `{{ 'English string'|_ }}`
- Auto-scan: Apparatus `Plugin::register()` hooks `winter.translate.themeScanner.afterScan` to glob `plugins/*/*/components/*/*.htm` for translatable strings
- Purpose: Inject global CSS/JS assets into every backend page
- Singleton: `apparatus.backend.injector` → `classes/BackendInjector.php`
- Usage: `$injector->addCss('/plugins/golem15/apparatus/assets/css/animate.css')`
- Purpose: Machine-to-machine authentication for backend users
- Model: `plugins/golem15/apparatus/models/PersonalApiToken.php`
- Middleware: `token.auth` → `Middleware/TokenAuthenticate.php`
- UI: Added to Backend\Controllers\Users "My Account" page via `backend.form.extendFields` event
## Entry Points
- Location: `index.php`
- Triggers: Any HTTP request not handled by the web server directly (static assets go to `public/`)
- Responsibilities: Bootstrap autoloader, create Laravel app, run HTTP kernel, send response
- Location: `artisan`
- Triggers: `php artisan <command>`
- Responsibilities: Bootstrap app, run Console kernel; all plugin commands registered in `Plugin::register()` via `$this->commands([...])`
- Location: `plugins/golem15/*/Plugin.php` — `register()` then `boot()`
- Triggers: WinterCMS plugin loader during request bootstrap
- Responsibilities: Service container bindings in `register()`; event listeners, model extensions, middleware registration in `boot()`
- Location: `plugins/golem15/paymentgateway/Plugin.php::registerSchedule()`
- Triggers: `php artisan schedule:run` via cron (`* * * * *`)
- Responsibilities: `pg:cancel-sent-payments` (daily), `pg:cancel-created-payments` (daily), `pg:cancel-placed-orders` (daily), `pg:finish-orders` (daily), `pg:update-currencies` (every 10 minutes)
## Error Handling
- FSM transition failures throw `Finite\Exception\StateException` — caught in Operator methods, re-thrown as domain exceptions (`CancellationFailureException`, `AcceptanceFailureException`, etc.)
- Plugin boot wraps `Settings::instance()` in `try/catch QueryException` to survive fresh installs before migrations run (PaymentGateway `Plugin::boot()`)
- Backend AJAX handlers throw `\ValidationException` or `\ApplicationException` which WinterCMS renders as flash messages
- JWT auth errors return 401 JSON via `JwtAuthenticate` middleware
- HTML output sanitized via `HtmlSanitizer::clean()` (HTMLPurifier, `raw_safe` Twig filter)
## Cross-Cutting Concerns
<!-- GSD:architecture-end -->

<!-- GSD:skills-start source:skills/ -->
## Project Skills

No project skills found. Add skills to any of: `.claude/skills/`, `.agents/skills/`, `.cursor/skills/`, `.github/skills/`, or `.codex/skills/` with a `SKILL.md` index file.
<!-- GSD:skills-end -->

<!-- GSD:workflow-start source:GSD defaults -->
## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `/gsd-quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd-debug` for investigation and bug fixing
- `/gsd-execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->

<!-- GSD:profile-start -->
## Developer Profile

> Profile not yet configured. Run `/gsd-profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
