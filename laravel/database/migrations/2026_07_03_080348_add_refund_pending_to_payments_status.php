<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    // PostgreSQL: ALTER TYPE ... ADD VALUE tidak boleh di dalam transaksi
    protected $withinTransaction = false;

    public function up(): void
    {
        DB::statement("ALTER TYPE payments_status ADD VALUE 'refund_pending'");
    }

    public function down(): void
    {
        // PostgreSQL nggak support DROP VALUE dari enum, biarkan kosong
    }
};
