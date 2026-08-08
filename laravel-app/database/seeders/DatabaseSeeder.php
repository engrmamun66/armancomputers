<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        $this->call([
            RoleSeeder::class,
            StatusSeeder::class,
            UserSeeder::class,
            BrandSeeder::class,
            ProductSeeder::class,
            CustomerSeeder::class,
            StockInSeeder::class,
            StockOutSeeder::class,
        ]);
    }
}
