<?php namespace Keios\MoneyRight\Tests;

use Keios\MoneyRight\Currency;
use Keios\MoneyRight\CurrencyPair;
use Keios\MoneyRight\Exceptions\InvalidArgumentException;
use Keios\MoneyRight\Money;
use PHPUnit\Framework\TestCase;

/**
 * PoC tests for DEP-03 (MR-004): CurrencyPair must reject zero and negative ratios.
 *
 * The current constructor only checks is_numeric() and accepts 0 / negative numerics.
 * These tests MUST FAIL (RED) before the fix and PASS (GREEN) after.
 *
 * @group security
 */
class CurrencyPairTest extends TestCase
{
    /**
     * DEP-03: CurrencyPair must reject zero ratio.
     *
     * A zero exchange rate is never valid -- it would convert any amount to zero,
     * silently destroying financial data.
     *
     * @test
     */
    public function test_dep_03_currency_pair_rejects_zero_ratio(): void
    {
        $eur = new Currency('EUR');
        $usd = new Currency('USD');

        $this->expectException(InvalidArgumentException::class);

        new CurrencyPair($eur, $usd, 0);
    }

    /**
     * DEP-03: CurrencyPair must reject negative ratio.
     *
     * A negative exchange rate is never valid -- it would invert the sign of
     * converted amounts, creating phantom negative balances.
     *
     * @test
     */
    public function test_dep_03_currency_pair_rejects_negative_ratio(): void
    {
        $eur = new Currency('EUR');
        $usd = new Currency('USD');

        $this->expectException(InvalidArgumentException::class);

        new CurrencyPair($eur, $usd, -0.5);
    }

    /**
     * DEP-03: CurrencyPair must accept positive ratio without throwing.
     *
     * Ensures the validation does not over-restrict -- positive ratios are valid.
     *
     * @test
     */
    public function test_dep_03_currency_pair_accepts_positive_ratio(): void
    {
        $eur = new Currency('EUR');
        $usd = new Currency('USD');

        $pair = new CurrencyPair($eur, $usd, 1.0850);

        // getRatio() with usePrecision=true returns bcadd'd value at GAAP_PRECISION (4)
        $this->assertEquals(
            bcadd('1.0850', '0', Money::GAAP_PRECISION),
            $pair->getRatio(true),
            'CurrencyPair should accept positive ratio and return bcround\'d value'
        );
    }
}
