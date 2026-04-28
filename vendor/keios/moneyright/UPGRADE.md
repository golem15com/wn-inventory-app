# Security & Correctness Upgrade Guide

**Package:** keios/moneyright
**Audit reference:** Phase 10 / Security Audit v1.1
**Date:** 2026-04-27

## MR-004 (DEP-03): CurrencyPair rejects zero and negative ratios

**Severity:** MEDIUM
**Breaking change:** Behavioral -- previously-silent acceptance of zero/negative ratios now throws.

### What changed
`CurrencyPair::__construct()` now validates that `$ratio > 0` using `bccomp((string)$ratio, '0', Money::GAAP_PRECISION) <= 0`. If the ratio is zero or negative, it throws `Keios\MoneyRight\Exceptions\InvalidArgumentException`.

### Migration steps
Callers that pulled exchange rates from external providers (NBP, Fixer, Yahoo) and constructed `CurrencyPair` directly must wrap the constructor in try/catch and skip bad data, retaining the prior persisted ratio. Reference implementation: `Golem15\PaymentGateway\Console\UpdateCurrencyRatios` (see PaymentGateway repo).

### Before / after code
**Before:**
```php
$pair = new CurrencyPair($base, $counter, $ratio); // silently accepted ratio=0
```
**After:**
```php
try {
    $pair = new CurrencyPair($base, $counter, $ratio);
} catch (\Keios\MoneyRight\Exceptions\InvalidArgumentException $e) {
    // log + skip; retain prior rate
}
```

### Verification
`new CurrencyPair($eur, $usd, 0)` and `new CurrencyPair($eur, $usd, -0.5)` both throw. See `tests/CurrencyPairTest.php`.

***

## MR-001 (DEP-02): Money int-as-cents API trap -- documentation

**Severity:** MEDIUM
**Breaking change:** NONE (documentation only)

### What changed
The `Money::__construct` docblock now prominently warns that int input is interpreted as cents and divided by 100. This preserves Verraes Money compatibility for callers that rely on this behavior.

### Migration steps
ALWAYS pass amount as a string. `new Money('500', $usd)` is five hundred dollars; `new Money(500, $usd)` is five dollars. Audit caller code with `grep -rn "new Money(\s*\d" .` and convert int literals to strings.

### Verification
`grep -q 'int input is divided by 100' src/Money.php` returns exit 0.
