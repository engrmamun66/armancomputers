<?php

namespace Tests\Support;

use App\Models\Brand;
use App\Models\Customer;
use App\Models\Product;
use App\Models\Role;
use App\Models\Status;
use App\Models\User;
use Database\Seeders\RoleSeeder;
use Database\Seeders\StatusSeeder;

trait SeedsCore
{
    protected function seedLookups(): void
    {
        $this->seed(RoleSeeder::class);
        $this->seed(StatusSeeder::class);
    }

    protected function makeUser(string $roleSlug = Role::ADMIN): User
    {
        return User::factory()->create([
            'role_id' => Role::query()->where('slug', $roleSlug)->value('id'),
            'status_id' => Status::id(Status::TYPE_GENERAL, 'active'),
        ]);
    }

    protected function makeProduct(array $attributes = []): Product
    {
        $brand = Brand::query()->create([
            'name' => 'Test Brand ' . uniqid(),
            'slug' => 'test-brand-' . uniqid(),
            'status_id' => Status::id(Status::TYPE_GENERAL, 'active'),
        ]);

        return Product::query()->create(array_merge([
            'brand_id' => $brand->id,
            'name' => 'Test Product ' . uniqid(),
            'sku' => 'SKU-' . strtoupper(uniqid()),
            'purchase_price' => 100,
            'selling_price' => 150,
            'current_stock' => 0,
            'minimum_stock' => 5,
            'status_id' => Status::id(Status::TYPE_GENERAL, 'active'),
        ], $attributes));
    }

    protected function makeCustomer(array $attributes = []): Customer
    {
        return Customer::query()->create(array_merge([
            'name' => 'Test Customer ' . uniqid(),
            'status_id' => Status::id(Status::TYPE_GENERAL, 'active'),
        ], $attributes));
    }
}
