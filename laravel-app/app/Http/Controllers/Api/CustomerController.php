<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Concerns\Sortable;
use App\Http\Controllers\Controller;
use App\Http\Requests\Customer\StoreCustomerRequest;
use App\Http\Requests\Customer\UpdateCustomerRequest;
use App\Http\Resources\CustomerResource;
use App\Models\Customer;
use Illuminate\Http\Request;

class CustomerController extends Controller
{
    use Sortable;

    public function index(Request $request)
    {
        $this->authorize('viewAny', Customer::class);

        $customers = Customer::query()
            ->withCount('sales')
            ->withSum('sales as total_paid_amount', 'paid_amount')
            ->withSum('sales as total_due_amount', 'due_amount')
            ->when($request->filled('search'), function ($query) use ($request) {
                $term = "%{$request->string('search')}%";
                $query->where(fn ($q) => $q->where('name', 'like', $term)
                    ->orWhere('phone', 'like', $term)
                    ->orWhere('email', 'like', $term));
            })
            ->when($request->filled('status_id'), fn ($q) => $q->where('status_id', $request->integer('status_id')));

        $this->applySort($customers, $request, [
            'name' => 'name',
            'phone' => 'phone',
            'email' => 'email',
            'total_purchases' => 'sales_count',
            'total_paid' => 'total_paid_amount',
            'total_due' => 'total_due_amount',
            'status' => 'status_id',
        ], 'name');

        $customers = $customers->paginate($request->integer('per_page', 15));

        return CustomerResource::collection($customers)->additional(['success' => true, 'message' => '']);
    }

    public function store(StoreCustomerRequest $request)
    {
        $this->authorize('create', Customer::class);

        $customer = Customer::query()->create($request->validated());

        return $this->success(new CustomerResource($customer), 'Customer created successfully.', 201);
    }

    public function show(Customer $customer)
    {
        $this->authorize('view', Customer::class);

        $customer->loadCount('sales')
            ->loadSum('sales as total_paid_amount', 'paid_amount')
            ->loadSum('sales as total_due_amount', 'due_amount');

        $purchases = $customer->sales()
            ->with('status')
            ->orderByDesc('sale_date')
            ->get()
            ->map(fn ($sale) => [
                'id' => $sale->id,
                'reference_no' => $sale->reference_no,
                'sale_date' => $sale->sale_date,
                'grand_total' => (float) $sale->grand_total,
                'paid_amount' => (float) $sale->paid_amount,
                'due_amount' => (float) $sale->due_amount,
                'payment_status' => $sale->payment_status,
                'status' => $sale->status->slug,
            ]);

        return $this->success([
            'customer' => new CustomerResource($customer),
            'purchases' => $purchases,
        ]);
    }

    public function update(UpdateCustomerRequest $request, Customer $customer)
    {
        $this->authorize('update', Customer::class);

        $customer->update($request->validated());

        return $this->success(new CustomerResource($customer->fresh()), 'Customer updated successfully.');
    }

    public function destroy(Customer $customer)
    {
        $this->authorize('delete', Customer::class);

        $customer->delete();

        return $this->success(null, 'Customer deleted successfully.');
    }
}
