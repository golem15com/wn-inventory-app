# Contributing to Inventory

Thanks for your interest in contributing! Inventory is a personal/household inventory
catalog built as a `Golem15\Inventory` plugin on the Golem15 / WinterCMS stack, with a Vue
SPA front-end (`vue-inventory-app`) and Typesense-backed search. This guide covers local
setup, the submodule workflow, and what we expect from a pull request.

## Project Layout

This repository is a **superproject**: the application itself plus a set of **git
submodules**. The Golem15 plugins live under `plugins/golem15/*` and the Vue SPA lives in
`vue-inventory-app/` — each is its own repository, pulled in as a submodule.

## Requirements

- **PHP >= 8.4**
- **Composer**
- A database — SQLite works out of the box for local development; MySQL or PostgreSQL is
  recommended for anything beyond that.
- (Optional) **Typesense** for full-text search; the app falls back to a database search
  path when Typesense is not configured.
- **Node.js** (for the Vue SPA in `vue-inventory-app/`).

## Getting Started

Clone with submodules, then run the local installer:

```bash
git clone --recurse-submodules <repo-url> inventory
cd inventory

# If you cloned without --recurse-submodules:
git submodule update --init --recursive

# Local install (non-interactive; defaults to sqlite)
./backend-init.sh

# Or run the underlying steps manually
php artisan winter:env          # generate .env
php artisan winter:up           # run migrations + create the admin account
php artisan winter:mirror public --relative  # symlink plugin/module assets
```

The Vue SPA has its own setup — see `vue-inventory-app/README.md`.

## Working with Submodules

Because plugins and the Vue app are submodules, a change usually touches **two** repos:

1. Make and commit your change **inside the submodule** (it has its own history and
   remote).
2. Back in the superproject, commit the **updated submodule pointer** so the superproject
   references your new commit:

   ```bash
   cd plugins/golem15/inventory
   # ... make changes, commit, push to the plugin repo ...
   cd ../../../
   git add plugins/golem15/inventory
   git commit -m "Bump inventory submodule"
   ```

To pull the latest submodule revisions:

```bash
git submodule update --remote --merge
```

## Tests and Code Style

Before opening a PR, please make sure the relevant checks pass:

```bash
composer test                              # PHPUnit suite
php artisan winter:test Golem15.Inventory  # run a specific plugin's tests
composer lint                              # syntax check (php-parallel-lint)
composer sniff                             # PSR-1 / PSR-2 with WinterCMS exceptions
```

Coding conventions follow the WinterCMS standard: 4-space indentation, LF line endings,
UTF-8, a trailing newline, and no trailing whitespace (see `.editorconfig`). WinterCMS
AJAX handlers use the `on`-prefixed snake_case form (e.g. `onSave`); regular methods are
`camelCase`.

## Pull Requests

- Keep PRs focused — one logical change per PR is easier to review.
- Fill in the pull-request template; it prefills automatically when you open a PR.
- **Confirm that no secrets** (API keys, tokens, credentials, or `.env` values) are
  committed. This is a mandatory checkbox on every PR — this is a public, history-bearing
  repository and a leaked secret is leaked permanently.
- Make sure tests pass and lint is clean.
- If your change affects a submodule, include the submodule pointer bump in the
  superproject (or note it clearly so a maintainer can do it).

## Reporting Security Issues

Please **do not** open a public issue for a security vulnerability. See
[SECURITY.md](SECURITY.md) for how to report privately via GitHub Private Vulnerability
Reporting.

Thank you for contributing!
