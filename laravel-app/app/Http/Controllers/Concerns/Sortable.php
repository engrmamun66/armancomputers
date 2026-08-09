<?php

namespace App\Http\Controllers\Concerns;

use Closure;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\Request;

trait Sortable
{
    /**
     * Apply a whitelisted sort to the query. $sortMap maps a public sort key
     * (matching the frontend column key) to either a real/aliased column
     * name, or a Closure($query, $direction) for relation-based columns.
     */
    protected function applySort(Builder $query, Request $request, array $sortMap, string $defaultKey, string $defaultDir = 'asc'): Builder
    {
        $requestedKey = $request->string('sort_by')->value();
        $key = array_key_exists($requestedKey, $sortMap) ? $requestedKey : $defaultKey;

        $requestedDir = $request->string('sort_dir')->value();
        $dir = in_array($requestedDir, ['asc', 'desc'], true) ? $requestedDir : $defaultDir;

        $column = $sortMap[$key];

        if ($column instanceof Closure) {
            $column($query, $dir);
        } else {
            $query->orderBy($column, $dir);
        }

        return $query;
    }
}
