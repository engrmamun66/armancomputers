<?php

namespace Database\Seeders;

use App\Models\Product;
use Illuminate\Database\Seeder;

class ProductSeeder extends Seeder
{
    public function run(): void
    {
        if (Product::query()->count() === 0) {
            Product::factory()->count(24)->create();
        }
    }
}
