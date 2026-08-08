<?php

namespace Database\Seeders;

use App\Models\Brand;
use App\Models\Status;
use Illuminate\Database\Seeder;
use Illuminate\Support\Str;

class BrandSeeder extends Seeder
{
    public function run(): void
    {
        $activeStatusId = Status::id(Status::TYPE_GENERAL, 'active');

        $brands = ['Dell', 'HP', 'Lenovo', 'Asus', 'Apple', 'Logitech', 'Samsung', 'Canon'];

        foreach ($brands as $name) {
            Brand::query()->updateOrCreate(
                ['slug' => Str::slug($name)],
                [
                    'name' => $name,
                    'description' => "{$name} computers and accessories.",
                    'status_id' => $activeStatusId,
                ]
            );
        }
    }
}
