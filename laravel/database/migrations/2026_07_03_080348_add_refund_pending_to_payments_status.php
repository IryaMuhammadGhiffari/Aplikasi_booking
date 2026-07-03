<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        // PostgreSQL: tambah value ke enum
        DB::statement("ALTER TYPE payments_status ADD VALUE 'refund_pending'");
    }

    public function down(): void
    {
        // PostgreSQL nggak support DROP VALUE dari enum, biarkan kosong
    }
};
