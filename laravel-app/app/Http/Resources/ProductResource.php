<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin \App\Models\Product */
class ProductResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'brand' => $this->brand ? new BrandResource($this->brand) : null,
            'name' => $this->name,
            'sku' => $this->sku,
            'barcode' => $this->barcode,
            'description' => $this->description,
            'purchase_price' => (float) $this->purchase_price,
            'selling_price' => (float) $this->selling_price,
            'current_stock' => $this->current_stock,
            'minimum_stock' => $this->minimum_stock,
            'stock_state' => $this->stock_state,
            'status' => $this->status ? new StatusResource($this->status) : null,
            'created_at' => $this->created_at,
        ];
    }
}
