<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Concerns\Sortable;
use App\Http\Controllers\Controller;
use App\Http\Requests\Purchase\StorePurchaseRequest;
use App\Http\Requests\Purchase\UpdatePurchaseRequest;
use App\Http\Resources\PurchaseResource;
use App\Models\Product;
use App\Models\Purchase;
use App\Models\PurchaseItem;
use App\Models\Status;
use App\Models\User;
use App\Services\ReferenceNumberGenerator;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use RuntimeException;

class PurchaseController extends Controller
{
    use Sortable;

    public function index(Request $request)
    {
        $this->authorize('viewAny', Purchase::class);

        $filtered = Purchase::query()
            ->when($request->filled('search'), function ($query) use ($request) {
                $term = "%{$request->string('search')}%";
                $query->where(fn ($q) => $q->where('reference_no', 'like', $term)->orWhere('supplier_name', 'like', $term));
            })
            ->when($request->filled('date_from'), fn ($q) => $q->whereDate('purchase_date', '>=', $request->string('date_from')))
            ->when($request->filled('date_to'), fn ($q) => $q->whereDate('purchase_date', '<=', $request->string('date_to')))
            ->when($request->filled('status_id'), fn ($q) => $q->where('status_id', $request->integer('status_id')))
            ->when($request->filled('user_id'), fn ($q) => $q->where('created_by', $request->integer('user_id')));

        $ids = (clone $filtered)->pluck('id');
        $totals = [
            'items_count' => (int) PurchaseItem::whereIn('purchase_id', $ids)->count(),
            'total_qty' => (int) PurchaseItem::whereIn('purchase_id', $ids)->sum('quantity'),
            'total_amount' => (float) (clone $filtered)->sum('grand_total'),
        ];

        $filtered
            ->with(['status', 'creator'])
            ->withCount('items')
            ->withSum('items as total_qty', 'quantity');

        $this->applySort($filtered, $request, [
            'reference_no' => 'reference_no',
            'purchase_date' => 'purchase_date',
            'supplier_name' => 'supplier_name',
            'items_count' => 'items_count',
            'total_qty' => 'total_qty',
            'grand_total' => 'grand_total',
            'status' => 'status_id',
            'created_by' => fn ($q, $dir) => $q->orderBy(User::select('name')->whereColumn('users.id', 'purchases.created_by'), $dir),
            'created_at' => 'created_at',
        ], 'purchase_date', 'desc');
        $filtered->orderByDesc('id');

        $purchases = $filtered->paginate($request->integer('per_page', 15));

        return PurchaseResource::collection($purchases)->additional(['success' => true, 'message' => '', 'totals' => $totals]);
    }

    public function store(StorePurchaseRequest $request)
    {
        $this->authorize('create', Purchase::class);

        $validated = $request->validated();
        $items = $validated['items'];

        $purchase = DB::transaction(function () use ($validated, $items, $request) {
            $subtotal = collect($items)->sum(fn ($item) => $item['quantity'] * $item['unit_price']);
            $discount = $validated['discount'] ?? 0;
            $additionalCost = $validated['additional_cost'] ?? 0;
            $grandTotal = $subtotal - $discount + $additionalCost;

            $purchase = Purchase::query()->create([
                'reference_no' => ReferenceNumberGenerator::generate('PUR', 'purchases'),
                'supplier_name' => $validated['supplier_name'] ?? null,
                'supplier_phone' => $validated['supplier_phone'] ?? null,
                'purchase_date' => $validated['purchase_date'],
                'warranty_end_date' => $validated['warranty_end_date'] ?? null,
                'subtotal' => $subtotal,
                'discount' => $discount,
                'additional_cost' => $additionalCost,
                'grand_total' => $grandTotal,
                'notes' => $validated['notes'] ?? null,
                'status_id' => Status::id(Status::TYPE_PURCHASE, 'completed'),
                'created_by' => $request->user()->id,
            ]);

            foreach ($items as $item) {
                $purchase->items()->create([
                    'product_id' => $item['product_id'],
                    'quantity' => $item['quantity'],
                    'unit_price' => $item['unit_price'],
                    'total_price' => $item['quantity'] * $item['unit_price'],
                ]);

                Product::query()->whereKey($item['product_id'])->increment('current_stock', $item['quantity']);
            }

            return $purchase;
        });

        return $this->success(
            new PurchaseResource($purchase->load('items.product', 'status', 'creator')),
            'Purchase created successfully.',
            201
        );
    }

