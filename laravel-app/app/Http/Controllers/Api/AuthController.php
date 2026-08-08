<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Auth\LoginRequest;
use App\Http\Resources\UserResource;
use Illuminate\Support\Facades\Auth;
use Tymon\JWTAuth\Facades\JWTAuth;

class AuthController extends Controller
{
    public function login(LoginRequest $request)
    {
        $credentials = $request->validated();

        if (! $token = Auth::guard('api')->attempt($credentials)) {
            return $this->error('Invalid email or password.', null, 401);
        }

        $user = Auth::guard('api')->user();
        $user->forceFill(['last_login_at' => now()])->save();
        $user->load('role', 'status');

        return $this->success([
            'token' => $token,
            'token_type' => 'bearer',
            'expires_in' => JWTAuth::factory()->getTTL() * 60,
            'user' => new UserResource($user),
        ], 'Login successful.');
    }

    public function me()
    {
        $user = Auth::guard('api')->user()->load('role', 'status');

        return $this->success(new UserResource($user));
    }

    public function logout()
    {
        Auth::guard('api')->logout();

        return $this->success(null, 'Logged out successfully.');
    }

    public function refresh()
    {
        $token = Auth::guard('api')->refresh();

        return $this->success([
            'token' => $token,
            'token_type' => 'bearer',
            'expires_in' => JWTAuth::factory()->getTTL() * 60,
        ], 'Token refreshed.');
    }
}
