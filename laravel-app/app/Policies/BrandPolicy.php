<?php

namespace App\Policies;

use App\Models\User;

class BrandPolicy
{
    public function viewAny(User $user): bool
    {
        return $user->isAdmin() || $user->isManager();
    }

    public function create(User $user): bool
    {
        return $user->isAdmin() || $user->isManager();
    }

    public function update(User $user): bool
    {
        return $user->isAdmin() || $user->isManager();
    }

    public function delete(User $user): bool
    {
        return $user->isAdmin() || $user->isManager();
    }
}
