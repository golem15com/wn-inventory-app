# Security Upgrade Guide

**Package:** keios/oc-trait-financial
**Audit reference:** Phase 10 / Security Audit v1.1
**Date:** 2026-04-27

## OTF-001 (PAY-13): Financial trait per-class boot tracking

**Severity:** HIGH
**Breaking change:** NO (pure correctness fix)

### What changed
The `bootFinancial()` static guard now indexes per-class via `static::$financialTraitBootedFor[$class]` instead of using a single shared `static::$financialTraitAlreadyBooted` boolean. Previously, the first class using the trait set the flag, and subsequent classes (e.g. a sibling Payment + Order pair) skipped boot entirely -- leaving `model.beforeSetAttribute` unbound for them.

### Verification
Two models that both use the trait will independently boot and register their event listeners. Run `composer test` against `keios/oc-trait-financial` (or `vendor/bin/phpunit --testsuite="Golem15.PaymentGateway" --filter=FinancialTraitTest` from a host project) -- the new `test_pay_13_financial_trait_per_class_boot` test must pass.
