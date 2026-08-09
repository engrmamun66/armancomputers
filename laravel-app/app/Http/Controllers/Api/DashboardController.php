<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Customer;
use App\Models\Product;
use App\Models\Purchase;
use App\Models\Sale;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class DashboardController extends Controller
{
    public function index(Request $request)
    {
        [$from, $to] = $this->resolveRange(
            $request->string('range', 'month')->value(),
            $request->string('date_from')->value(),
            $request->string('date_to')->value()
        );

        $today = now()->toDateString();

        $cards = [
            'total_products' => Product::count(),
            'total_stock_quantity' => (int) Product::sum('current_stock'),
            'total_purchases' => Purchase::whereBetween('purchase_date', [$from, $to])->count(),
            'total_sales' => Sale::whereBetween('sale_date', [$from, $to])->count(),
            'todays_sales' => (float) Sale::whereDate('sale_date', $today)->sum('grand_total'),
            'todays_purchases' => (float) Purchase::whereDate('purchase_date', $today)->sum('grand_total'),
            'total_customers' => Customer::count(),
            'low_stock_products' => Product::whereColumn('current_stock', '<=', 'minimum_stock')->where('current_stock', '>', 0)->count(),
            'out_of_stock_products' => Product::where('current_stock', '<=', 0)->count(),
        ];

        $purchaseByDate = DB::table('purchase_items')
            ->join('purchases', 'purchases.id', '=', 'purchase_items.purchase_id')
            ->whereBetween('purchases.purchase_date', [$from, $to])
            ->selectRaw('purchases.purchase_date as date, SUM(purchase_items.quantity) as qty')
            ->groupBy('purchases.purchase_date')
            ->pluck('qty', 'date');

        $saleByDate = DB::table('sale_items')
            ->join('sales', 'sales.id', '=', 'sale_items.sale_id')
            ->whereBetween('sales.sale_date', [$from, $to])
            ->selectRaw('sales.sale_date as date, SUM(sale_items.quantity) as qty')
            ->groupBy('sales.sale_date')
            ->pluck('qty', 'date');

        $salesByDate = Sale::query()
            ->whereBetween('sale_date', [$from, $to])
            ->selectRaw('sale_date as date, SUM(grand_total) as total')
            ->groupBy('sale_date')
            ->pluck('total', 'date');

        $stockMovement = [];
        $salesOverview = [];
        $cursor = Carbon::parse($from);
        $end = Carbon::parse($to);
        while ($cursor->lte($end)) {
            $date = $cursor->toDateString();
            $stockMovement[] = [
                'date' => $date,
                'purchase_qty' => (int) ($purchaseByDate[$date] ?? 0),
                'sale_qty' => (int) ($saleByDate[$date] ?? 0),
            ];
            $salesOverview[] = [
                'date' => $date,
                'total' => (float) ($salesByDate[$date] ?? 0),
            ];
            $cursor->addDay();
        }

        $topSellingProducts = DB::table('sale_items')
            ->join('sales', 'sales.id', '=', 'sale_items.sale_id')
            ->join('products', 'products.id', '=', 'sale_items.product_id')
            ->whereBetween('sales.sale_date', [$from, $to])
            ->selectRaw('products.name as name, SUM(sale_items.quantity) as qty_sold')
            ->groupBy('products.id', 'products.name')
            ->orderByDesc('qty_sold')
            ->limit(5)
            ->get()
            ->map(fn ($row) => ['name' => $row->name, 'qty_sold' => (int) $row->qty_sold]);

        $lowStockProducts = Product::query()
            ->whereColumn('current_stock', '<=', 'minimum_stock')
            ->orderBy('current_stock')
            ->limit(10)
            ->get(['id', 'name', 'sku', 'current_stock', 'minimum_stock']);

        $recentPurchases = Purchase::query()
            ->with('creator:id,name')
            ->orderByDesc('created_at')
            ->limit(5)
            ->get(['id', 'reference_no', 'purchase_date', 'supplier_name', 'grand_total', 'created_by']);

        $recentSales = Sale::query()
            ->with('customer:id,name')
            ->orderByDesc('created_at')
            ->limit(5)
            ->get(['id', 'reference_no', 'sale_date', 'customer_id', 'grand_total']);

        return $this->success([
            'range' => ['from' => $from, 'to' => $to],
            'cards' => $cards,
            'stock_movement' => $stockMovement,
            'sales_overview' => $salesOverview,
            'top_selling_products' => $topSellingProducts,
            'low_stock_products' => $lowStockProducts,
            'recent_purchases' => $recentPurchases->map(fn ($s) => [
                'id' => $s->id,
                'reference_no' => $s->reference_no,
                'purchase_date' => $s->purchase_date,
                'supplier_name' => $s->supplier_name,
                'grand_total' => (float) $s->grand_total,
                'created_by' => $s->creator?->name,
            ]),
            'recent_sales' => $recentSales->map(fn ($s) => [
                'id' => $s->id,
                'reference_no' => $s->reference_no,
                'sale_date' => $s->sale_date,
                'customer_name' => $s->customer?->name,
                'grand_total' => (float) $s->grand_total,
            ]),
        ]);
    }

    private function resolveRange(string $range, ?string $customFrom, ?string $customTo): array
    {
        $now = now();

        return match ($range) {
            'today' => [$now->toDateString(), $now->toDateString()],
            'week' => [$now->copy()->startOfWeek()->toDateString(), $now->toDateString()],
            'year' => [$now->copy()->startOfYear()->toDateString(), $now->toDateString()],
            'custom' => [$customFrom ?: $now->copy()->startOfMonth()->toDateString(), $customTo ?: $now->toDateString()],
            default => [$now->copy()->startOfMonth()->toDateString(), $now->toDateString()],
        };
    }
}
