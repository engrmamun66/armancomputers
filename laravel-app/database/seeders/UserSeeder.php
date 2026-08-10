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
            // Super admin (full access)
            ['name' => 'Arman Admin', 'email' => 'admin@armancomputers.com', 'role' => Role::ADMIN, 'password' => 'AdminAC!2026#Xk9'],
            ['name' => 'Manager User', 'email' => 'manager@armancomputers.com', 'role' => Role::MANAGER, 'password' => 'ManagerAC!2026#Qz4'],
        ];

        foreach ($users as $user) {
            User::query()->updateOrCreate(
                ['email' => $user['email']],
                [
                    'name' => $user['name'],
                    'password' => Hash::make($user['password']),
                    'role_id' => $roleIds[$user['role']],
                    'status_id' => $activeStatusId,
                    'email_verified_at' => now(),
                ]
            );
        }

        // Staff role retired — remove the seeded staff account with it.
        User::query()->where('email', 'staff1@armancomputers.com')->delete();
    }
}
