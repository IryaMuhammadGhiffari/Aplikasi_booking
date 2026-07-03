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

        $booking->update(['status' => 'cancelled']);

        if ($booking->payment) {
            if ($booking->payment->status === 'pending') {
                $booking->payment->update(['status' => 'failed']);
            } elseif ($booking->payment->status === 'paid') {
                // Coba void Midtrans — refund otomatis kalau transaksi belum settle
                if ($booking->payment->order_id) {
                    try {
                        Transaction::cancel($booking->payment->order_id);
                    } catch (\Exception $e) {
                        Log::warning('Midtrans void failed saat cancel booking', [
                            'booking_id' => $booking->id,
                            'order_id'   => $booking->payment->order_id,
                            'error'      => $e->getMessage(),
                        ]);
                    }
                }
                $booking->payment->update(['status' => 'refunded']);
            }
        }

        $message = 'Booking berhasil dibatalkan.';
        if ($booking->payment?->status === 'refunded') {
            $message = 'Booking dibatalkan. Dana akan dikembalikan. Hubungi admin jika refund belum diterima dalam 1x24 jam.';
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
                if ($booking->payment->status === 'paid' && $booking->payment->order_id) {
                    try {
                        Transaction::cancel($booking->payment->order_id);
                    } catch (\Exception $e) {
                        Log::warning('Midtrans void failed saat admin cancel', [
                            'booking_id' => $booking->id,
                            'order_id'   => $booking->payment->order_id,
                            'error'      => $e->getMessage(),
                        ]);
                    }
                    $booking->payment->update(['status' => 'refunded']);
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
}
