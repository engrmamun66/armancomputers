<?php

namespace App\Services;

use Illuminate\Support\Facades\DB;

class ReferenceNumberGenerator
{
    /**
     * Generate the next unique reference number for a table/column, e.g. SI-2026-000001.
     *
     * Must be called inside a DB transaction that already holds a lock (or is otherwise
     * serialized) so two concurrent requests can never read the same "last" number.
     */
    public static function generate(string $prefix, string $table, string $column = 'reference_no'): string
    {
        $year = now()->year;
        $like = "{$prefix}-{$year}-%";

        $last = DB::table($table)
            ->where($column, 'like', $like)
            ->lockForUpdate()
            ->orderByDesc($column)
            ->value($column);

        $next = $last ? ((int) substr($last, -4)) + 1 : 1;

        return sprintf('%s-%d-%04d', $prefix, $year, $next);
    }
}
