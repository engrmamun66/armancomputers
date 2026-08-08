<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Product\StoreProductRequest;
use App\Http\Requests\Product\UpdateProductRequest;
use App\Http\Resources\ProductResource;
use App\Models\Product;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class ProductController extends Controller
{
    public function index(Request $request)
    {
        $this->authorize('viewAny', Product::class);

        $products = Product::query()
            ->with(['brand', 'status'])
            ->when($request->filled('search'), function ($query) use ($request) {
                $term = "%{$request->string('search')}%";
                $query->where(fn ($q) => $q->where('name', 'like', $term)
                    ->orWhere('sku', 'like', $term)
                    ->orWhere('barcode', 'like', $term));
            })
            ->when($request->filled('brand_id'), fn ($q) => $q->where('brand_id', $request->integer('brand_id')))
            ->when($request->filled('status_id'), fn ($q) => $q->where('status_id', $request->integer('status_id')))
            ->when($request->filled('stock_status'), function ($query) use ($request) {
                match ($request->string('stock_status')->value()) {
                    'out-of-stock' => $query->where('current_stock', '<=', 0),
                    'low-stock' => $query->whereColumn('current_stock', '<=', 'minimum_stock')->where('current_stock', '>', 0),
                    'in-stock' => $query->whereColumn('current_stock', '>', 'minimum_stock'),
                    default => null,
                };
            })
            ->orderBy('name')
            ->paginate($request->integer('per_page', 15));

        return ProductResource::collection($products)->additional(['success' => true, 'message' => '']);
    }

    public function store(StoreProductRequest $request)
    {
        $this->authorize('create', Product::class);

        $product = Product::query()->create([
            ...$request->validated(),
            'current_stock' => 0,
        ]);

        return $this->success(new ProductResource($product->load('brand', 'status')), 'Product created successfully.', 201);
    }

    public function show(Product $product)
    {
        $this->authorize('view', Product::class);

        return $this->success(new ProductResource($product->load('brand', 'status')));
    }

    public function update(UpdateProductRequest $request, Product $product)
    {
        $this->authorize('update', Product::class);

        $product->update($request->validated());

        return $this->success(new ProductResource($product->fresh()->load('brand', 'status')), 'Product updated successfully.');
    }

    public function destroy(Product $product)
    {
        $this->authorize('delete', Product::class);

        $product->delete();

        return $this->success(null, 'Product deleted successfully.');
    }

    public function stockHistory(Product $product)
    {
        $this->authorize('view', Product::class);

        $inRows = DB::table('stock_in_items')
            ->join('stock_ins', 'stock_ins.id', '=', 'stock_in_items.stock_in_id')
            ->join('users', 'users.id', '=', 'stock_ins.created_by')
            ->where('stock_in_items.product_id', $product->id)
            ->select([
                'stock_ins.purchase_date as date',
                DB::raw("'in' as type"),
                'stock_ins.reference_no as reference',
                'stock_in_items.quantity as quantity',
                'users.name as user',
                'stock_in_items.created_at as created_at',
            ])
            ->get();

        $outRows = DB::table('stock_out_items')
            ->join('stock_outs', 'stock_outs.id', '=', 'stock_out_items.stock_out_id')
            ->join('users', 'users.id', '=', 'stock_outs.created_by')
            ->where('stock_out_items.product_id', $product->id)
            ->select([
                'stock_outs.sale_date as date',
                DB::raw("'out' as type"),
                'stock_outs.reference_no as reference',
                'stock_out_items.quantity as quantity',
                'users.name as user',
                'stock_out_items.created_at as created_at',
            ])
            ->get();

        $timeline = $inRows->concat($outRows)->sortBy('created_at')->values();

        $running = 0;
        $history = $timeline->map(function ($row) use (&$running) {
            $before = $running;
            $running += $row->type === 'in' ? $row->quantity : -$row->quantity;

            return [
                'date' => $row->date,
                'type' => $row->type,
                'reference' => $row->reference,
                'quantity' => (int) $row->quantity,
                'stock_before' => $before,
                'stock_after' => $running,
                'user' => $row->user,
            ];
        })->reverse()->values();

        return $this->success([
            'product' => new ProductResource($product->load('brand', 'status')),
            'history' => $history,
        ]);
    }
}
