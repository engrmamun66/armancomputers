<?php

namespace Database\Seeders;

use App\Models\Status;
use Illuminate\Database\Seeder;

class StatusSeeder extends Seeder
{
    public function run(): void
    {
        $statuses = [
            ['type' => Status::TYPE_GENERAL, 'slug' => 'active', 'name' => 'Active'],
            ['type' => Status::TYPE_GENERAL, 'slug' => 'inactive', 'name' => 'Inactive'],

            ['type' => Status::TYPE_STOCK_IN, 'slug' => 'completed', 'name' => 'Completed'],
            ['type' => Status::TYPE_STOCK_IN, 'slug' => 'cancelled', 'name' => 'Cancelled'],

            ['type' => Status::TYPE_STOCK_OUT, 'slug' => 'completed', 'name' => 'Completed'],
            ['type' => Status::TYPE_STOCK_OUT, 'slug' => 'cancelled', 'name' => 'Cancelled'],

            ['type' => Status::TYPE_INVOICE, 'slug' => 'issued', 'name' => 'Issued'],
            ['type' => Status::TYPE_INVOICE, 'slug' => 'cancelled', 'name' => 'Cancelled'],
        ];

        foreach ($statuses as $status) {
            Status::query()->updateOrCreate(
                ['type' => $status['type'], 'slug' => $status['slug']],
                $status
            );
        }
    }
}
