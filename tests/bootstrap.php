<?php
// tests/bootstrap.php — Shared test bootstrap for all Golem15 plugin tests.
// Wraps WinterCMS's built-in bootstrap. No auth-bind override is needed:
// WinterCMS runs Laravel 9 with loadDiscoveredPackages=false, so JWT is not
// auto-discovered and the boot-ordering crash that exists in DTW (Laravel 12)
// does not occur here.

$baseDir = realpath(__DIR__ . '/..');

/*
 * WinterCMS bootstrap/app.php handles automatically:
 *   - Composer autoload (bootstrap/autoload.php)
 *   - Winter\Storm\Support\ClassLoader for modules and plugins
 *   - class_alias('PluginTestCase', System\Tests\Bootstrap\PluginTestCase::class)
 *     via modules/system/aliases.php
 *   - SQLite in-memory DB (set by PluginTestCase::createApplication() at runtime)
 *
 * Do NOT duplicate any of the above here.
 */
require_once $baseDir . '/modules/system/tests/bootstrap/app.php';

if (!defined('GOLEM15_TEST_BOOTSTRAP_RAN')) {
    define('GOLEM15_TEST_BOOTSTRAP_RAN', true);

    putenv('WS_ENABLE_MODEL_UPDATES=false');
}
