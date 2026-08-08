<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('statuses', function (Blueprint $table) {
            $table->id();
            $table->string('name');
            $table->string('slug');
            $table->string('type')->index();
            $table->timestamps();

            $table->unique(['slug', 'type']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('statuses');
    }
};
