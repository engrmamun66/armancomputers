<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Concerns\Sortable;
use App\Http\Controllers\Controller;
use App\Http\Requests\User\ResetPasswordRequest;
use App\Http\Requests\User\StoreUserRequest;
use App\Http\Requests\User\UpdateUserRequest;
use App\Http\Resources\UserResource;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;

class UserController extends Controller
{
    use Sortable;

    public function index(Request $request)
    {
        $this->authorize('viewAny', User::class);

        $users = User::query()
            ->with(['role', 'status'])
            ->when($request->filled('search'), function ($query) use ($request) {
                $term = "%{$request->string('search')}%";
                $query->where(fn ($q) => $q->where('name', 'like', $term)->orWhere('email', 'like', $term));
            })
            ->when($request->filled('role_id'), fn ($query) => $query->where('role_id', $request->integer('role_id')))
            ->when($request->filled('status_id'), fn ($query) => $query->where('status_id', $request->integer('status_id')));

        $this->applySort($users, $request, [
            'name' => 'name',
            'email' => 'email',
            'role' => 'role_id',
            'status' => 'status_id',
            'last_login_at' => 'last_login_at',
            'created_at' => 'created_at',
        ], 'created_at', 'desc');

        $users = $users->paginate($request->integer('per_page', 15));

        return UserResource::collection($users)->additional(['success' => true, 'message' => '']);
    }

    public function store(StoreUserRequest $request)
    {
        $this->authorize('create', User::class);

        $user = User::query()->create([
            ...$request->validated(),
            'password' => Hash::make($request->validated('password')),
        ]);

        return $this->success(new UserResource($user->load('role', 'status')), 'User created successfully.', 201);
    }

    public function show(User $user)
    {
        $this->authorize('view', User::class);

        return $this->success(new UserResource($user->load('role', 'status')));
    }

    public function update(UpdateUserRequest $request, User $user)
    {
        $this->authorize('update', User::class);

        $user->update($request->validated());

        return $this->success(new UserResource($user->fresh(['role', 'status'])), 'User updated successfully.');
    }

    public function destroy(User $user)
    {
        $this->authorize('delete', [User::class, $user]);

        $user->delete();

        return $this->success(null, 'User deleted successfully.');
    }

    public function resetPassword(ResetPasswordRequest $request, User $user)
    {
        $this->authorize('update', User::class);

        $user->update(['password' => Hash::make($request->validated('password'))]);

        return $this->success(null, 'Password reset successfully.');
    }
}
