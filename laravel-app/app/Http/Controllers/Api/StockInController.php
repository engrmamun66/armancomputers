<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\StockIn\StoreStockInRequest;
use App\Http\Requests\StockIn\UpdateStockInRequest;
use App\Http\Resources\StockInResource;
use App\Models\Product;
use App\Models\Status;
use App\Models\StockIn;
use App\Services\ReferenceNumberGenerator;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use RuntimeException;

class StockInController extends Controller
{
    public function index(Request $request)
    {
        $this->authorize('viewAny', StockIn::class);

        $stockIns = StockIn::query()
            ->with(['status', 'creator'])
            ->withCount('items')
            ->withSum('items as total_qty', 'quantity')
            ->when($request->filled('search'), function ($query) use ($request) {
                $term = "%{$request->string('search')}%";
                $query->where(fn ($q) => $q->where('reference_no', 'like', $term)->orWhere('supplier_name', 'like', $term));
            })
            ->when($request->filled('date_from'), fn ($q) => $q->whereDate('purchase_date', '>=', $request->string('date_from')))
            ->when($request->filled('date_to'), fn ($q) => $q->whereDate('purchase_date', '<=', $request->string('date_to')))
            ->when($request->filled('status_id'), fn ($q) => $q->where('status_id', $request->integer('status_id')))
            ->when($request->filled('user_id'), fn ($q) => $q->where('created_by', $request->integer('user_id')))
            ->orderByDesc('purchase_date')
            ->orderByDesc('id')
            ->paginate($request->integer('per_page', 15));

        return StockInResource::collection($stockIns)->additional(['success' => true, 'message' => '']);
    }

    public function store(StoreStockInRequest $request)
    {
        $this->authorize('create', StockIn::class);

        $validated = $request->validated();
        $items = $validated['items'];

        $stockIn = DB::transaction(function () use ($validated, $items, $request) {
            $subtotal = collect($items)->sum(fn ($item) => $item['quantity'] * $item['unit_price']);
            $discount = $validated['discount'] ?? 0;
            $additionalCost = $validated['additional_cost'] ?? 0;
            $grandTotal = $subtotal - $discount + $additionalCost;

            $stockIn = StockIn::query()->create([
                'reference_no' => ReferenceNumberGenerator::generate('SI', 'stock_ins'),
                'supplier_name' => $validated['supplier_name'] ?? null,
                'supplier_phone' => $validated['supplier_phone'] ?? null,
                'purchase_date' => $validated['purchase_date'],
                'subtotal' => $subtotal,
                'discount' => $discount,
                'additional_cost' => $additionalCost,
                'grand_total' => $grandTotal,
                'notes' => $validated['notes'] ?? null,
                'status_id' => Status::id(Status::TYPE_STOCK_IN, 'completed'),
                'created_by' => $request->user()->id,
            ]);

            foreach ($items as $item) {
                $stockIn->items()->create([
                    'product_id' => $item['product_id'],
                    'quantity' => $item['quantity'],
                    'unit_price' => $item['unit_price'],
                    'total_price' => $item['quantity'] * $item['unit_price'],
                ]);

                Product::query()->whereKey($item['product_id'])->increment('current_stock', $item['quantity']);
            }

            return $stockIn;
        });

        return $this->success(
            new StockInResource($stockIn->load('items.product', 'status', 'creator')),
            'Stock In created successfully.',
            201
        );
    }

    public function show(StockIn $stockIn)
    {
        $this->authorize('view', StockIn::class);

        return $this->success(new StockInResource($stockIn->load('items.product', 'status', 'creator')));
    }

    public function update(UpdateStockInRequest $request, StockIn $stockIn)
    {
        $this->authorize('update', StockIn::class);

        $validated = $request->validated();
        $newItems = $validated['items'];

        try {
            DB::transaction(function () use ($validated, $newItems, $stockIn) {
                $oldItems = $stockIn->items()->get();

                foreach ($oldItems as $oldItem) {
                    Product::query()->whereKey($oldItem->product_id)->decrement('current_stock', $oldItem->quantity);
                }

                $stockIn->items()->delete();

                $subtotal = 0;
                foreach ($newItems as $item) {
                    $totalPrice = $item['quantity'] * $item['unit_price'];
                    $subtotal += $totalPrice;

                    $stockIn->items()->create([
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

                $stockIn->update([
                    'supplier_name' => $validated['supplier_name'] ?? null,
                    'supplier_phone' => $validated['supplier_phone'] ?? null,
                    'purchase_date' => $validated['purchase_date'],
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
            new StockInResource($stockIn->fresh()->load('items.product', 'status', 'creator')),
            'Stock In updated successfully.'
        );
    }

    public function destroy(StockIn $stockIn)
    {
        $this->authorize('delete', StockIn::class);

        try {
            DB::transaction(function () use ($stockIn) {
                $items = $stockIn->items()->get();

                foreach ($items as $item) {
                    Product::query()->whereKey($item->product_id)->decrement('current_stock', $item->quantity);
                }

                if (Product::query()->whereIn('id', $items->pluck('product_id'))->where('current_stock', '<', 0)->exists()) {
                    throw new RuntimeException('Cannot delete: reversing this Stock In would leave one or more products with negative stock.');
                }

                $stockIn->update(['status_id' => Status::id(Status::TYPE_STOCK_IN, 'cancelled')]);
                $stockIn->delete();
            });
        } catch (RuntimeException $e) {
            return $this->error($e->getMessage(), null, 422);
        }

        return $this->success(null, 'Stock In deleted successfully.');
    }
}
