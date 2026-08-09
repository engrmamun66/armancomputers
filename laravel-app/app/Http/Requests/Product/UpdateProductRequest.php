<?php

namespace App\Http\Requests\Product;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdateProductRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    protected function prepareForValidation(): void
    {
        $data = [];
        if ($this->has('sku')) {
            $data['sku'] = $this->sku !== null && $this->sku !== '' ? $this->sku : null;
        }
        if ($this->has('barcode')) {
            $data['barcode'] = $this->barcode !== null && $this->barcode !== '' ? $this->barcode : null;
        }
        if ($data) {
            $this->merge($data);
        }
    }

    public function rules(): array
    {
        return [
            'brand_id' => ['sometimes', 'required', 'integer', 'exists:brands,id'],
            'name' => ['sometimes', 'required', 'string', 'max:255'],
            'sku' => ['sometimes', 'nullable', 'string', 'max:100', Rule::unique('products', 'sku')->ignore($this->route('product'))],
            'barcode' => ['sometimes', 'nullable', 'string', 'max:100', Rule::unique('products', 'barcode')->ignore($this->route('product'))],
            'description' => ['sometimes', 'nullable', 'string'],
            'purchase_price' => ['sometimes', 'required', 'numeric', 'min:0'],
            'selling_price' => ['sometimes', 'required', 'numeric', 'min:0'],
            'minimum_stock' => ['sometimes', 'required', 'integer', 'min:0'],
            'status_id' => ['sometimes', 'required', 'integer', 'exists:statuses,id'],
        ];
    }
}
