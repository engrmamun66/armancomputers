<?php

namespace Tests\Feature\Purchase;

use App\Models\Purchase;
use App\Models\Role;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Support\SeedsCore;
use Tests\TestCase;

class PurchaseTest extends TestCase
{
    use RefreshDatabase, SeedsCore;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seedLookups();
    }

    public function test_can_create_purchase_with_multiple_products_and_stock_increases(): void
    {
        $user = $this->makeUser(Role::ADMIN);
        $productA = $this->makeProduct(['current_stock' => 10]);
        $productB = $this->makeProduct(['current_stock' => 0]);

        $response = $this->actingAs($user, 'api')->postJson('/api/purchases', [
            'purchase_date' => now()->toDateString(),
            'supplier_name' => 'Acme Supplies',
            'discount' => 10,
            'additional_cost' => 20,
            'items' => [
                ['product_id' => $productA->id, 'quantity' => 5, 'unit_price' => 100],
                ['product_id' => $productB->id, 'quantity' => 3, 'unit_price' => 200],
            ],
        ]);

        $response->assertStatus(201)->assertJsonPath('success', true);

        $this->assertEquals(15, $productA->fresh()->current_stock);
        $this->assertEquals(3, $productB->fresh()->current_stock);

        // subtotal = 5*100 + 3*200 = 1100; grand_total = 1100 - 10 + 20 = 1110
        $response->assertJsonPath('data.subtotal', 1100)
            ->assertJsonPath('data.grand_total', 1110);

        $this->assertDatabaseCount('purchase_items', 2);
        $this->assertNotEmpty($response->json('data.reference_no'));
    }

    public function test_purchase_requires_at_least_one_item(): void
    {
        $user = $this->makeUser(Role::ADMIN);

        $response = $this->actingAs($user, 'api')->postJson('/api/purchases', [
            'purchase_date' => now()->toDateString(),
            'items' => [],
        ]);

        $response->assertStatus(422)->assertJsonValidationErrors(['items']);
    }

    public function test_purchase_rejects_invalid_quantity(): void
    {
        $user = $this->makeUser(Role::ADMIN);
        $product = $this->makeProduct();

        $response = $this->actingAs($user, 'api')->postJson('/api/purchases', [
            'purchase_date' => now()->toDateString(),
            'items' => [['product_id' => $product->id, 'quantity' => 0, 'unit_price' => 100]],
        ]);

        $response->assertStatus(422)->assertJsonValidationErrors(['items.0.quantity']);
        $this->assertEquals(0, $product->fresh()->current_stock);
    }

    public function test_purchase_rejects_negative_unit_price(): void
    {
        $user = $this->makeUser(Role::ADMIN);
        $product = $this->makeProduct();

        $response = $this->actingAs($user, 'api')->postJson('/api/purchases', [
            'purchase_date' => now()->toDateString(),
            'items' => [['product_id' => $product->id, 'quantity' => 5, 'unit_price' => -10]],
        ]);

        $response->assertStatus(422)->assertJsonValidationErrors(['items.0.unit_price']);
    }

    public function test_deleting_purchase_reverses_stock_effect(): void
    {
        $user = $this->makeUser(Role::ADMIN);
        $product = $this->makeProduct(['current_stock' => 0]);

        $create = $this->actingAs($user, 'api')->postJson('/api/purchases', [
            'purchase_date' => now()->toDateString(),
            'items' => [['product_id' => $product->id, 'quantity' => 20, 'unit_price' => 50]],
        ]);
        $purchaseId = $create->json('data.id');
        $this->assertEquals(20, $product->fresh()->current_stock);

        $this->actingAs($user, 'api')->deleteJson("/api/purchases/{$purchaseId}")->assertOk();

        $this->assertEquals(0, $product->fresh()->current_stock);
        $this->assertSoftDeleted('purchases', ['id' => $purchaseId]);
    }

    public function test_deleting_purchase_is_rejected_if_it_would_cause_negative_stock(): void
    {
        $user = $this->makeUser(Role::ADMIN);
        $product = $this->makeProduct(['current_stock' => 0]);

        $create = $this->actingAs($user, 'api')->postJson('/api/purchases', [
            'purchase_date' => now()->toDateString(),
            'items' => [['product_id' => $product->id, 'quantity' => 20, 'unit_price' => 50]],
        ]);
        $purchaseId = $create->json('data.id');

        // Simulate downstream consumption (e.g. via a Sale) eating into the stock this Purchase provided.
        $product->fresh()->update(['current_stock' => 5]);

        $response = $this->actingAs($user, 'api')->deleteJson("/api/purchases/{$purchaseId}");

        $response->assertStatus(422);
        $this->assertEquals(5, $product->fresh()->current_stock);
        $this->assertDatabaseHas('purchases', ['id' => $purchaseId, 'deleted_at' => null]);
    }

    public function test_staff_cannot_create_purchase(): void
    {
        $staff = $this->makeUser(Role::STAFF);
        $product = $this->makeProduct();

        $response = $this->actingAs($staff, 'api')->postJson('/api/purchases', [
            'purchase_date' => now()->toDateString(),
            'items' => [['product_id' => $product->id, 'quantity' => 5, 'unit_price' => 10]],
        ]);

        $response->assertStatus(403);
        $this->assertEquals(0, Purchase::count());
    }
}
