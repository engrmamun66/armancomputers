<?php

namespace Tests\Feature\Auth;

use App\Models\Role;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\Support\SeedsCore;
use Tests\TestCase;

class AuthenticationTest extends TestCase
{
    use RefreshDatabase, SeedsCore;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seedLookups();
    }

    public function test_user_can_login_with_valid_credentials(): void
    {
        $user = $this->makeUser(Role::ADMIN);
        $user->forceFill(['password' => Hash::make('password123')])->save();

        $response = $this->postJson('/api/auth/login', [
            'email' => $user->email,
            'password' => 'password123',
        ]);

        $response->assertOk()
            ->assertJsonPath('success', true)
            ->assertJsonStructure(['data' => ['token', 'token_type', 'expires_in', 'user' => ['id', 'email', 'role']]]);
    }

    public function test_login_fails_with_invalid_credentials(): void
    {
        $user = $this->makeUser(Role::ADMIN);
        $user->forceFill(['password' => Hash::make('password123')])->save();

        $response = $this->postJson('/api/auth/login', [
            'email' => $user->email,
            'password' => 'wrong-password',
        ]);

        $response->assertStatus(401)->assertJsonPath('success', false);
    }

    public function test_login_requires_email_and_password(): void
    {
        $response = $this->postJson('/api/auth/login', []);

        $response->assertStatus(422)
            ->assertJsonPath('success', false)
            ->assertJsonValidationErrors(['email', 'password']);
    }

    public function test_protected_route_requires_authentication(): void
    {
        $response = $this->getJson('/api/auth/me');

        $response->assertStatus(401)->assertJsonPath('success', false);
    }

    public function test_authenticated_user_can_access_protected_route(): void
    {
        $user = $this->makeUser(Role::ADMIN);

        $response = $this->actingAs($user, 'api')->getJson('/api/auth/me');

        $response->assertOk()->assertJsonPath('data.id', $user->id);
    }

    public function test_user_can_logout_and_token_is_invalidated(): void
    {
        $user = $this->makeUser(Role::ADMIN);
        $user->forceFill(['password' => Hash::make('password123')])->save();

        $login = $this->postJson('/api/auth/login', [
            'email' => $user->email,
            'password' => 'password123',
        ]);
        $token = $login->json('data.token');

        $this->withHeader('Authorization', "Bearer {$token}")
            ->postJson('/api/auth/logout')
            ->assertOk()
            ->assertJsonPath('success', true);

        $this->withHeader('Authorization', "Bearer {$token}")
            ->getJson('/api/auth/me')
            ->assertStatus(401);
    }
}
