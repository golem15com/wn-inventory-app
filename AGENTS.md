# Repository Guidelines

## Project Structure & Module Organization
This repository is a WinterCMS application built on Laravel 9 and organized around core modules and custom plugins. Core framework code lives in `modules/` (`backend`, `cms`, `system`). Product-specific features live in `plugins/golem15/`, third-party plugins in `plugins/winter/`, public assets in `public/`, frontend themes in `themes/`, and app/runtime configuration in `config/`, `bootstrap/`, `storage/`, and `temp/`. Shared docs and repo maintenance scripts live in `docs/` and `scripts/`. PHPUnit bootstrap and top-level test config live in `tests/` and `phpunit.xml`.

## Build, Test, and Development Commands
Use the documented setup flow before making changes:

```bash
./setup.sh              # install deps, prepare .env, initialize app
php artisan serve       # run local dev server
vendor/bin/phpunit      # run PHPUnit suites directly
composer lint           # parallel PHP syntax lint
composer sniff          # PHPCS style checks
composer scan:phpstan   # static analysis
composer scan:all       # security + static-analysis sweep
```

If you touch `modules/system` JavaScript, run `npm test` from `modules/system/`.

## Coding Style & Naming Conventions
Follow `.editorconfig`: UTF-8, LF endings, trailing newline, and 4-space indentation; use 2 spaces only in GitHub workflow YAML. Match existing WinterCMS and Laravel conventions: PSR-style PHP, PascalCase class names, camelCase methods, and plugin namespaces like `Golem15\\PgStripe`. Keep plugin code inside its own directory and mirror existing folder names such as `models/`, `updates/`, `components/`, and `tests/`. JS in `modules/system` uses ESLint with `airbnb-base` and Vue 3 rules, also with 4-space indentation.

## Testing Guidelines
Add or update PHPUnit coverage for any behavioral change. Test files use the `*Test.php` suffix and usually sit in each module or plugin’s `tests/` directory, for example `plugins/golem15/pgstripe/tests/`. Prefer focused suite runs while iterating, then finish with `vendor/bin/phpunit`. For JavaScript changes in `modules/system`, add or update Jest cases under `modules/system/tests/js/`.

## Commit & Pull Request Guidelines
Recent history follows scoped Conventional Commit style such as `fix(pgstripe): ...`, `test: ...`, and `docs(14-01): ...`. Keep subjects imperative and specific; include the affected plugin, module, or phase when useful. PRs should explain the user-visible change, note setup or migration impact, link the issue or phase artifact, and include screenshots for backend or theme UI changes. If submodules move, call that out explicitly in the PR description.
