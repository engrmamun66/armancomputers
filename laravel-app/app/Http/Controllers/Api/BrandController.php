<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Brand\StoreBrandRequest;
use App\Http\Requests\Brand\UpdateBrandRequest;
use App\Http\Resources\BrandResource;
use App\Models\Brand;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

class BrandController extends Controller
{
    public function index(Request $request)
    {
        $this->authorize('viewAny', Brand::class);

        $brands = Brand::query()
            ->withCount('products')
            ->when($request->filled('search'), fn ($q) => $q->where('name', 'like', "%{$request->string('search')}%"))
            ->when($request->filled('status_id'), fn ($q) => $q->where('status_id', $request->integer('status_id')))
            ->orderBy('name')
            ->paginate($request->integer('per_page', 15));

        return BrandResource::collection($brands)->additional(['success' => true, 'message' => '']);
    }

    public function store(StoreBrandRequest $request)
    {
        $this->authorize('create', Brand::class);

        $brand = Brand::query()->create([
            ...$request->validated(),
            'slug' => $this->uniqueSlug($request->validated('name')),
        ]);

        return $this->success(new BrandResource($brand->loadCount('products')), 'Brand created successfully.', 201);
    }

    public function show(Brand $brand)
    {
        $this->authorize('viewAny', Brand::class);

        return $this->success(new BrandResource($brand->loadCount('products')));
    }

    public function update(UpdateBrandRequest $request, Brand $brand)
    {
        $this->authorize('update', Brand::class);

        $brand->update($request->validated());

        return $this->success(new BrandResource($brand->fresh()->loadCount('products')), 'Brand updated successfully.');
    }

    public function destroy(Brand $brand)
    {
        $this->authorize('delete', Brand::class);

        if ($brand->products()->exists()) {
            return $this->error('Cannot delete a brand that still has products assigned to it.', null, 422);
        }

        $brand->delete();

        return $this->success(null, 'Brand deleted successfully.');
    }

    private function uniqueSlug(string $name): string
    {
        $base = Str::slug($name);
        $slug = $base;
        $suffix = 1;

        while (Brand::withTrashed()->where('slug', $slug)->exists()) {
            $slug = "{$base}-" . ++$suffix;
        }

        return $slug;
    }
}
