<?php

namespace Database\Seeders;

use App\Models\Customer;
use Illuminate\Database\Seeder;

class CustomerSeeder extends Seeder
{
    public function run(): void
    {
        if (Customer::query()->count() === 0) {
            Customer::factory()->count(10)->create();
        }
    }
}
