<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Models\Booking;
use App\Models\BarberUnavailability;
use App\Models\Service;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Midtrans\Transaction;

class BookingController extends Controller
{
    public function index(Request $request)
    {
        $bookings = Booking::with([
                'barber'   => fn ($q) => $q->select('id', 'name'),
                'services' => fn ($q) => $q->select('services.id', 'services.name', 'services.price', 'services.duration'),
                'payment'  => fn ($q) => $q->select('id', 'booking_id', 'order_id', 'amount', 'status', 'payment_method', 'paid_at'),
            ])
            ->where('user_id', $request->user()->id)
            ->orderByDesc('created_at')
            ->get();

        return response()->json(['success' => true, 'data' => $bookings]);
    }

    public function show(Request $request, $id)
    {
        $booking = Booking::with([
                'barber'   => fn ($q) => $q->select('id', 'name', 'specialty'),
                'services' => fn ($q) => $q->select('services.id', 'services.name', 'services.price', 'services.duration'),
                'payment'  => fn ($q) => $q->select('id', 'booking_id', 'order_id', 'transaction_id', 'amount', 'status', 'payment_method', 'snap_token', 'snap_url', 'paid_at', 'created_at'),
                'user'     => fn ($q) => $q->select('id', 'name', 'email', 'phone'),
            ])->findOrFail($id);

        if ($request->user()->role === 'user' && $booking->user_id !== $request->user()->id) {
            return response()->json(['success' => false, 'message' => 'Akses ditolak'], 403);
        }

        return response()->json(['success' => true, 'data' => $booking]);
    }

    public function store(Request $request)
    {
        // Dukung service_ids (baru) dan service_id (lama) untuk kompatibilitas
        $serviceIds = $request->service_ids;
        if (empty($serviceIds) && $request->service_id) {
            $serviceIds = [$request->service_id];
        }

        $request->merge(['service_ids' => $serviceIds]);

        $request->validate([
            'barber_id'      => 'required|exists:barbers,id',
            'service_ids'    => 'required|array|min:1',
            'service_ids.*'  => 'exists:services,id',
            'booking_date'   => 'required|date|after_or_equal:today',
            'booking_time'   => 'required|date_format:H:i',
            'notes'          => 'nullable|string|max:500',
        ]);

        $conflict = Booking::where('barber_id', $request->barber_id)
            ->where('booking_date', $request->booking_date)
            ->where('booking_time', $request->booking_time . ':00')
            ->whereNotIn('status', ['cancelled'])
            ->exists();

        if ($conflict) {
            return response()->json([
                'success' => false,
                'message' => 'Jadwal sudah dipesan. Silakan pilih waktu lain.',
            ], 422);
        }

        $unavailable = BarberUnavailability::where('barber_id', $request->barber_id)
            ->where('date', $request->booking_date)
            ->exists();

        if ($unavailable) {
            return response()->json([
                'success' => false,
                'message' => 'Barber tidak tersedia pada tanggal ini.',
            ], 422);
        }

        $services = Service::whereIn('id', $request->service_ids)
            ->where('is_active', true)
            ->get();

        if ($services->count() !== count(array_unique($request->service_ids))) {
            return response()->json([
                'success' => false,
                'message' => 'Satu atau lebih layanan tidak valid atau tidak aktif.',
            ], 422);
        }

        $totalPrice = $services->sum('price');

        $booking = Booking::create([
            'user_id'      => $request->user()->id,
            'barber_id'    => $request->barber_id,
            'booking_date' => $request->booking_date,
            'booking_time' => $request->booking_time . ':00',
            'total_price'  => $totalPrice,
            'notes'        => $request->notes,
            'status'       => 'pending',
        ]);

        $booking->services()->attach($request->service_ids);

        return response()->json([
            'success' => true,
            'message' => 'Booking berhasil dibuat',
            'data'    => $booking->load([
                'barber'   => fn ($q) => $q->select('id', 'name', 'specialty'),
                'services' => fn ($q) => $q->select('services.id', 'services.name', 'services.price', 'services.duration'),
            ]),
        ], 201);
    }

