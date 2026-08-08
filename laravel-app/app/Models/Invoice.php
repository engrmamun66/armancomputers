<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Invoice extends Model
{
    use HasFactory;

    protected $fillable = [
        'invoice_number',
        'stock_out_id',
        'customer_id',
        'invoice_date',
        'subtotal',
        'discount',
        'additional_cost',
        'grand_total',
        'paid_amount',
        'due_amount',
        'status_id',
        'created_by',
    ];

    protected function casts(): array
    {
        return [
            'invoice_date' => 'date',
            'subtotal' => 'decimal:2',
            'discount' => 'decimal:2',
            'additional_cost' => 'decimal:2',
            'grand_total' => 'decimal:2',
            'paid_amount' => 'decimal:2',
            'due_amount' => 'decimal:2',
        ];
    }

    public function stockOut(): BelongsTo
    {
        return $this->belongsTo(StockOut::class);
    }

    public function customer(): BelongsTo
    {
        return $this->belongsTo(Customer::class)->withTrashed();
    }

    public function status(): BelongsTo
    {
        return $this->belongsTo(Status::class);
    }

    public function creator(): BelongsTo
    {
        return $this->belongsTo(User::class, 'created_by')->withTrashed();
    }

    public function items(): HasMany
    {
        return $this->hasMany(InvoiceItem::class);
    }

    public function getPaymentStatusAttribute(): string
    {
        if ((float) $this->due_amount <= 0) {
            return 'paid';
        }

        if ((float) $this->paid_amount > 0) {
            return 'partial';
        }

        return 'due';
    }
}
