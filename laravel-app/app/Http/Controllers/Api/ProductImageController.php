<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\ProductImageResource;
use App\Models\Product;
use App\Models\ProductImage;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

class ProductImageController extends Controller
{
    public function store(Request $request, Product $product)
    {
        $this->authorize('update', $product);

        $request->validate([
            'image' => ['required', 'image', 'max:4096'],
            'is_default' => ['nullable', 'boolean'],
        ]);

        $makeDefault = $request->boolean('is_default') || $product->images()->count() === 0;

        if ($makeDefault) {
            $product->images()->update(['is_default' => false]);
        }

        $path = $request->file('image')->store('products', 'public');

        $image = $product->images()->create([
            'image' => $path,
            'is_default' => $makeDefault,
        ]);

        return $this->success(new ProductImageResource($image), 'Image uploaded successfully.', 201);
    }

    public function destroy(Product $product, ProductImage $image)
    {
        $this->authorize('update', $product);
        abort_if($image->product_id !== $product->id, 404);

        Storage::disk('public')->delete($image->image);
        $wasDefault = $image->is_default;
        $image->delete();

        if ($wasDefault) {
            $next = $product->images()->first();
            $next?->update(['is_default' => true]);
        }

        return $this->success(null, 'Image deleted successfully.');
    }

    public function setDefault(Product $product, ProductImage $image)
    {
        $this->authorize('update', $product);
        abort_if($image->product_id !== $product->id, 404);

        $product->images()->update(['is_default' => false]);
        $image->update(['is_default' => true]);

        return $this->success(null, 'Default image updated.');
    }
}
