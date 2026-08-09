<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\StockOut\StoreStockOutRequest;
use App\Http\Requests\StockOut\UpdateStockOutRequest;
use App\Http\Resources\StockOutResource;
use App\Models\Invoice;
use App\Models\Product;
use App\Models\Status;
use App\Models\StockOut;
use App\Services\ReferenceNumberGenerator;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use RuntimeException;

class StockOutController extends Controller
{
    public function index(Request $request)
    {
        $this->authorize('viewAny', StockOut::class);

        $stockOuts = StockOut::query()
            ->with(['customer', 'status', 'creator'])
            ->withCount('items')
            ->withSum('items as total_qty', 'quantity')
            ->when($request->filled('search'), function ($query) use ($request) {
                $term = "%{$request->string('search')}%";
                $query->where(function ($q) use ($term) {
                    $q->where('reference_no', 'like', $term)
                        ->orWhereHas('customer', fn ($c) => $c->where('name', 'like', $term))
                        ->orWhereHas('items.product', fn ($p) => $p->where('name', 'like', $term)->orWhere('sku', 'like', $term));
                });
            })
            ->when($request->filled('customer_id'), fn ($q) => $q->where('customer_id', $request->integer('customer_id')))
            ->when($request->filled('date_from'), fn ($q) => $q->whereDate('sale_date', '>=', $request->string('date_from')))
            ->when($request->filled('date_to'), fn ($q) => $q->whereDate('sale_date', '<=', $request->string('date_to')))
            ->when($request->filled('status_id'), fn ($q) => $q->where('status_id', $request->integer('status_id')))
            ->when($request->filled('payment_status'), function ($query) use ($request) {
                match ($request->string('payment_status')->value()) {
                    'paid' => $query->where('due_amount', '<=', 0),
                    'partial' => $query->where('due_amount', '>', 0)->where('paid_amount', '>', 0),
                    'due' => $query->where('paid_amount', '<=', 0),
                    default => null,
                };
            })
            ->orderByDesc('sale_date')
            ->orderByDesc('id')
            ->paginate($request->integer('per_page', 15));

        return StockOutResource::collection($stockOuts)->additional(['success' => true, 'message' => '']);
    }

    public function store(StoreStockOutRequest $request)
    {
        $this->authorize('create', StockOut::class);

        $validated = $request->validated();
        $items = $validated['items'];

        try {
            $stockOut = DB::transaction(function () use ($validated, $items, $request) {
                $products = [];
                foreach ($items as $item) {
                    $product = Product::query()->whereKey($item['product_id'])->lockForUpdate()->first();

                    if (! $product) {
                        throw new RuntimeException('One of the selected products no longer exists.');
                    }

                    if ($product->current_stock < $item['quantity']) {
                        throw new RuntimeException("Insufficient stock for \"{$product->name}\". Available quantity: {$product->current_stock}.");
                    }

                    $products[$item['product_id']] = $product;
                }

                $subtotal = collect($items)->sum(fn ($item) => $item['quantity'] * $item['unit_price']);
                $discount = $validated['discount'] ?? 0;
                $additionalCost = $validated['additional_cost'] ?? 0;
                $grandTotal = $subtotal - $discount + $additionalCost;
                $paidAmount = min($validated['paid_amount'] ?? 0, $grandTotal);
                $dueAmount = round($grandTotal - $paidAmount, 2);

                $stockOut = StockOut::query()->create([
                    'reference_no' => ReferenceNumberGenerator::generate('SO', 'stock_outs'),
                    'customer_id' => $validated['customer_id'],
                    'sale_date' => $validated['sale_date'],
                    'subtotal' => $subtotal,
                    'discount' => $discount,
                    'additional_cost' => $additionalCost,
                    'grand_total' => $grandTotal,
                    'paid_amount' => $paidAmount,
                    'due_amount' => $dueAmount,
                    'payment_method' => $validated['payment_method'],
                    'notes' => $validated['notes'] ?? null,
                    'status_id' => Status::id(Status::TYPE_STOCK_OUT, 'completed'),
                    'created_by' => $request->user()->id,
                ]);

                foreach ($items as $item) {
                    $stockOut->items()->create([
                        'product_id' => $item['product_id'],
                        'quantity' => $item['quantity'],
                        'unit_price' => $item['unit_price'],
                        'total_price' => $item['quantity'] * $item['unit_price'],
                    ]);

                    $affected = Product::query()
                        ->whereKey($item['product_id'])
                        ->where('current_stock', '>=', $item['quantity'])
                        ->decrement('current_stock', $item['quantity']);

                    if ($affected === 0) {
                        $name = $products[$item['product_id']]->name;
                        throw new RuntimeException("Stock for \"{$name}\" changed while processing this sale. Please try again.");
                    }
                }

                $invoice = Invoice::query()->create([
                    'invoice_number' => ReferenceNumberGenerator::generate('INV', 'invoices', 'invoice_number'),
                    'stock_out_id' => $stockOut->id,
                    'customer_id' => $validated['customer_id'],
                    'invoice_date' => $validated['sale_date'],
                    'subtotal' => $subtotal,
                    'discount' => $discount,
                    'additional_cost' => $additionalCost,
                    'grand_total' => $grandTotal,
                    'paid_amount' => $paidAmount,
                    'due_amount' => $dueAmount,
                    'status_id' => Status::id(Status::TYPE_INVOICE, 'issued'),
                    'created_by' => $request->user()->id,
                ]);

                foreach ($items as $item) {
                    $invoice->items()->create([
                        'product_id' => $item['product_id'],
                        'quantity' => $item['quantity'],
                        'unit_price' => $item['unit_price'],
                        'total_price' => $item['quantity'] * $item['unit_price'],
                    ]);
                }

                return $stockOut;
            });
        } catch (RuntimeException $e) {
            return $this->error($e->getMessage(), null, 422);
        }

        return $this->success(
            new StockOutResource($stockOut->load('items.product', 'status', 'creator', 'customer', 'invoice')),
            'Stock Out created successfully.',
            201
        );
    }

