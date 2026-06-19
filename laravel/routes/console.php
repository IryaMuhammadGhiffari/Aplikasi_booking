<?php

use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\DB;
use App\Models\Booking;

Artisan::command('inspire', function () {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote');

Artisan::command('bookings:auto-cancel', function () {
    $count = Booking::whereIn('status', ['pending', 'confirmed'])
        ->where('booking_date', '<', now()->toDateString())
        ->orWhere(function ($q) {
            $q->where('booking_date', '=', now()->toDateString())
              ->where('booking_time', '<', now()->subHours(2)->format('H:i:s'));
        })
        ->whereIn('status', ['pending', 'confirmed'])
        ->update(['status' => 'cancelled']);

    $this->info("Berhasil cancel $count booking expired.");
    Log::info("Auto-cancel: $count booking expired dibatalkan.");
})->purpose('Cancel expired bookings (lewat tanggal/jam)');
