<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin \App\Models\User */
class UserResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'email' => $this->email,
            'avatar' => $this->avatar,
            'last_login_at' => $this->last_login_at,
            'created_at' => $this->created_at,
            'role' => $this->role ? new RoleResource($this->role) : null,
            'status' => $this->status ? new StatusResource($this->status) : null,
        ];
    }
}
