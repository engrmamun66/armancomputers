<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Status extends Model
{
    public const TYPE_GENERAL = 'general';
    public const TYPE_STOCK_IN = 'stock_in';
    public const TYPE_STOCK_OUT = 'stock_out';
    public const TYPE_INVOICE = 'invoice';

    protected $fillable = ['name', 'slug', 'type'];

    public function scopeOfType($query, string $type)
    {
        return $query->where('type', $type);
    }

    public static function id(string $type, string $slug): int
    {
        return static::query()->where('type', $type)->where('slug', $slug)->value('id');
    }
}
