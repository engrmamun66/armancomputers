<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Concerns\Sortable;
use App\Http\Controllers\Controller;
use App\Http\Resources\InvoiceResource;
use App\Models\Customer;
use App\Models\Invoice;
use Illuminate\Http\Request;

class InvoiceController extends Controller
{
    use Sortable;

    public function index(Request $request)
    {
        $this->authorize('viewAny', Invoice::class);

        $invoices = Invoice::query()
            ->with(['customer', 'status'])
            ->when($request->filled('search'), function ($query) use ($request) {
                $term = "%{$request->string('search')}%";
                $query->where(fn ($q) => $q->where('invoice_number', 'like', $term)
                    ->orWhereHas('customer', fn ($c) => $c->where('name', 'like', $term)));
            })
            ->when($request->filled('customer_id'), fn ($q) => $q->where('customer_id', $request->integer('customer_id')))
            ->when($request->filled('date_from'), fn ($q) => $q->whereDate('invoice_date', '>=', $request->string('date_from')))
            ->when($request->filled('date_to'), fn ($q) => $q->whereDate('invoice_date', '<=', $request->string('date_to')))
            ->when($request->filled('status_id'), fn ($q) => $q->where('status_id', $request->integer('status_id')));

        $this->applySort($invoices, $request, [
            'invoice_number' => 'invoice_number',
            'customer' => fn ($q, $dir) => $q->orderBy(Customer::select('name')->whereColumn('customers.id', 'invoices.customer_id'), $dir),
            'invoice_date' => 'invoice_date',
            'grand_total' => 'grand_total',
            'paid_amount' => 'paid_amount',
            'due_amount' => 'due_amount',
        ], 'invoice_date', 'desc');

        $invoices = $invoices->paginate($request->integer('per_page', 15));

        return InvoiceResource::collection($invoices)->additional(['success' => true, 'message' => '']);
    }

    public function show(Invoice $invoice)
    {
        $this->authorize('view', Invoice::class);

        return $this->success(new InvoiceResource($invoice->load('items.product', 'status', 'creator', 'customer', 'sale')));
    }
}