    public function cancel(Request $request, $id)
    {
        $booking = Booking::where('user_id', $request->user()->id)->findOrFail($id);

        if (!in_array($booking->status, ['pending', 'confirmed'])) {
            return response()->json([
                'success' => false,
                'message' => 'Booking tidak bisa dibatalkan pada status ini.',
            ], 422);
        }

        // Minimal 6 jam sebelum jadwal — DISABLED sementara karena server clock Render off by ~1 tahun
        // $bookingDateStr = $booking->booking_date->format('Y-m-d');
        // $bookingTimeStr = $booking->booking_time;
        // $bookingDateTime = \Carbon\Carbon::parse($bookingDateStr . ' ' . $bookingTimeStr);
        // $hoursDiff = $bookingDateTime->diffInHours(now());
        // if ($hoursDiff < 6) {
        //     return response()->json([
        //         'success' => false,
        //         'message' => "Booking tidak bisa dibatalkan. Jadwal: {$bookingDateStr} {$bookingTimeStr}, sekarang: " . now()->format('Y-m-d H:i:s') . ", selisih: {$hoursDiff} jam.",
        //     ], 422);
        // }

        // Sync payment status dari Midtrans dulu (kalau bukan cashless)
        if ($booking->payment && $booking->payment->payment_method !== 'cashless') {
            $this->syncPaymentFromMidtrans($booking->payment);
            $booking->payment->refresh();
        }

        $refunded = false;
        $refundMessage = '';

        if ($booking->payment) {
            if ($booking->payment->status === 'pending') {
                $booking->payment->update(['status' => 'failed']);
                $refunded = true; // pending tidak perlu refund, cukup gagal
            } elseif ($booking->payment->status === 'paid') {
                if ($booking->payment->order_id) {
                    try {
                        // 1. Coba void dulu (untuk transaksi pending/belum settle)
                        Transaction::cancel($booking->payment->order_id);
                        $refunded = true;
                        $refundMessage = 'Void berhasil, dana dikembalikan instan.';
                    } catch (\Exception $e) {
                        // 2. Kalau void gagal (sudah settle), coba refund dengan amount
                        try {
                            $amount = (int) $booking->payment->amount; // amount dalam rupiah
                            $refund = Transaction::refund($booking->payment->order_id, [
                                'amount' => $amount,
                                'reason' => 'Customer cancel booking',
                            ]);
                            if (isset($refund->status_code) && $refund->status_code === '200') {
                                $refunded = true;
                                $refundMessage = 'Refund diproses, dana kembali 1-7 hari kerja.';
                            } else {
                                $refundMessage = 'Refund gagal: ' . ($refund->status_message ?? 'Unknown error');
                            }
                        } catch (\Exception $e2) {
                            Log::error('Midtrans refund failed', [
                                'booking_id' => $booking->id,
                                'order_id'   => $booking->payment->order_id,
                                'error'      => $e2->getMessage(),
                            ]);
                            $refundMessage = 'Refund error: ' . $e2->getMessage();
                        }
                    }
                }
                $booking->payment->update([
                    'status' => $refunded ? 'refunded' : 'refund_pending',
                ]);
            }
        }

        // Update booking status SETELAH proses refund
        $booking->update(['status' => 'cancelled']);

        $message = 'Booking berhasil dibatalkan.';
        if ($booking->payment?->status === 'refunded') {
            $message = 'Booking dibatalkan. ' . ($refundMessage ?: 'Dana akan dikembalikan. Hubungi admin jika refund belum diterima dalam 1x24 jam.');
        } elseif ($booking->payment?->status === 'refund_pending') {
            $message = 'Booking dibatalkan tapi refund gagal: ' . $refundMessage . '. Hubungi admin untuk proses manual.';
        }

        return response()->json(['success' => true, 'message' => $message]);
    }

    public function reschedule(Request $request, $id)
    {
        $booking = Booking::where('user_id', $request->user()->id)->findOrFail($id);

        if (!in_array($booking->status, ['pending', 'confirmed'])) {
            return response()->json([
                'success' => false,
                'message' => 'Jadwal tidak bisa diubah pada status ini.',
            ], 422);
        }

        $request->validate([
            'booking_date' => 'required|date|after_or_equal:today',
            'booking_time' => 'required|date_format:H:i',
        ]);

        $unavailable = BarberUnavailability::where('barber_id', $booking->barber_id)
            ->where('date', $request->booking_date)
            ->exists();

        if ($unavailable) {
            return response()->json([
                'success' => false,
                'message' => 'Barber tidak tersedia pada tanggal ini.',
            ], 422);
        }

        $conflict = Booking::where('barber_id', $booking->barber_id)
            ->where('booking_date', $request->booking_date)
            ->where('booking_time', $request->booking_time . ':00')
            ->where('id', '!=', $booking->id)
            ->whereNotIn('status', ['cancelled'])
            ->exists();

        if ($conflict) {
            return response()->json([
                'success' => false,
                'message' => 'Jadwal sudah dipesan. Silakan pilih waktu lain.',
            ], 422);
        }

        $wasConfirmed = $booking->status === 'confirmed';

        $updates = [
            'booking_date' => $request->booking_date,
            'booking_time' => $request->booking_time . ':00',
        ];

        if ($wasConfirmed) {
            $updates['status'] = 'pending';
        }

        $booking->update($updates);

        if ($wasConfirmed && $booking->payment?->status === 'pending') {
            $booking->payment->update([
                'status'     => 'failed',
                'snap_token' => null,
                'snap_url'   => null,
            ]);
        }

        return response()->json([
            'success' => true,
            'message' => 'Jadwal booking berhasil diubah',
            'data'    => $booking->fresh([
                'barber'   => fn ($q) => $q->select('id', 'name', 'specialty'),
                'services' => fn ($q) => $q->select('services.id', 'services.name', 'services.price', 'services.duration'),
                'payment'  => fn ($q) => $q->select('id', 'booking_id', 'order_id', 'transaction_id', 'amount', 'status', 'payment_method', 'snap_token', 'snap_url', 'paid_at'),
            ]),
        ]);
    }

