<?php

namespace Database\Seeders;

use App\Models\Product;
use App\Models\Purchase;
use App\Models\PurchaseItem;
use App\Models\Status;
use App\Models\User;
use App\Services\ReferenceNumberGenerator;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class PurchaseSeeder extends Seeder
{
    public function run(): void
    {
        if (Purchase::query()->count() > 0) {
            return;
        }

        $statusId = Status::id(Status::TYPE_PURCHASE, 'completed');
        $creators = User::query()->pluck('id');
        $suppliers = ['Global Tech Distributors', 'Micro Traders Ltd', 'Bright Star Imports', 'City Electronics Wholesale'];

        for ($batch = 0; $batch < 8; $batch++) {
            DB::transaction(function () use ($statusId, $creators, $suppliers, $batch) {
                $products = Product::query()->inRandomOrder()->limit(random_int(2, 4))->get();
                $subtotal = 0;
                $itemRows = [];

                foreach ($products as $product) {
                    $quantity = random_int(10, 50);
                    $unitPrice = $product->purchase_price;
                    $total = round($quantity * $unitPrice, 2);
                    $subtotal += $total;

                    $itemRows[] = [
                        'product_id' => $product->id,
                        'quantity' => $quantity,
                        'unit_price' => $unitPrice,
                        'total_price' => $total,
                    ];
                }

                $discount = round($subtotal * 0.02, 2);
                $additionalCost = random_int(0, 1) ? random_int(100, 500) : 0;
                $grandTotal = $subtotal - $discount + $additionalCost;

                $purchaseDate = now()->subDays(random_int(1, 60));
                $warrantyDays = [null, 20, 90, 365][random_int(0, 3)];

                $purchase = Purchase::query()->create([
                    'reference_no' => ReferenceNumberGenerator::generate('PUR', 'purchases'),
                    'supplier_name' => $suppliers[array_rand($suppliers)],
                    'supplier_phone' => '01' . random_int(700000000, 999999999),
                    'purchase_date' => $purchaseDate->toDateString(),
                    'warranty_end_date' => $warrantyDays ? $purchaseDate->copy()->addDays($warrantyDays)->toDateString() : null,
                    'subtotal' => $subtotal,
                    'discount' => $discount,
                    'additional_cost' => $additionalCost,
                    'grand_total' => $grandTotal,
                    'notes' => null,
                    'status_id' => $statusId,
                    'created_by' => $creators->random(),
                ]);

                foreach ($itemRows as $row) {
                    PurchaseItem::query()->create($row + ['purchase_id' => $purchase->id]);
                    Product::query()->whereKey($row['product_id'])->increment('current_stock', $row['quantity']);
                }
            });
        }
    }
}
