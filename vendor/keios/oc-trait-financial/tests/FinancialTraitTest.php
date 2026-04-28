<?php namespace Keios\Financial\Tests;

use Keios\Financial\Financial;

/**
 * PoC tests for PAY-13 (OTF-001): Financial trait per-class boot tracking.
 *
 * The trait uses a single static boolean, which when shared through an inheritance
 * hierarchy means the SECOND child class using the trait skips boot entirely --
 * leaving model.beforeSetAttribute UNBOUND for that class.
 *
 * These tests MUST FAIL (RED) before the fix is applied and PASS (GREEN) after.
 *
 * @group security
 */
class FinancialTraitTest extends \PHPUnit\Framework\TestCase
{
    /**
     * PAY-13: Two sibling classes inheriting the Financial trait from a common
     * base must both successfully boot and register their event listeners.
     *
     * In WinterCMS, Payment and Order both extend Model and use the Financial
     * trait. PHP shares static properties through inheritance, so the single
     * boolean flag set by the first child causes the second child to skip boot.
     *
     * Before fix: static::$financialTraitAlreadyBooted is set to true by the
     * first class, and the second class returns early without binding events.
     *
     * After fix: per-class tracking via static::$financialTraitBootedFor[$class]
     * allows each class in the hierarchy to boot independently.
     *
     * @test
     */
    public function test_pay_13_financial_trait_per_class_boot(): void
    {
        // Reset the boot state via reflection so test is isolated
        $this->resetBootState();

        // Track which classes successfully completed boot (called extend())
        FinancialBaseStub::$extendCalledBy = [];

        // Call bootFinancial on the first child class
        FinancialChildStubA::bootFinancial();

        // Call bootFinancial on the second child class
        FinancialChildStubB::bootFinancial();

        // After fix: both classes call extend() and register their listeners
        // Before fix: only ChildStubA calls extend(), ChildStubB returns early
        $this->assertContains(
            FinancialChildStubA::class,
            FinancialBaseStub::$extendCalledBy,
            'PAY-13: First child class should have called extend() during boot'
        );
        $this->assertContains(
            FinancialChildStubB::class,
            FinancialBaseStub::$extendCalledBy,
            'PAY-13: Second child class should have called extend() during boot, '
            . 'but was skipped because the single-boolean boot guard was already true '
            . 'from the first child\'s boot. Per-class tracking required.'
        );
    }

    /**
     * Reset the Financial trait's static boot state via reflection.
     */
    private function resetBootState(): void
    {
        // Reset on the base class -- children share the static property through inheritance
        $reflection = new \ReflectionClass(FinancialBaseStub::class);

        if ($reflection->hasProperty('financialTraitBootedFor')) {
            $prop = $reflection->getProperty('financialTraitBootedFor');
            $prop->setAccessible(true);
            $prop->setValue([]);
        }

        if ($reflection->hasProperty('financialTraitAlreadyBooted')) {
            $prop = $reflection->getProperty('financialTraitAlreadyBooted');
            $prop->setAccessible(true);
            $prop->setValue(false);
        }
    }
}

/**
 * Base stub that uses the Financial trait, simulating a WinterCMS Model base.
 * In the real codebase, multiple models (Payment, Order) extend a common base
 * and share the static property through inheritance.
 */
class FinancialBaseStub
{
    use Financial;

    /** @var string[] Track which classes called extend() during boot */
    public static $extendCalledBy = [];

    protected $financial = [
        'price' => ['balance' => 'amount_stored', 'currency' => 'currency'],
    ];

    protected $attributes = [];

    /**
     * Stub for WinterCMS Model::extend(). Records the calling class
     * so the test can verify both children booted successfully.
     */
    public static function extend(callable $callback): void
    {
        static::$extendCalledBy[] = static::class;
    }
}

/**
 * Child stub A -- simulates Payment model.
 */
class FinancialChildStubA extends FinancialBaseStub
{
    protected $financial = [
        'amount' => ['balance' => 'amount_stored', 'currency' => 'currency'],
    ];
}

/**
 * Child stub B -- simulates Order model.
 */
class FinancialChildStubB extends FinancialBaseStub
{
    protected $financial = [
        'total' => ['balance' => 'total_stored', 'currency' => 'total_currency'],
    ];
}
