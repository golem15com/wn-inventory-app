# Upgrade Notes -- v1.1 Security Remediation

This document aggregates breaking changes shipped during the Phase 8-13 security remediation milestone. Each per-plugin breaking change is fully documented in the corresponding submodule's `UPGRADE.md` (e.g. `plugins/golem15/apparatus/UPGRADE.md`). This file is the index plus cross-plugin notes.

## Cross-Plugin Notes

### HTMLPurifier dependency (Phase 12 / Apparatus)

`plugins/golem15/apparatus` now requires `ezyang/htmlpurifier ^4.17` for the new `|raw_safe` Twig filter. Run `composer install` after pulling. HTMLPurifier requires the cache directory `storage/framework/cache/htmlpurifier/` to be writable by the web user. The directory is auto-created on first sanitize call (`mkdir($path, 0755, true)`), but if your deployment uses restrictive permissions, run `chmod -R 775 storage/framework/cache` post-deploy.

### APP_KEY rotation hazard (Phase 12 / Golem, GitHub)

Several settings are now encrypted at rest with `Illuminate\Support\Facades\Crypt`:

- `golem15_github_repos.webhook_secret` (Phase 12 / 12-05)
- `system_settings.value` JSON blob containing CompreFace `admin_password` (Phase 12 / 12-04)

All `Crypt`-encrypted values are tied to `APP_KEY`. Rotating `APP_KEY` will make these values unreadable. If you must rotate `APP_KEY`, decrypt-then-reencrypt or restore the affected secrets manually.

## Drop: Winter.Redirect submodule (Phase 12 / UTIL-08)

The `plugins/winter/redirect` submodule is removed in this release. The submodule was effectively unused (the plugin directory was already empty in the working tree).

**Migration paths for projects relying on Winter.Redirect:**

- For HTTP redirects, use nginx/Apache rewrite rules at the web-server layer.
- For Winter.Pages-managed redirects, see Winter.Pages docs.

**Per-project verification:** Each downstream project (Horoskopia, QuestStream, Drzewo, etc.) must audit its own redirect rules and migrate them. Out of scope for the shared plugin set.

## Per-Plugin Breaking Changes Index

| Plugin | UPGRADE.md | Breaking Changes |
|--------|-----------|-----------------|
| Apparatus | `plugins/golem15/apparatus/UPGRADE.md` | New HTMLPurifier composer dep; new `\|raw_safe` Twig filter; API token AJAX handlers now require backend auth (UTIL-07) |
| Golem | `plugins/golem15/golem/UPGRADE.md` | CompreFace `admin_password` now encrypted at rest; SSRFGuard rejects unallowlisted hosts (INTG-01); per-user rate limit on AI chat |
| GitHub | `plugins/golem15/github/UPGRADE.md` | `webhook_secret` encrypted at rest; `webhook_secret` and `token_encrypted` removed from `$fillable` |
| Journal | `plugins/golem15/journal/UPGRADE.md` (if updated) | Tag/Category models use explicit `$fillable`; `MediaApiController` requires upload permission |
| FAQ | `plugins/golem15/faq/UPGRADE.md` (if updated) | FAQs controller now requires `golem15.faq.faqs` permission |
| Quote | `plugins/golem15/quote/UPGRADE.md` (if updated) | Quotes controller now requires `golem15.quote.quotes` permission |
| Translate | `plugins/golem15/translate/UPGRADE.md` (if updated) | Message/Attribute models use explicit `$fillable` |
| Sitemap | `plugins/golem15/sitemap/UPGRADE.md` (if updated) | Definition model uses explicit `$fillable`; XML output now correctly entity-escapes `&` |
