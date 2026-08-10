<?php

namespace Database\Seeders;

use App\Models\Role;
use Illuminate\Database\Seeder;

class RoleSeeder extends Seeder
{
    public function run(): void
    {
        $roles = [
            ['name' => 'Admin', 'slug' => Role::ADMIN],
            ['name' => 'Manager', 'slug' => Role::MANAGER],
        ];

        foreach ($roles as $role) {
            Role::query()->updateOrCreate(['slug' => $role['slug']], $role);
        }

        // Retired role — nullOnDelete() on users.role_id means this can't orphan a foreign key.
        Role::query()->where('slug', 'staff')->delete();
    }
}
