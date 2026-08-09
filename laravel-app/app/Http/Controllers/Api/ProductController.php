<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Concerns\Sortable;
use App\Http\Controllers\Controller;
use App\Http\Requests\Product\StoreProductRequest;
use App\Http\Requests\Product\UpdateProductRequest;
use App\Http\Resources\ProductResource;
use App\Models\Brand;
use App\Models\Product;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class ProductController extends Controller
{
    use Sortable;

    public function index(Request $request)
    {
        $this->authorize('viewAny', Product::class);

        $products = Product::query()
            ->with(['brand', 'status', 'images'])
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
            });

        $this->applySort($products, $request, [
            'name' => 'name',
            'sku' => 'sku',
            'barcode' => 'barcode',
            'brand' => fn ($q, $dir) => $q->orderBy(Brand::select('name')->whereColumn('brands.id', 'products.brand_id'), $dir),
            'purchase_price' => 'purchase_price',
            'selling_price' => 'selling_price',
            'current_stock' => 'current_stock',
            'minimum_stock' => 'minimum_stock',
            'status' => 'status_id',
        ], 'name');

        $products = $products->paginate($request->integer('per_page', 15));

        return ProductResource::collection($products)->additional(['success' => true, 'message' => '']);
    }

    public function store(StoreProductRequest $request)
    {
        $this->authorize('create', Product::class);

        $product = Product::query()->create([
            ...$request->validated(),
            'current_stock' => 0,
        ]);

        return $this->success(new ProductResource($product->load('brand', 'status', 'images')), 'Product created successfully.', 201);
    }

    public function show(Product $product)
    {
        $this->authorize('view', Product::class);

        return $this->success(new ProductResource($product->load('brand', 'status', 'images')));
    }

    public function update(UpdateProductRequest $request, Product $product)
    {
        $this->authorize('update', Product::class);

        $product->update($request->validated());

        return $this->success(new ProductResource($product->fresh()->load('brand', 'status', 'images')), 'Product updated successfully.');
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

        $inRows = DB::table('purchase_items')
            ->join('purchases', 'purchases.id', '=', 'purchase_items.purchase_id')
            ->join('users', 'users.id', '=', 'purchases.created_by')
            ->where('purchase_items.product_id', $product->id)
            ->select([
                'purchases.purchase_date as date',
                DB::raw("'in' as type"),
                'purchases.reference_no as reference',
                'purchase_items.quantity as quantity',
                'users.name as user',
                'purchase_items.created_at as created_at',
            ])
            ->get();

        $outRows = DB::table('sale_items')
            ->join('sales', 'sales.id', '=', 'sale_items.sale_id')
            ->join('users', 'users.id', '=', 'sales.created_by')
            ->where('sale_items.product_id', $product->id)
            ->select([
                'sales.sale_date as date',
                DB::raw("'out' as type"),
                'sales.reference_no as reference',
                'sale_items.quantity as quantity',
                'users.name as user',
                'sale_items.created_at as created_at',
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
            'product' => new ProductResource($product->load('brand', 'status', 'images')),
            'history' => $history,
        ]);
    }
}
