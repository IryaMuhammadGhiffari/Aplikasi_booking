<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        // 1. Hapus constraint lama kalau ada (idempotent)
        DB::statement("ALTER TABLE payments DROP CONSTRAINT IF EXISTS payments_status_check");

        // 2. Ubah kolom status dari enum ke varchar (idempotent - aman dijalankan berulang)
        DB::statement("ALTER TABLE payments ALTER COLUMN status TYPE varchar(255) USING status::varchar");

        // 3. Tambah check constraint baru dengan nilai lengkap
        DB::statement("
            ALTER TABLE payments 
            ADD CONSTRAINT payments_status_check 
            CHECK (status IN ('pending', 'paid', 'failed', 'expired', 'refunded', 'refund_pending'))
        ");
    }

    public function down(): void
    {
        DB::statement("ALTER TABLE payments DROP CONSTRAINT IF EXISTS payments_status_check");
        
        DB::statement("
            ALTER TABLE payments 
            ALTER COLUMN status TYPE payments_status 
            USING status::payments_status
        ");
    }
};
