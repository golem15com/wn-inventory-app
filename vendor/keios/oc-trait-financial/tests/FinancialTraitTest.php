<?php namespace Keios\Financial\Tests;

use Keios\Financial\Financial;

/**
 * PoC tests for PAY-13 (OTF-001): Financial trait per-class boot tracking.
 *
 * The trait uses a single static $financialTraitAlreadyBooted boolean,
 * which means the SECOND class using the trait skips boot entirely --
 * leaving model.beforeSetAttribute UNBOUND for that class.
 *
 * These tests MUST FAIL (RED) before the fix is applied and PASS (GREEN) after.
 *
 * @group security
 */
class FinancialTraitTest extends \PHPUnit\Framework\TestCase
{
    /**
     * PAY-13: Two distinct model classes using the Financial trait must both
     * successfully boot and register their event listeners independently.
     *
     * Before fix: the second class skips boot because static $financialTraitAlreadyBooted
     * is already true from the first class's boot. After fix: per-class tracking via
     * static $financialTraitBootedFor allows each class to boot independently.
     *
     * @test
     */
    public function test_pay_13_financial_trait_per_class_boot(): void
    {
        // Reset the boot state via reflection so test is isolated
        $this->resetBootState();

        // Call bootFinancial on the first stub class
        FinancialModelStubA::bootFinancial();

        // Call bootFinancial on the second stub class
        FinancialModelStubB::bootFinancial();

        // After fix: both classes should be registered in $financialTraitBootedFor
        // Before fix: only the first class sets $financialTraitAlreadyBooted = true,
        // the second class returns early and never registers its listeners.

        // Use reflection to read the boot tracking property
        $reflection = new \ReflectionClass(FinancialModelStubA::class);

        // After fix, the property should be $financialTraitBootedFor (array)
        // Before fix, the property is $financialTraitAlreadyBooted (bool)
        if ($reflection->hasProperty('financialTraitBootedFor')) {
            $prop = $reflection->getProperty('financialTraitBootedFor');
            $prop->setAccessible(true);
            $bootedFor = $prop->getValue();

            $this->assertArrayHasKey(
                FinancialModelStubA::class,
                $bootedFor,
                'PAY-13: First class should be registered in $financialTraitBootedFor'
            );
            $this->assertArrayHasKey(
                FinancialModelStubB::class,
                $bootedFor,
                'PAY-13: Second class should be registered in $financialTraitBootedFor but was skipped due to single-boolean boot guard'
            );
        } else {
            // Pre-fix: property is $financialTraitAlreadyBooted (single boolean)
            // This means per-class tracking is not implemented yet -- FAIL
            $this->fail(
                'PAY-13: Financial trait still uses single $financialTraitAlreadyBooted boolean. '
                . 'Per-class boot tracking via $financialTraitBootedFor is required.'
            );
        }
    }

    /**
     * Reset the Financial trait's static boot state via reflection.
     */
    private function resetBootState(): void
    {
        $reflection = new \ReflectionClass(FinancialModelStubA::class);

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
 * Minimal stub class A using the Financial trait.
 * Uses a minimal extend() static method to satisfy the trait's boot requirements
 * without needing the full WinterCMS model infrastructure.
 */
class FinancialModelStubA
{
    use Financial;

    protected $financial = [
        'price' => ['balance' => 'amount_stored', 'currency' => 'currency'],
    ];

    protected $attributes = [];

    /**
     * Stub for WinterCMS Model::extend() used by Financial trait's bootFinancial().
     */
    public static function extend(callable $callback): void
    {
        // No-op for test purposes -- we only need boot registration to succeed
    }
}

/**
 * Minimal stub class B using the Financial trait.
 */
class FinancialModelStubB
{
    use Financial;

    protected $financial = [
        'total' => ['balance' => 'total_stored', 'currency' => 'total_currency'],
    ];

    protected $attributes = [];

    /**
     * Stub for WinterCMS Model::extend() used by Financial trait's bootFinancial().
     */
    public static function extend(callable $callback): void
    {
        // No-op for test purposes
    }
}