    public function show(Purchase $purchase)
    {
        $this->authorize('view', Purchase::class);

        return $this->success(new PurchaseResource($purchase->load('items.product', 'status', 'creator')));
    }

    public function update(UpdatePurchaseRequest $request, Purchase $purchase)
    {
        $this->authorize('update', Purchase::class);

        $validated = $request->validated();
        $newItems = $validated['items'];

        try {
            DB::transaction(function () use ($validated, $newItems, $purchase) {
                $oldItems = $purchase->items()->get();

                foreach ($oldItems as $oldItem) {
                    Product::query()->whereKey($oldItem->product_id)->decrement('current_stock', $oldItem->quantity);
                }

                $purchase->items()->delete();

                $subtotal = 0;
                foreach ($newItems as $item) {
                    $totalPrice = $item['quantity'] * $item['unit_price'];
                    $subtotal += $totalPrice;

                    $purchase->items()->create([
                        'product_id' => $item['product_id'],
                        'quantity' => $item['quantity'],
                        'unit_price' => $item['unit_price'],
                        'total_price' => $totalPrice,
                    ]);

                    Product::query()->whereKey($item['product_id'])->increment('current_stock', $item['quantity']);
                }

                $affectedProductIds = $oldItems->pluck('product_id')
                    ->merge(collect($newItems)->pluck('product_id'))
                    ->unique();

                if (Product::query()->whereIn('id', $affectedProductIds)->where('current_stock', '<', 0)->exists()) {
                    throw new RuntimeException('This change would result in negative stock for one or more products. Adjust the quantities and try again.');
                }

                $discount = $validated['discount'] ?? 0;
                $additionalCost = $validated['additional_cost'] ?? 0;

                $purchase->update([
                    'supplier_name' => $validated['supplier_name'] ?? null,
                    'supplier_phone' => $validated['supplier_phone'] ?? null,
                    'purchase_date' => $validated['purchase_date'],
                    'warranty_end_date' => $validated['warranty_end_date'] ?? null,
                    'subtotal' => $subtotal,
                    'discount' => $discount,
                    'additional_cost' => $additionalCost,
                    'grand_total' => $subtotal - $discount + $additionalCost,
                    'notes' => $validated['notes'] ?? null,
                ]);
            });
        } catch (RuntimeException $e) {
            return $this->error($e->getMessage(), null, 422);
        }

        return $this->success(
            new PurchaseResource($purchase->fresh()->load('items.product', 'status', 'creator')),
            'Purchase updated successfully.'
        );
    }

    public function destroy(Purchase $purchase)
    {
        $this->authorize('delete', Purchase::class);

        try {
            DB::transaction(function () use ($purchase) {
                $items = $purchase->items()->get();

                foreach ($items as $item) {
                    Product::query()->whereKey($item->product_id)->decrement('current_stock', $item->quantity);
                }

                if (Product::query()->whereIn('id', $items->pluck('product_id'))->where('current_stock', '<', 0)->exists()) {
                    throw new RuntimeException('Cannot delete: reversing this Purchase would leave one or more products with negative stock.');
                }

                $purchase->update(['status_id' => Status::id(Status::TYPE_PURCHASE, 'cancelled')]);
                $purchase->delete();
            });
        } catch (RuntimeException $e) {
            return $this->error($e->getMessage(), null, 422);
        }

        return $this->success(null, 'Purchase deleted successfully.');
    }
}
