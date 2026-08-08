<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\StatusResource;
use App\Models\Status;
use Illuminate\Http\Request;

class StatusController extends Controller
{
    public function index(Request $request)
    {
        $statuses = Status::query()
            ->when($request->filled('type'), fn ($query) => $query->ofType($request->string('type')))
            ->orderBy('id')
            ->get();

        return $this->success(StatusResource::collection($statuses));
    }
}
