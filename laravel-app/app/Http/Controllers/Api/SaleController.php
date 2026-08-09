<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Concerns\Sortable;
use App\Http\Controllers\Controller;
use App\Http\Requests\Sale\StoreSaleRequest;
use App\Http\Requests\Sale\UpdateSaleRequest;
use App\Http\Resources\SaleResource;
use App\Models\Customer;
use App\Models\Invoice;
use App\Models\Product;
use App\Models\Sale;
use App\Models\SaleItem;
use App\Models\Status;
use App\Models\User;
use App\Services\ReferenceNumberGenerator;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use RuntimeException;

class SaleController extends Controller
{
    use Sortable;

    public function index(Request $request)
    {
        $this->authorize('viewAny', Sale::class);

        $filtered = Sale::query()
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
            });

        $ids = (clone $filtered)->pluck('id');
        $totalAmount = (float) (clone $filtered)->sum('grand_total');
        $totalCost = (float) SaleItem::whereIn('sale_id', $ids)
            ->join('products', 'products.id', '=', 'sale_items.product_id')
            ->sum(DB::raw('sale_items.quantity * products.purchase_price'));
        $totals = [
            'items_count' => (int) SaleItem::whereIn('sale_id', $ids)->count(),
            'total_qty' => (int) SaleItem::whereIn('sale_id', $ids)->sum('quantity'),
            'total_amount' => $totalAmount,
            'total_cost' => $totalCost,
            'total_profit' => $totalAmount - $totalCost,
        ];

        $filtered
            ->with(['customer', 'status', 'creator', 'invoice'])
            ->withCount('items')
            ->withSum('items as total_qty', 'quantity');

        $this->applySort($filtered, $request, [
            'reference_no' => 'reference_no',
            'sale_date' => 'sale_date',
            'customer' => fn ($q, $dir) => $q->orderBy(Customer::select('name')->whereColumn('customers.id', 'sales.customer_id'), $dir),
            'items_count' => 'items_count',
            'total_qty' => 'total_qty',
            'grand_total' => 'grand_total',
            'paid_amount' => 'paid_amount',
            'due_amount' => 'due_amount',
            'status' => 'status_id',
            'created_by' => fn ($q, $dir) => $q->orderBy(User::select('name')->whereColumn('users.id', 'sales.created_by'), $dir),
        ], 'sale_date', 'desc');
        $filtered->orderByDesc('id');

        $sales = $filtered->paginate($request->integer('per_page', 15));

        return SaleResource::collection($sales)->additional(['success' => true, 'message' => '', 'totals' => $totals]);
    }

    public function store(StoreSaleRequest $request)
    {
        $this->authorize('create', Sale::class);

        $validated = $request->validated();
        $items = $validated['items'];

        try {
            $sale = DB::transaction(function () use ($validated, $items, $request) {
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

                $sale = Sale::query()->create([
                    'reference_no' => ReferenceNumberGenerator::generate('SAL', 'sales'),
                    'customer_id' => $validated['customer_id'],
                    'sale_date' => $validated['sale_date'],
                    'warranty_end_date' => $validated['warranty_end_date'] ?? null,
                    'subtotal' => $subtotal,
                    'discount' => $discount,
                    'additional_cost' => $additionalCost,
                    'grand_total' => $grandTotal,
                    'paid_amount' => $paidAmount,
                    'due_amount' => $dueAmount,
                    'payment_method' => $validated['payment_method'],
                    'notes' => $validated['notes'] ?? null,
                    'status_id' => Status::id(Status::TYPE_SALE, 'completed'),
                    'created_by' => $request->user()->id,
                ]);

                foreach ($items as $item) {
                    $sale->items()->create([
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
                    'sale_id' => $sale->id,
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

                return $sale;
            });
        } catch (RuntimeException $e) {
            return $this->error($e->getMessage(), null, 422);
        }

        return $this->success(
            new SaleResource($sale->load('items.product', 'status', 'creator', 'customer', 'invoice')),
            'Sale created successfully.',
            201
        );
    }

    public function show(Sale $sale)
    {
        $this->authorize('view', Sale::class);

        return $this->success(
            new SaleResource($sale->load('items.product', 'status', 'creator', 'customer', 'invoice'))
        );
    }

    public function update(UpdateSaleRequest $request, Sale $sale)
    {
        $this->authorize('update', Sale::class);

        $validated = $request->validated();
        $newItems = $validated['items'];

        try {
            DB::transaction(function () use ($validated, $newItems, $sale) {
                $oldItems = $sale->items()->get();

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

                $sale->items()->delete();

                $subtotal = 0;
                foreach ($newItems as $item) {
                    $totalPrice = $item['quantity'] * $item['unit_price'];
                    $subtotal += $totalPrice;

                    $sale->items()->create([
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

                $sale->update([
                    'customer_id' => $validated['customer_id'],
                    'sale_date' => $validated['sale_date'],
                    'warranty_end_date' => $validated['warranty_end_date'] ?? null,
                    'subtotal' => $subtotal,
                    'discount' => $discount,
                    'additional_cost' => $additionalCost,
                    'grand_total' => $grandTotal,
                    'paid_amount' => $paidAmount,
                    'due_amount' => $dueAmount,
                    'payment_method' => $validated['payment_method'],
                    'notes' => $validated['notes'] ?? null,
                ]);

                $invoice = $sale->invoice;
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
            new SaleResource($sale->fresh()->load('items.product', 'status', 'creator', 'customer', 'invoice')),
            'Sale updated successfully.'
        );
    }

    public function destroy(Sale $sale)
    {
        $this->authorize('delete', Sale::class);

        DB::transaction(function () use ($sale) {
            $items = $sale->items()->get();

            foreach ($items as $item) {
                Product::query()->whereKey($item->product_id)->increment('current_stock', $item->quantity);
            }

            $sale->update(['status_id' => Status::id(Status::TYPE_SALE, 'cancelled')]);

            if ($sale->invoice) {
                $sale->invoice->update(['status_id' => Status::id(Status::TYPE_INVOICE, 'cancelled')]);
            }

            $sale->delete();
        });

        return $this->success(null, 'Sale deleted successfully.');
    }
}
