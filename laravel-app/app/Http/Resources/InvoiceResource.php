<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin \App\Models\Invoice */
class InvoiceResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'invoice_number' => $this->invoice_number,
            'sale_id' => $this->sale_id,
            'customer' => $this->customer ? [
                'id' => $this->customer->id,
                'name' => $this->customer->name,
                'phone' => $this->customer->phone,
                'email' => $this->customer->email,
                'address' => $this->customer->address,
            ] : null,
            'invoice_date' => $this->invoice_date,
            'sale_date' => $this->sale?->sale_date,
            'warranty_end_date' => $this->sale?->warranty_end_date,
            'subtotal' => (float) $this->subtotal,
            'discount' => (float) $this->discount,
            'additional_cost' => (float) $this->additional_cost,
            'grand_total' => (float) $this->grand_total,
            'paid_amount' => (float) $this->paid_amount,
            'due_amount' => (float) $this->due_amount,
            'payment_status' => $this->payment_status,
            'status' => $this->status ? new StatusResource($this->status) : null,
            'created_by' => $this->creator?->name,
            'items' => InvoiceItemResource::collection($this->whenLoaded('items')),
            'created_at' => $this->created_at,
        ];
    }
}
