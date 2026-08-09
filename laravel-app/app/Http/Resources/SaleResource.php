<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin \App\Models\Sale */
class SaleResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'reference_no' => $this->reference_no,
            'customer' => $this->customer ? [
                'id' => $this->customer->id,
                'name' => $this->customer->name,
                'phone' => $this->customer->phone,
            ] : null,
            'sale_date' => $this->sale_date,
            'warranty_end_date' => $this->warranty_end_date,
            'subtotal' => (float) $this->subtotal,
            'discount' => (float) $this->discount,
            'additional_cost' => (float) $this->additional_cost,
            'grand_total' => (float) $this->grand_total,
            'paid_amount' => (float) $this->paid_amount,
            'due_amount' => (float) $this->due_amount,
            'payment_method' => $this->payment_method,
            'payment_status' => $this->payment_status,
            'notes' => $this->notes,
            'status' => $this->status ? new StatusResource($this->status) : null,
            'created_by' => $this->creator?->name,
            'invoice_id' => $this->when($this->relationLoaded('invoice'), fn () => $this->invoice?->id),
            'items_count' => $this->when(isset($this->items_count), fn () => (int) $this->items_count),
            'total_qty' => $this->when(isset($this->total_qty), fn () => (int) ($this->total_qty ?? 0)),
            'items' => SaleItemResource::collection($this->whenLoaded('items')),
            'created_at' => $this->created_at,
        ];
    }
}
