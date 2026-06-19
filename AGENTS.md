# Repository Guidelines

## Product Focus
This repo is **Where I Put It** (`whereiput.it`), a self-hostable inventory system for physical things. The core user promise is: type the name of an item and immediately see where it lives. Preserve search-to-location behavior above all else.

The application is a WinterCMS/Laravel backend with the product implemented mainly in the `Golem15\Inventory` plugin, plus a Vue/Nuxt SPA, MCP server, and Home Assistant add-on as submodules.

## Project Structure
- `modules/` contains WinterCMS core modules: `backend`, `cms`, and `system`.
- `plugins/golem15/` contains Golem15 plugin submodules:
  - `apparatus`: foundation framework, dependency injection, backend utilities, scenarios.
  - `user`: frontend accounts, JWT API auth, OAuth, 2FA, GDPR flows.
  - `backend`: Golem15 backend branding/defaults.
  - `golem`: AI integration.
  - `translate`: multilingual support.
  - `inventory`: the inventory application: Areas, Locations, Items, search, API.
- `vue-inventory-app/` is the Vue/Nuxt SPA.
- `inventory-mcp/` is the MCP server.
- `ha-inventory-addon/` is the Home Assistant add-on.
- `config/`, `bootstrap/`, `storage/`, and `temp/` hold runtime configuration and app state.
- `docs/` and `scripts/` hold documentation and maintenance scripts.

Plugins and apps are git submodules. Commit plugin/app changes in their own repo first, then update and commit the superproject submodule reference.

## Domain And Security Invariants
The inventory domain model is **Area -> Location -> Item**.

- `Area` is the top-level permission boundary.
- `Location` is a physical place inside an Area.
- `Item` is a thing, categorized and tagged, that lives in a Location.
- Search is powered by Typesense via Laravel Scout when configured.

Always enforce Area permission scoping server-side, including search results and API responses. A user must never see items from an Area they cannot access.

Primary API surfaces:
- `/_inventory/api/v1/*`: Inventory plugin JSON API used by the SPA.
- `/api/v1/inventory/*`: personal-token-scoped API used by MCP and integrations.

After bulk Area, Location, Category, Tag, or Item changes that affect search documents, run or recommend `php artisan inventory:reindex`.

## Setup And Development Commands
Use the README for current user-facing setup details. Common local commands:

```bash
./backend-init.sh                              # non-interactive backend setup, defaults to SQLite
./scripts/frontend-init.sh                     # initialize Vue/Nuxt frontend
./run-typesense.sh                            # optional local Typesense

php artisan winter:up                         # run WinterCMS migrations/setup
php artisan winter:down                       # drop all tables
php artisan migrate                           # run pending Laravel migrations
php artisan cache:clear
php artisan queue:clear

php artisan inventory:reindex                 # rebuild Inventory search index
php artisan user:create                       # create a backend user
php artisan user:process-scheduled-deletions  # GDPR deletion processing

composer test                                 # run PHPUnit tests
composer lint                                 # PHP syntax lint
composer sniff                                # PHPCS standards check
composer scan:phpstan                         # PHPStan static analysis
composer scan:all                             # security/static analysis sweep
```

Focused Inventory plugin test command:

```bash
./vendor/bin/phpunit -c plugins/golem15/inventory/phpunit.xml
```

If touching `modules/system` JavaScript, run `npm test` from `modules/system/`.

## Architecture Notes
- WinterCMS runs on Laravel 9.x; runtime target is PHP 8.4+.
- Most Golem15 plugins depend on `Golem15.Apparatus`.
- Apparatus provides scenarios, dependency injection, route resolution, backend injection, API token auth, and shared Twig filters.
- Prefer existing Apparatus scenarios over new ad-hoc multi-step workflows.
- Model extension is common; plugins dynamically extend models instead of inheritance coupling.
- Translation uses `Golem15\Translate`; CMS templates use `{{ 'English string'|_ }}`.
- Backend forms/lists usually live in plugin `models/*/fields.yaml` and `columns.yaml`.

WinterCMS Snowboard does not support `data-request-success`; use JavaScript event handlers for CMS-side AJAX success behavior. The Vue SPA is the primary front end.

Composer dependencies from plugin `composer.json` files are merged into the root dependency tree through `wikimedia/composer-merge-plugin`.

## Coding Style
Follow `.editorconfig`: UTF-8, LF endings, trailing newline, 4-space indentation, and 2-space indentation only for GitHub workflow YAML.

PHP conventions:
- PSR-1/PSR-2 with project exceptions from `phpcs.xml`.
- PascalCase class names.
- camelCase methods.
- Winter AJAX handlers named `on{Action}`.
- Plugin hooks such as `pluginDetails()`, `registerComponents()`, `registerMarkupTags()`, and `registerPermissions()`.
- Plugin namespaces follow `Golem15\PluginName`.

Keep plugin code inside its plugin directory and mirror WinterCMS folder conventions such as `models/`, `updates/`, `components/`, `controllers/`, and `tests/`.

JS in `modules/system` follows ESLint with `airbnb-base` and Vue 3 rules, using 4-space indentation.

## Testing Guidelines
Add or update PHPUnit coverage for behavioral changes, especially permission checks, search behavior, API responses, and data migrations.

Test files use the `*Test.php` suffix and usually live in the relevant module or plugin `tests/` directory. Prefer focused test runs while iterating, then run the relevant broader suite before finishing.

For frontend changes in the Vue/Nuxt app, use that submodule's own README/package scripts. For `modules/system` JavaScript changes, add or update Jest cases under `modules/system/tests/js/`.

## Submodule Workflow
`.gitmodules` uses public HTTPS URLs for anonymous recursive clone support.

Useful commands:

```bash
git submodule update --init --recursive
git submodule update --remote --merge
php artisan g15:sane-git            # mark submodules skip-worktree
php artisan g15:sane-git --insane   # undo skip-worktree
```

When editing a submodule:

```bash
cd plugins/golem15/inventory
git checkout master && git pull
# make changes, test, commit, push in the submodule
cd ../../../
git add plugins/golem15/inventory
git commit -m "Update inventory submodule reference"
```

Use `ssu` when available for submodule management. Naming note: `apparatus` uses `oc-apparatus-plugin`; other Golem15 plugins use `wn-{name}-plugin`.

## Commit And PR Guidelines
Use scoped Conventional Commit style, for example:
- `fix(inventory): enforce area scope in search`
- `test(inventory): cover location API permissions`
- `docs(self-hosting): clarify docker secrets`

Keep subjects imperative and specific. PRs should explain the user-visible change, note migrations or setup impact, link relevant issues or phase artifacts, and include screenshots for backend or frontend UI changes. If submodule references move, call that out explicitly.
