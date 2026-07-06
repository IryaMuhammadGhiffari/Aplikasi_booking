<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Cek apakah kolom snap_token masih ada (backward compat)
        if (Schema::hasColumn('payments', 'snap_token')) {
            Schema::table('payments', function (Blueprint $table) {
                $table->dropColumn(['snap_token', 'snap_url', 'midtrans_response']);
            });
        }

        if (!Schema::hasColumn('payments', 'payment_url')) {
            Schema::table('payments', function (Blueprint $table) {
                $table->string('payment_url', 500)->nullable()->after('status');
            });
        }
    }

    public function down(): void
    {
        Schema::table('payments', function (Blueprint $table) {
            $table->dropColumn('payment_url');
            $table->string('snap_token')->nullable()->after('status');
            $table->string('snap_url')->nullable()->after('snap_token');
            $table->json('midtrans_response')->nullable()->after('payment_method');
        });
    }
};
