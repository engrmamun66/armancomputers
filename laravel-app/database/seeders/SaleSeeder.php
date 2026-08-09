<?php

namespace Database\Seeders;

use App\Models\Customer;
use App\Models\Invoice;
use App\Models\InvoiceItem;
use App\Models\Product;
use App\Models\Sale;
use App\Models\SaleItem;
use App\Models\Status;
use App\Models\User;
use App\Services\ReferenceNumberGenerator;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class SaleSeeder extends Seeder
{
    public function run(): void
    {
        if (Sale::query()->count() > 0) {
            return;
        }

        $saleStatusId = Status::id(Status::TYPE_SALE, 'completed');
        $invoiceStatusId = Status::id(Status::TYPE_INVOICE, 'issued');
        $creators = User::query()->pluck('id');
        $customers = Customer::query()->pluck('id');
        $paymentMethods = ['cash', 'bank', 'card', 'mobile_banking'];

        for ($batch = 0; $batch < 15; $batch++) {
            DB::transaction(function () use ($saleStatusId, $invoiceStatusId, $creators, $customers, $paymentMethods) {
                $products = Product::query()->where('current_stock', '>', 0)->inRandomOrder()->limit(random_int(1, 3))->get();

                if ($products->isEmpty()) {
                    return;
                }

                $subtotal = 0;
                $itemRows = [];

                foreach ($products as $product) {
                    $maxQty = min($product->current_stock, 8);
                    if ($maxQty < 1) {
                        continue;
                    }
                    $quantity = random_int(1, $maxQty);
                    $unitPrice = $product->selling_price;
                    $total = round($quantity * $unitPrice, 2);
                    $subtotal += $total;

                    $itemRows[] = [
                        'product_id' => $product->id,
                        'quantity' => $quantity,
                        'unit_price' => $unitPrice,
                        'total_price' => $total,
                    ];
                }

                if (empty($itemRows)) {
                    return;
                }

                $discount = round($subtotal * 0.01, 2);
                $additionalCost = 0;
                $grandTotal = $subtotal - $discount + $additionalCost;

                $paymentRoll = random_int(1, 10);
                $paidAmount = match (true) {
                    $paymentRoll <= 6 => $grandTotal,
                    $paymentRoll <= 9 => round($grandTotal * 0.5, 2),
                    default => 0,
                };
                $dueAmount = round($grandTotal - $paidAmount, 2);

                $saleDate = now()->subDays(random_int(0, 30))->toDateString();
                $createdBy = $creators->random();
                $customerId = $customers->random();

                $sale = Sale::query()->create([
                    'reference_no' => ReferenceNumberGenerator::generate('SAL', 'sales'),
                    'customer_id' => $customerId,
                    'sale_date' => $saleDate,
                    'subtotal' => $subtotal,
                    'discount' => $discount,
                    'additional_cost' => $additionalCost,
                    'grand_total' => $grandTotal,
                    'paid_amount' => $paidAmount,
                    'due_amount' => $dueAmount,
                    'payment_method' => $paymentMethods[array_rand($paymentMethods)],
                    'notes' => null,
                    'status_id' => $saleStatusId,
                    'created_by' => $createdBy,
                ]);

                foreach ($itemRows as $row) {
                    SaleItem::query()->create($row + ['sale_id' => $sale->id]);
                    Product::query()->whereKey($row['product_id'])->decrement('current_stock', $row['quantity']);
                }

                $invoice = Invoice::query()->create([
                    'invoice_number' => ReferenceNumberGenerator::generate('INV', 'invoices', 'invoice_number'),
                    'sale_id' => $sale->id,
                    'customer_id' => $customerId,
                    'invoice_date' => $saleDate,
                    'subtotal' => $subtotal,
                    'discount' => $discount,
                    'additional_cost' => $additionalCost,
                    'grand_total' => $grandTotal,
                    'paid_amount' => $paidAmount,
                    'due_amount' => $dueAmount,
                    'status_id' => $invoiceStatusId,
                    'created_by' => $createdBy,
                ]);

                foreach ($itemRows as $row) {
                    InvoiceItem::query()->create($row + ['invoice_id' => $invoice->id]);
                }
            });
        }
    }
}
