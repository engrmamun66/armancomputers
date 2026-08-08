<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->foreignId('role_id')->nullable()->after('id')->constrained('roles')->nullOnDelete();
            $table->foreignId('status_id')->nullable()->after('role_id')->constrained('statuses')->nullOnDelete();
            $table->string('avatar')->nullable()->after('password');
            $table->timestamp('last_login_at')->nullable()->after('avatar');
            $table->softDeletes();
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropForeign(['role_id']);
            $table->dropForeign(['status_id']);
            $table->dropColumn(['role_id', 'status_id', 'avatar', 'last_login_at', 'deleted_at']);
        });
    }
};
