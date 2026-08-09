<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin \App\Models\StockIn */
class StockInResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'reference_no' => $this->reference_no,
            'supplier_name' => $this->supplier_name,
            'supplier_phone' => $this->supplier_phone,
            'purchase_date' => $this->purchase_date,
            'subtotal' => (float) $this->subtotal,
            'discount' => (float) $this->discount,
            'additional_cost' => (float) $this->additional_cost,
            'grand_total' => (float) $this->grand_total,
            'notes' => $this->notes,
            'status' => $this->status ? new StatusResource($this->status) : null,
            'created_by' => $this->creator?->name,
            'items_count' => $this->when(isset($this->items_count), fn () => (int) $this->items_count),
            'total_qty' => $this->when(isset($this->total_qty), fn () => (int) ($this->total_qty ?? 0)),
            'items' => StockInItemResource::collection($this->whenLoaded('items')),
            'created_at' => $this->created_at,
        ];
    }
}