    public function show(StockOut $stockOut)
    {
        $this->authorize('view', StockOut::class);

        return $this->success(
            new StockOutResource($stockOut->load('items.product', 'status', 'creator', 'customer', 'invoice'))
        );
    }

    public function update(UpdateStockOutRequest $request, StockOut $stockOut)
    {
        $this->authorize('update', StockOut::class);

        $validated = $request->validated();
        $newItems = $validated['items'];

        try {
            DB::transaction(function () use ($validated, $newItems, $stockOut) {
                $oldItems = $stockOut->items()->get();

                foreach ($oldItems as $oldItem) {
                    Product::query()->whereKey($oldItem->product_id)->increment('current_stock', $oldItem->quantity);
                }

                $products = [];
                foreach ($newItems as $item) {
                    $product = Product::query()->whereKey($item['product_id'])->lockForUpdate()->first();

                    if (! $product) {
                        throw new RuntimeException('One of the selected products no longer exists.');
                    }

                    if ($product->current_stock < $item['quantity']) {
                        throw new RuntimeException("Insufficient stock for \"{$product->name}\". Available quantity: {$product->current_stock}.");
                    }

                    $products[$item['product_id']] = $product;
                }

                $stockOut->items()->delete();

                $subtotal = 0;
                foreach ($newItems as $item) {
                    $totalPrice = $item['quantity'] * $item['unit_price'];
                    $subtotal += $totalPrice;

                    $stockOut->items()->create([
                        'product_id' => $item['product_id'],
                        'quantity' => $item['quantity'],
                        'unit_price' => $item['unit_price'],
                        'total_price' => $totalPrice,
                    ]);

                    $affected = Product::query()
                        ->whereKey($item['product_id'])
                        ->where('current_stock', '>=', $item['quantity'])
                        ->decrement('current_stock', $item['quantity']);

                    if ($affected === 0) {
                        $name = $products[$item['product_id']]->name;
                        throw new RuntimeException("Stock for \"{$name}\" changed while processing this update. Please try again.");
                    }
                }

                $discount = $validated['discount'] ?? 0;
                $additionalCost = $validated['additional_cost'] ?? 0;
                $grandTotal = $subtotal - $discount + $additionalCost;
                $paidAmount = min($validated['paid_amount'] ?? 0, $grandTotal);
                $dueAmount = round($grandTotal - $paidAmount, 2);

                $stockOut->update([
                    'customer_id' => $validated['customer_id'],
                    'sale_date' => $validated['sale_date'],
                    'subtotal' => $subtotal,
                    'discount' => $discount,
                    'additional_cost' => $additionalCost,
                    'grand_total' => $grandTotal,
                    'paid_amount' => $paidAmount,
                    'due_amount' => $dueAmount,
                    'payment_method' => $validated['payment_method'],
                    'notes' => $validated['notes'] ?? null,
                ]);

                $invoice = $stockOut->invoice;
                if ($invoice) {
                    $invoice->items()->delete();
                    foreach ($newItems as $item) {
                        $invoice->items()->create([
                            'product_id' => $item['product_id'],
                            'quantity' => $item['quantity'],
                            'unit_price' => $item['unit_price'],
                            'total_price' => $item['quantity'] * $item['unit_price'],
                        ]);
                    }
                    $invoice->update([
                        'customer_id' => $validated['customer_id'],
                        'invoice_date' => $validated['sale_date'],
                        'subtotal' => $subtotal,
                        'discount' => $discount,
                        'additional_cost' => $additionalCost,
                        'grand_total' => $grandTotal,
                        'paid_amount' => $paidAmount,
                        'due_amount' => $dueAmount,
                    ]);
                }
            });
        } catch (RuntimeException $e) {
            return $this->error($e->getMessage(), null, 422);
        }

        return $this->success(
            new StockOutResource($stockOut->fresh()->load('items.product', 'status', 'creator', 'customer', 'invoice')),
            'Stock Out updated successfully.'
        );
    }

    public function destroy(StockOut $stockOut)
    {
        $this->authorize('delete', StockOut::class);

        DB::transaction(function () use ($stockOut) {
            $items = $stockOut->items()->get();

            foreach ($items as $item) {
                Product::query()->whereKey($item->product_id)->increment('current_stock', $item->quantity);
            }

            $stockOut->update(['status_id' => Status::id(Status::TYPE_STOCK_OUT, 'cancelled')]);

            if ($stockOut->invoice) {
                $stockOut->invoice->update(['status_id' => Status::id(Status::TYPE_INVOICE, 'cancelled')]);
            }

            $stockOut->delete();
        });

        return $this->success(null, 'Stock Out deleted successfully.');
    }
}
