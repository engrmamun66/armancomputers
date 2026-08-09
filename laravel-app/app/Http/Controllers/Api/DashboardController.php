<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Customer;
use App\Models\Product;
use App\Models\StockIn;
use App\Models\StockOut;
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
            'total_stock_in' => StockIn::whereBetween('purchase_date', [$from, $to])->count(),
            'total_stock_out' => StockOut::whereBetween('sale_date', [$from, $to])->count(),
            'todays_sales' => (float) StockOut::whereDate('sale_date', $today)->sum('grand_total'),
            'todays_stock_in' => (float) StockIn::whereDate('purchase_date', $today)->sum('grand_total'),
            'total_customers' => Customer::count(),
            'low_stock_products' => Product::whereColumn('current_stock', '<=', 'minimum_stock')->where('current_stock', '>', 0)->count(),
            'out_of_stock_products' => Product::where('current_stock', '<=', 0)->count(),
        ];

        $stockInByDate = DB::table('stock_in_items')
            ->join('stock_ins', 'stock_ins.id', '=', 'stock_in_items.stock_in_id')
            ->whereBetween('stock_ins.purchase_date', [$from, $to])
            ->selectRaw('stock_ins.purchase_date as date, SUM(stock_in_items.quantity) as qty')
            ->groupBy('stock_ins.purchase_date')
            ->pluck('qty', 'date');

        $stockOutByDate = DB::table('stock_out_items')
            ->join('stock_outs', 'stock_outs.id', '=', 'stock_out_items.stock_out_id')
            ->whereBetween('stock_outs.sale_date', [$from, $to])
            ->selectRaw('stock_outs.sale_date as date, SUM(stock_out_items.quantity) as qty')
            ->groupBy('stock_outs.sale_date')
            ->pluck('qty', 'date');

        $salesByDate = StockOut::query()
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
                'stock_in_qty' => (int) ($stockInByDate[$date] ?? 0),
                'stock_out_qty' => (int) ($stockOutByDate[$date] ?? 0),
            ];
            $salesOverview[] = [
                'date' => $date,
                'total' => (float) ($salesByDate[$date] ?? 0),
            ];
            $cursor->addDay();
        }

        $topSellingProducts = DB::table('stock_out_items')
            ->join('stock_outs', 'stock_outs.id', '=', 'stock_out_items.stock_out_id')
            ->join('products', 'products.id', '=', 'stock_out_items.product_id')
            ->whereBetween('stock_outs.sale_date', [$from, $to])
            ->selectRaw('products.name as name, SUM(stock_out_items.quantity) as qty_sold')
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

        $recentStockIns = StockIn::query()
            ->with('creator:id,name')
            ->orderByDesc('created_at')
            ->limit(5)
            ->get(['id', 'reference_no', 'purchase_date', 'supplier_name', 'grand_total', 'created_by']);

        $recentStockOuts = StockOut::query()
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
            'recent_stock_ins' => $recentStockIns->map(fn ($s) => [
                'id' => $s->id,
                'reference_no' => $s->reference_no,
                'purchase_date' => $s->purchase_date,
                'supplier_name' => $s->supplier_name,
                'grand_total' => (float) $s->grand_total,
                'created_by' => $s->creator?->name,
            ]),
            'recent_stock_outs' => $recentStockOuts->map(fn ($s) => [
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
