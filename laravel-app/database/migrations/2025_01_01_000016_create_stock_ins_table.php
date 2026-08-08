<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('stock_ins', function (Blueprint $table) {
            $table->id();
            $table->string('reference_no')->unique();
            $table->string('supplier_name')->nullable();
            $table->string('supplier_phone')->nullable();
            $table->date('purchase_date');
            $table->decimal('subtotal', 14, 2)->default(0);
            $table->decimal('discount', 14, 2)->default(0);
            $table->decimal('additional_cost', 14, 2)->default(0);
            $table->decimal('grand_total', 14, 2)->default(0);
            $table->text('notes')->nullable();
            $table->foreignId('status_id')->constrained('statuses');
            $table->foreignId('created_by')->constrained('users');
            $table->softDeletes();
            $table->timestamps();

            $table->index('purchase_date');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('stock_ins');
    }
};
