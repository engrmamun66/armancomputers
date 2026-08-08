<?php

namespace Database\Factories;

use App\Models\Brand;
use App\Models\Status;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<\App\Models\Product>
 */
class ProductFactory extends Factory
{
    private static array $names = [
        'Laptop 14"', 'Laptop 15.6"', 'Desktop Tower', 'All-in-One PC', 'Monitor 24"',
        'Monitor 27"', 'Wireless Mouse', 'Wireless Keyboard', 'Mechanical Keyboard',
        'USB-C Hub', 'External SSD 1TB', 'External HDD 2TB', 'Webcam HD', 'Headset',
        'Bluetooth Speaker', 'Printer', 'Router', 'Graphics Card', 'RAM 16GB',
        'RAM 8GB', 'Power Bank', 'Laptop Bag', 'UPS 650VA', 'Docking Station',
    ];

    public function definition(): array
    {
        $name = $this->faker->unique()->randomElement(self::$names);
        $purchase = $this->faker->numberBetween(800, 60000);
        $margin = $this->faker->numberBetween(10, 25) / 100;

        return [
            'brand_id' => Brand::query()->inRandomOrder()->value('id'),
            'name' => $name,
            'sku' => 'SKU-' . strtoupper($this->faker->unique()->bothify('??###')),
            'barcode' => $this->faker->unique()->ean13(),
            'description' => "{$name} — reliable, ready for everyday use.",
            'purchase_price' => $purchase,
            'selling_price' => round($purchase * (1 + $margin), 2),
            'current_stock' => 0,
            'minimum_stock' => $this->faker->numberBetween(3, 10),
            'status_id' => Status::id(Status::TYPE_GENERAL, 'active'),
        ];
    }
}