    // ADMIN
    public function adminIndex(Request $request)
    {
        $query = Booking::with([
                'user'     => fn ($q) => $q->select('id', 'name', 'email', 'phone'),
                'barber'   => fn ($q) => $q->select('id', 'name'),
                'services' => fn ($q) => $q->select('services.id', 'services.name', 'services.price', 'services.duration'),
                'payment'  => fn ($q) => $q->select('id', 'booking_id', 'order_id', 'amount', 'status', 'payment_method', 'paid_at'),
            ])
            ->select('id', 'booking_code', 'user_id', 'barber_id', 'booking_date', 'booking_time', 'total_price', 'status', 'notes', 'created_at')
            ->orderByDesc('created_at');

        if ($request->status) $query->where('status', $request->status);
        if ($request->date)   $query->where('booking_date', $request->date);

        return response()->json(['success' => true, 'data' => $query->get()]);
    }

    public function updateStatus(Request $request, $id)
    {
        $request->validate([
            'status' => 'required|in:pending,confirmed,in_progress,completed,cancelled',
        ]);

        $booking = Booking::with(['payment' => fn ($q) => $q->select('id', 'booking_id', 'order_id', 'status')])->findOrFail($id);
        $booking->update(['status' => $request->status]);

        if ($request->status === 'cancelled') {
            if ($booking->payment && in_array($booking->payment->status, ['pending', 'paid'])) {
                if ($booking->payment->status === 'paid') {
                    $refunded = false;
                    if ($booking->payment->order_id) {
                        try {
                            Transaction::cancel($booking->payment->order_id);
                            $refunded = true;
                        } catch (\Exception $e) {
                            try {
                                $amount = (int) $booking->payment->amount;
                                $refund = Transaction::refund($booking->payment->order_id, [
                                    'amount' => $amount,
                                    'reason' => 'Admin cancel booking',
                                ]);
                                if (isset($refund->status_code) && $refund->status_code === '200') {
                                    $refunded = true;
                                }
                            } catch (\Exception $e2) {
                                Log::error('Midtrans refund failed (admin)', [
                                    'booking_id' => $booking->id,
                                    'order_id'   => $booking->payment->order_id,
                                    'error'      => $e2->getMessage(),
                                ]);
                            }
                        }
                    }
                    $booking->payment->update([
                        'status' => $refunded ? 'refunded' : 'refund_pending',
                    ]);
                } else {
                    $booking->payment->update(['status' => 'failed']);
                }
            }
        }

        return response()->json([
            'success' => true,
            'message' => 'Status booking berhasil diperbarui',
            'data'    => $booking->fresh(['payment' => fn ($q) => $q->select('id', 'booking_id', 'order_id', 'amount', 'status', 'payment_method', 'paid_at')]),
        ]);
    }

    private function syncPaymentFromMidtrans($payment): void
    {
        if (!$payment->order_id || $payment->payment_method === 'cashless') {
            return;
        }

        try {
            $midtrans = Transaction::status($payment->order_id);
        } catch (\Exception) {
            return;
        }

        if (is_array($midtrans)) {
            $midtrans = (object) $midtrans;
        }

        $this->applyMidtransUpdate($payment, [
            'transaction_status' => $midtrans->transaction_status,
            'fraud_status'       => $midtrans->fraud_status ?? null,
            'payment_type'       => $midtrans->payment_type ?? null,
            'transaction_id'     => $midtrans->transaction_id ?? null,
        ], (array) $midtrans);
    }

    private function applyMidtransUpdate($payment, array $midtrans, ?array $rawResponse = null): void
    {
        $paymentStatus = $this->mapMidtransStatus(
            $midtrans['transaction_status'],
            $midtrans['fraud_status'] ?? null
        );

        $payment->update([
            'transaction_id'    => $midtrans['transaction_id'] ?? $payment->transaction_id,
            'payment_method'    => $midtrans['payment_type'] ?? $payment->payment_method,
            'status'            => $paymentStatus,
            'midtrans_response' => $rawResponse ?? $payment->midtrans_response,
            'paid_at'           => $paymentStatus === 'paid' ? ($payment->paid_at ?? now()) : null,
        ]);
    }

    private function mapMidtransStatus(string $transactionStatus, ?string $fraudStatus): string
    {
        if ($transactionStatus === 'capture') {
            return $fraudStatus === 'challenge' ? 'pending' : 'paid';
        }
        if ($transactionStatus === 'settlement') {
            return 'paid';
        }
        if (in_array($transactionStatus, ['pending', 'authorize'])) {
            return 'pending';
        }
        return 'failed';
    }
}
