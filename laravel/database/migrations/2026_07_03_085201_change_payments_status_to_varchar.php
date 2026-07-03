<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        // 1. Hapus constraint enum lama (PostgreSQL)
        DB::statement("ALTER TABLE payments ALTER COLUMN status TYPE varchar(255) USING status::varchar");

        // 2. Tambah check constraint untuk validasi nilai
        DB::statement("
            ALTER TABLE payments 
            ADD CONSTRAINT payments_status_check 
            CHECK (status IN ('pending', 'paid', 'failed', 'expired', 'refunded', 'refund_pending'))
        ");
    }

    public function down(): void
    {
        // Hapus check constraint
        DB::statement("ALTER TABLE payments DROP CONSTRAINT IF EXISTS payments_status_check");
        
        // Kembalikan ke enum (butuh cast ulang)
        DB::statement("
            ALTER TABLE payments 
            ALTER COLUMN status TYPE payments_status 
            USING status::payments_status
        ");
    }
};
