<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin \App\Models\Customer */
class CustomerResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'phone' => $this->phone,
            'email' => $this->email,
            'address' => $this->address,
            'status' => $this->status ? new StatusResource($this->status) : null,
            'total_purchases' => $this->when(isset($this->stock_outs_count), fn () => (int) $this->stock_outs_count),
            'total_paid' => $this->when(isset($this->total_paid_amount), fn () => (float) ($this->total_paid_amount ?? 0)),
            'total_due' => $this->when(isset($this->total_due_amount), fn () => (float) ($this->total_due_amount ?? 0)),
            'created_at' => $this->created_at,
        ];
    }
}
