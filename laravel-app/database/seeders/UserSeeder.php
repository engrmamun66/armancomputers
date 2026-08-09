<?php

namespace Database\Seeders;

use App\Models\Role;
use App\Models\Status;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class UserSeeder extends Seeder
{
    public function run(): void
    {
        $activeStatusId = Status::id(Status::TYPE_GENERAL, 'active');
        $roleIds = Role::query()->pluck('id', 'slug');

        $users = [
            ['name' => 'Arman Admin', 'email' => 'admin@armancomputers.com', 'role' => Role::ADMIN],
            ['name' => 'Manager User', 'email' => 'manager@armancomputers.com', 'role' => Role::MANAGER],
            ['name' => 'Staff One', 'email' => 'staff1@armancomputers.com', 'role' => Role::STAFF],
        ];

        foreach ($users as $user) {
            User::query()->updateOrCreate(
                ['email' => $user['email']],
                [
                    'name' => $user['name'],
                    'password' => Hash::make('password'),
                    'role_id' => $roleIds[$user['role']],
                    'status_id' => $activeStatusId,
                    'email_verified_at' => now(),
                ]
            );
        }
    }
}
