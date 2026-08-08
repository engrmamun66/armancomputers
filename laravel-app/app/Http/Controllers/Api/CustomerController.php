<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Customer\StoreCustomerRequest;
use App\Http\Requests\Customer\UpdateCustomerRequest;
use App\Http\Resources\CustomerResource;
use App\Models\Customer;
use Illuminate\Http\Request;

class CustomerController extends Controller
{
    public function index(Request $request)
    {
        $this->authorize('viewAny', Customer::class);

        $customers = Customer::query()
            ->withCount('stockOuts')
            ->withSum('stockOuts as total_paid_amount', 'paid_amount')
            ->withSum('stockOuts as total_due_amount', 'due_amount')
            ->when($request->filled('search'), function ($query) use ($request) {
                $term = "%{$request->string('search')}%";
                $query->where(fn ($q) => $q->where('name', 'like', $term)
                    ->orWhere('phone', 'like', $term)
                    ->orWhere('email', 'like', $term));
            })
            ->when($request->filled('status_id'), fn ($q) => $q->where('status_id', $request->integer('status_id')))
            ->orderBy('name')
            ->paginate($request->integer('per_page', 15));

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

        $customer->loadCount('stockOuts')
            ->loadSum('stockOuts as total_paid_amount', 'paid_amount')
            ->loadSum('stockOuts as total_due_amount', 'due_amount');

        $purchases = $customer->stockOuts()
            ->with('status')
            ->orderByDesc('sale_date')
            ->get()
            ->map(fn ($stockOut) => [
                'id' => $stockOut->id,
                'reference_no' => $stockOut->reference_no,
                'sale_date' => $stockOut->sale_date,
                'grand_total' => (float) $stockOut->grand_total,
                'paid_amount' => (float) $stockOut->paid_amount,
                'due_amount' => (float) $stockOut->due_amount,
                'payment_status' => $stockOut->payment_status,
                'status' => $stockOut->status->slug,
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
