<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\RoleResource;
use App\Models\Role;

class RoleController extends Controller
{
    public function index()
    {
        return $this->success(RoleResource::collection(Role::query()->orderBy('id')->get()));
    }
}
