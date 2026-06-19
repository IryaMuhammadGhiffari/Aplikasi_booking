<?php

use Illuminate\Support\Facades\Route;
use Illuminate\Support\Facades\Artisan;
use App\Http\Controllers\API\AuthController;
use App\Http\Controllers\API\ServiceController;
use App\Http\Controllers\API\BarberController;
use App\Http\Controllers\API\BookingController;
use App\Http\Controllers\API\PaymentController;

Route::prefix('auth')->group(function () {
    Route::post('register', [AuthController::class, 'register']);
    Route::post('login',    [AuthController::class, 'login']);
});

Route::post('payments/notification', [PaymentController::class, 'notification']);

Route::middleware('auth:sanctum')->group(function () {

    Route::post('auth/logout',  [AuthController::class, 'logout']);
    Route::get('auth/profile',  [AuthController::class, 'profile']);
    Route::put('auth/profile',  [AuthController::class, 'updateProfile']);

    Route::get('services',      [ServiceController::class, 'index']);
    Route::get('services/{id}', [ServiceController::class, 'show']);

    Route::get('barbers',                          [BarberController::class, 'index']);
    Route::get('barbers/{id}',                     [BarberController::class, 'show']);
    Route::get('barbers/{id}/available-slots',     [BarberController::class, 'availableSlots']);
    Route::get('barbers/{id}/unavailable-dates',   [BarberController::class, 'unavailableDates']);

    Route::get('bookings',               [BookingController::class, 'index']);
    Route::post('bookings',              [BookingController::class, 'store']);
    Route::get('bookings/{id}',          [BookingController::class, 'show']);
    Route::patch('bookings/{id}/cancel',     [BookingController::class, 'cancel']);
    Route::patch('bookings/{id}/reschedule', [BookingController::class, 'reschedule']);

    Route::post('bookings/{id}/pay',           [PaymentController::class, 'createTransaction']);
    Route::post('bookings/{id}/pay-cashless',  [PaymentController::class, 'chooseCashless']);
    Route::get('bookings/{id}/payment-status', [PaymentController::class, 'checkStatus']);

    Route::middleware('admin')->prefix('admin')->group(function () {

        Route::post('services',        [ServiceController::class, 'store']);
        Route::put('services/{id}',    [ServiceController::class, 'update']);
        Route::delete('services/{id}', [ServiceController::class, 'destroy']);

        Route::get('barbers',          [BarberController::class, 'adminIndex']);
        Route::post('barbers',         [BarberController::class, 'store']);
        Route::put('barbers/{id}',     [BarberController::class, 'update']);
        Route::delete('barbers/{id}',  [BarberController::class, 'destroy']);

        Route::get('barbers/{id}/unavailabilities',                    [BarberController::class, 'adminUnavailabilities']);
        Route::post('barbers/{id}/unavailabilities',                   [BarberController::class, 'storeUnavailability']);
        Route::delete('barbers/{id}/unavailabilities/{unavailabilityId}', [BarberController::class, 'destroyUnavailability']);

        Route::get('bookings',                 [BookingController::class, 'adminIndex']);
        Route::patch('bookings/{id}/status',   [BookingController::class, 'updateStatus']);

        Route::get('transactions',             [PaymentController::class, 'adminTransactions']);
        Route::get('revenue-report',           [PaymentController::class, 'revenueReport']);
        // Route::patch('payments/{id}/confirm-cash'); // Dihapus — cashless auto-paid sejak Juni 2026
    });
});

// Cronjob: auto-cancel booking expired (panggil dari cronjob.com)
Route::get('/cron/auto-cancel', function () {
    Artisan::call('bookings:auto-cancel');
    return response()->json([
        'success' => true,
        'message' => Artisan::output(),
    ]);
});

// Fallback untuk redirect middleware Authenticate — mencegah error "Route [login] not defined"
Route::any('/login', fn () => response()->json([
    'success' => false,
    'message' => 'Token tidak valid. Silakan login ulang.',
], 401))->name('login');