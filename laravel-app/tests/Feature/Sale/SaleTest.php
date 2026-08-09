<?php

namespace Tests\Feature\Sale;

use App\Models\Invoice;
use App\Models\Role;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Support\SeedsCore;
use Tests\TestCase;

class SaleTest extends TestCase
{
    use RefreshDatabase, SeedsCore;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seedLookups();
    }

    public function test_can_create_sale_with_multiple_products_and_stock_decreases(): void
    {
        $user = $this->makeUser(Role::ADMIN);
        $customer = $this->makeCustomer();
        $productA = $this->makeProduct(['current_stock' => 10, 'selling_price' => 100]);
        $productB = $this->makeProduct(['current_stock' => 5, 'selling_price' => 200]);

        $response = $this->actingAs($user, 'api')->postJson('/api/sales', [
            'customer_id' => $customer->id,
            'sale_date' => now()->toDateString(),
            'payment_method' => 'cash',
            'paid_amount' => 500,
            'items' => [
                ['product_id' => $productA->id, 'quantity' => 4, 'unit_price' => 100],
                ['product_id' => $productB->id, 'quantity' => 2, 'unit_price' => 200],
            ],
        ]);

        $response->assertStatus(201)->assertJsonPath('success', true);

        $this->assertEquals(6, $productA->fresh()->current_stock);
        $this->assertEquals(3, $productB->fresh()->current_stock);

        // grand_total = 4*100 + 2*200 = 800; due = 800 - 500 = 300
        $response->assertJsonPath('data.grand_total', 800)
            ->assertJsonPath('data.due_amount', 300)
            ->assertJsonPath('data.payment_status', 'partial');

        $this->assertNotNull($response->json('data.invoice_id'));
        $this->assertDatabaseCount('invoices', 1);
        $this->assertDatabaseCount('invoice_items', 2);

        $invoice = Invoice::first();
        $this->assertEquals(800, (float) $invoice->grand_total);
        $this->assertEquals(300, (float) $invoice->due_amount);
    }

    public function test_sale_rejects_insufficient_stock_and_does_not_change_stock(): void
    {
        $user = $this->makeUser(Role::ADMIN);
        $customer = $this->makeCustomer();
        $product = $this->makeProduct(['current_stock' => 5]);

        $response = $this->actingAs($user, 'api')->postJson('/api/sales', [
            'customer_id' => $customer->id,
            'sale_date' => now()->toDateString(),
            'payment_method' => 'cash',
            'items' => [['product_id' => $product->id, 'quantity' => 10, 'unit_price' => 50]],
        ]);

        $response->assertStatus(422)->assertJsonPath('success', false);
        $this->assertStringContainsString('Insufficient stock', $response->json('message'));
        $this->assertEquals(5, $product->fresh()->current_stock);
        $this->assertDatabaseCount('sales', 0);
        $this->assertDatabaseCount('invoices', 0);
    }

    public function test_sale_exactly_at_available_stock_succeeds(): void
    {
        $user = $this->makeUser(Role::ADMIN);
        $customer = $this->makeCustomer();
        $product = $this->makeProduct(['current_stock' => 10]);

        $response = $this->actingAs($user, 'api')->postJson('/api/sales', [
            'customer_id' => $customer->id,
            'sale_date' => now()->toDateString(),
            'payment_method' => 'cash',
            'items' => [['product_id' => $product->id, 'quantity' => 10, 'unit_price' => 50]],
        ]);

        $response->assertStatus(201);
        $this->assertEquals(0, $product->fresh()->current_stock);
    }

    public function test_fully_paid_sale_has_zero_due_and_paid_status(): void
    {
        $user = $this->makeUser(Role::ADMIN);
        $customer = $this->makeCustomer();
        $product = $this->makeProduct(['current_stock' => 10, 'selling_price' => 100]);

        $response = $this->actingAs($user, 'api')->postJson('/api/sales', [
            'customer_id' => $customer->id,
            'sale_date' => now()->toDateString(),
            'payment_method' => 'cash',
            'paid_amount' => 1000,
            'items' => [['product_id' => $product->id, 'quantity' => 10, 'unit_price' => 100]],
        ]);

        $response->assertStatus(201)
            ->assertJsonPath('data.due_amount', 0)
            ->assertJsonPath('data.payment_status', 'paid');
    }

    public function test_deleting_sale_reverses_stock_and_cancels_invoice(): void
    {
        $user = $this->makeUser(Role::ADMIN);
        $customer = $this->makeCustomer();
        $product = $this->makeProduct(['current_stock' => 10]);

        $create = $this->actingAs($user, 'api')->postJson('/api/sales', [
            'customer_id' => $customer->id,
            'sale_date' => now()->toDateString(),
            'payment_method' => 'cash',
            'items' => [['product_id' => $product->id, 'quantity' => 4, 'unit_price' => 50]],
        ]);
        $saleId = $create->json('data.id');
        $this->assertEquals(6, $product->fresh()->current_stock);

        $this->actingAs($user, 'api')->deleteJson("/api/sales/{$saleId}")->assertOk();

        $this->assertEquals(10, $product->fresh()->current_stock);
        $this->assertSoftDeleted('sales', ['id' => $saleId]);

        $invoice = Invoice::where('sale_id', $saleId)->first();
        $this->assertEquals('cancelled', $invoice->status->slug);
    }

    public function test_editing_sale_reconciles_stock_correctly(): void
    {
        $user = $this->makeUser(Role::ADMIN);
        $customer = $this->makeCustomer();
        $product = $this->makeProduct(['current_stock' => 20]);

        $create = $this->actingAs($user, 'api')->postJson('/api/sales', [
            'customer_id' => $customer->id,
            'sale_date' => now()->toDateString(),
            'payment_method' => 'cash',
            'items' => [['product_id' => $product->id, 'quantity' => 5, 'unit_price' => 50]],
        ]);
        $saleId = $create->json('data.id');
        $this->assertEquals(15, $product->fresh()->current_stock);

        // Reduce the sold quantity from 5 to 2 — stock should go back up by 3 (to 18).
        $update = $this->actingAs($user, 'api')->putJson("/api/sales/{$saleId}", [
            'customer_id' => $customer->id,
            'sale_date' => now()->toDateString(),
            'payment_method' => 'cash',
            'items' => [['product_id' => $product->id, 'quantity' => 2, 'unit_price' => 50]],
        ]);

        $update->assertOk();
        $this->assertEquals(18, $product->fresh()->current_stock);
    }

    public function test_editing_sale_rejects_when_new_quantity_exceeds_available_stock(): void
    {
        $user = $this->makeUser(Role::ADMIN);
        $customer = $this->makeCustomer();
        $product = $this->makeProduct(['current_stock' => 10]);

        $create = $this->actingAs($user, 'api')->postJson('/api/sales', [
            'customer_id' => $customer->id,
            'sale_date' => now()->toDateString(),
            'payment_method' => 'cash',
            'items' => [['product_id' => $product->id, 'quantity' => 5, 'unit_price' => 50]],
        ]);
        $saleId = $create->json('data.id');
        // current_stock is now 5. Another sale (outside this Sale) consumes it entirely.
        $product->fresh()->update(['current_stock' => 0]);

        // Even after this edit reverses its own original 5 units (0 -> 5), raising the
        // requested quantity to 6 should still exceed what's actually available.
        $update = $this->actingAs($user, 'api')->putJson("/api/sales/{$saleId}", [
            'customer_id' => $customer->id,
            'sale_date' => now()->toDateString(),
            'payment_method' => 'cash',
            'items' => [['product_id' => $product->id, 'quantity' => 6, 'unit_price' => 50]],
        ]);

        $update->assertStatus(422);
        $this->assertEquals(0, $product->fresh()->current_stock);
    }

    public function test_staff_can_create_but_not_delete_sale(): void
    {
        $staff = $this->makeUser(Role::STAFF);
        $customer = $this->makeCustomer();
        $product = $this->makeProduct(['current_stock' => 10]);

        $create = $this->actingAs($staff, 'api')->postJson('/api/sales', [
            'customer_id' => $customer->id,
            'sale_date' => now()->toDateString(),
            'payment_method' => 'cash',
            'items' => [['product_id' => $product->id, 'quantity' => 2, 'unit_price' => 50]],
        ]);
        $create->assertStatus(201);

        $saleId = $create->json('data.id');
        $this->actingAs($staff, 'api')->deleteJson("/api/sales/{$saleId}")->assertStatus(403);
    }
}
