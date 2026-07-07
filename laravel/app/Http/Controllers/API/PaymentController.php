<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Models\Booking;
use App\Models\Payment;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class PaymentController extends Controller
{
    /**
     * Buat transaksi pembayaran via Pakasir.
     * Pakasir SDK: payment_url digenerate lokal, API dipanggil untuk dapat payment_number
     * Format payment_url: https://app.pakasir.com/pay/{project}/{amount}?order_id={order_id}&qris_only=1
     */
    public function createTransaction(Request $request, $bookingId)
    {
        set_time_limit(120);

        $booking = Booking::with([
                'user'     => fn ($q) => $q->select('id', 'name', 'email', 'phone'),
                'services' => fn ($q) => $q->select('services.id', 'services.name', 'services.price'),
                'barber'   => fn ($q) => $q->select('id', 'name'),
                'payment'  => fn ($q) => $q->select('id', 'booking_id', 'order_id', 'amount', 'status', 'payment_method', 'payment_url'),
            ])
            ->where('user_id', $request->user()->id)
            ->findOrFail($bookingId);

        if ($booking->status !== 'confirmed' && $booking->status !== 'in_progress') {
            return response()->json([
                'success' => false,
                'message' => 'Booking belum dikonfirmasi admin. Silakan tunggu konfirmasi terlebih dahulu.',
            ], 422);
        }

        if ($booking->payment?->status === 'paid') {
            return response()->json([
                'success' => false,
                'message' => 'Booking ini sudah dibayar.',
            ], 422);
        }

        $refresh  = $request->boolean('refresh');
        $existing = Payment::where('booking_id', $booking->id)
            ->where('status', 'pending')
            ->whereNotNull('payment_url')
            ->first();

        if ($existing && !$refresh) {
            return response()->json([
                'success' => true,
                'data'    => [
                    'payment_url' => $existing->payment_url,
                    'order_id'    => $existing->order_id,
                ],
            ]);
        }

        // Kalau refresh, cancel transaksi lama di Pakasir
        if ($existing && $refresh) {
            $this->cancelPakasirTransaction($existing->order_id, (int) $existing->amount);
        }

        $orderId = 'ARF-PAY-' . $booking->id . '-' . time();
        $amount  = (int) $booking->total_price;
        $slug    = config('pakasir.slug');

        // Payment URL digenerate lokal — tanpa qris_only biar muncul semua metode
        $paymentUrl = 'https://app.pakasir.com/pay/' . $slug . '/' . $amount
            . '?order_id=' . urlencode($orderId);

        // Data default (dipakai kalau API call gagal)
        $paymentData = [
            'payment_method' => 'qris',
            'payment_number' => null,
            'fee'            => 0,
            'total_payment'  => $amount,
            'expired_at'     => now()->addDay()->toIso8601String(),
        ];

        // Coba panggil API untuk dapat payment_number dan fee asli
        try {
            $response = Http::timeout(10)->post('https://app.pakasir.com/api/transactioncreate/qris', [
                'project'  => $slug,
                'order_id' => $orderId,
                'amount'   => $amount,
                'api_key'  => config('pakasir.api_key'),
            ]);

            if ($response->successful()) {
                $result = $response->json();
                $apiData = $result['payment'] ?? [];
                if ($apiData) {
                    $paymentData = array_merge($paymentData, $apiData);
                }
            } else {
                Log::warning('Pakasir API warning: ' . $response->body());
            }
        } catch (\Exception $e) {
            // API gagal — tetap lanjut pake payment_url lokal
            Log::warning('Pakasir API call failed (using local payment_url): ' . $e->getMessage());
        }

        Payment::updateOrCreate(
            ['booking_id' => $booking->id],
            [
                'order_id'       => $orderId,
                'amount'         => $booking->total_price,
                'status'         => 'pending',
                'payment_method' => $paymentData['payment_method'] ?? 'qris',
                'payment_url'    => $paymentUrl,
                'transaction_id' => $paymentData['order_id'] ?? null,
            ]
        );

        return response()->json([
            'success' => true,
            'data'    => [
                'payment_url'  => $paymentUrl,
                'order_id'     => $orderId,
                'payment_number' => $paymentData['payment_number'] ?? null,
            ],
        ]);
    }

    /**
     * Webhook dari Pakasir — dipanggil saat pembayaran sukses.
     * Body: { amount, order_id, project, status, payment_method, completed_at }
     */
    public function notification(Request $request)
    {
        try {
            $payload = $request->all();

            $payment = Payment::where('order_id', $payload['order_id'])->first();

            if (!$payment) {
                Log::warning('Pakasir webhook: order_id tidak ditemukan', $payload);
                return response()->json(['success' => false, 'message' => 'Order not found'], 404);
            }

            // Verifikasi amount cocok
            $receivedAmount = (int) $payload['amount'];
            $expectedAmount = (int) $payment->amount;
            if ($receivedAmount !== $expectedAmount) {
                Log::warning('Pakasir webhook: amount mismatch', [
                    'expected' => $expectedAmount,
                    'received' => $receivedAmount,
                    'order_id' => $payload['order_id'],
                ]);
                return response()->json(['success' => false, 'message' => 'Amount mismatch'], 422);
            }

            // Map status Pakasir ke status lokal
            $paymentStatus = match ($payload['status'] ?? '') {
                'completed' => 'paid',
                'canceled'  => 'failed',
                default     => 'pending',
            };

            $payment->update([
                'status'          => $paymentStatus,
                'payment_method'  => $payload['payment_method'] ?? $payment->payment_method,
                'paid_at'         => $paymentStatus === 'paid' ? ($payment->paid_at ?? now()) : null,
            ]);

            if ($paymentStatus === 'paid') {
                Log::info("Pakasir payment completed: order_id={$payload['order_id']}, amount={$receivedAmount}");
            }

            return response()->json(['success' => true]);

        } catch (\Exception $e) {
            Log::error('Pakasir webhook error: ' . $e->getMessage());
            return response()->json([
                'success' => false,
                'message' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Sync status dari Pakasir untuk payment pending.
     */
    private function syncFromPakasir(Payment $payment): void
    {
        if (!$payment->order_id || $payment->payment_method === 'cashless') {
            return;
        }

        try {
            $response = Http::get('https://app.pakasir.com/api/transactiondetail', [
                'project'  => config('pakasir.slug'),
                'amount'   => (int) $payment->amount,
                'order_id' => $payment->order_id,
                'api_key'  => config('pakasir.api_key'),
            ]);

            if (!$response->successful()) return;

            $result = $response->json();
            $data   = $result['transaction'] ?? null;
            if (!$data) return;

            $status = match ($data['status'] ?? '') {
                'completed' => 'paid',
                'canceled'  => 'failed',
                default     => 'pending',
            };

            if ($status !== $payment->status) {
                $payment->update([
                    'status'          => $status,
                    'payment_method'  => $data['payment_method'] ?? $payment->payment_method,
                    'paid_at'         => $status === 'paid' ? ($payment->paid_at ?? now()) : null,
                ]);
            }
        } catch (\Exception $e) {
            Log::warning('Pakasir sync error: ' . $e->getMessage());
        }
    }

    /**
     * Cancel transaksi di Pakasir.
     */
    public function cancelPakasirTransaction(string $orderId, int $amount): bool
    {
        try {
            $response = Http::post('https://app.pakasir.com/api/transactioncancel', [
                'project'  => config('pakasir.slug'),
                'order_id' => $orderId,
                'amount'   => $amount,
                'api_key'  => config('pakasir.api_key'),
            ]);

            return $response->successful();
        } catch (\Exception $e) {
            Log::warning('Pakasir cancel error: ' . $e->getMessage());
            return false;
        }
    }

    public function chooseCashless(Request $request, $bookingId)
    {
        $booking = Booking::with(['payment' => fn ($q) => $q->select('id', 'booking_id', 'order_id', 'status')])
            ->where('user_id', $request->user()->id)
            ->findOrFail($bookingId);

        if ($booking->status !== 'confirmed') {
            return response()->json([
                'success' => false,
                'message' => 'Booking belum dikonfirmasi admin.',
            ], 422);
        }

        if ($booking->payment?->status === 'paid') {
            return response()->json([
                'success' => false,
                'message' => 'Booking ini sudah dibayar.',
            ], 422);
        }

        $orderId = 'ARF-CASH-' . $booking->id . '-' . time();

        $payment = Payment::updateOrCreate(
            ['booking_id' => $booking->id],
            [
                'order_id'       => $orderId,
                'amount'         => $booking->total_price,
                'payment_method' => 'cashless',
                'status'         => 'paid',
                'paid_at'        => now(),
                'payment_url'    => null,
                'transaction_id' => null,
            ]
        );

        return response()->json([
            'success' => true,
            'message' => 'Booking dikonfirmasi. Bayar tunai saat datang ke barbershop.',
            'data'    => $payment,
        ]);
    }

    public function checkStatus(Request $request, $bookingId)
    {
        $booking = Booking::with(['payment' => fn ($q) => $q->select('id', 'booking_id', 'order_id', 'status', 'payment_method')])
            ->where('user_id', $request->user()->id)
            ->findOrFail($bookingId);

        if ($booking->payment && $booking->payment->status === 'pending') {
            if ($booking->payment->payment_method !== 'cashless') {
                $this->syncFromPakasir($booking->payment);
            }
            $booking->load(['payment' => fn ($q) => $q->select('id', 'booking_id', 'order_id', 'transaction_id', 'amount', 'status', 'payment_method', 'payment_url', 'paid_at')]);
        }

        return response()->json([
            'success' => true,
            'data'    => [
                'booking_status' => $booking->status,
                'payment'        => $booking->payment,
            ],
        ]);
    }

    public function adminTransactions()
    {
        $payments = Payment::with([
                'booking'         => fn ($q) => $q->select('id', 'booking_code', 'user_id', 'barber_id', 'booking_date', 'booking_time', 'total_price', 'status', 'created_at'),
                'booking.user'    => fn ($q) => $q->select('id', 'name', 'email', 'phone'),
                'booking.services'=> fn ($q) => $q->select('services.id', 'services.name', 'services.price'),
                'booking.barber'  => fn ($q) => $q->select('barbers.id', 'barbers.name'),
            ])
            ->select('id', 'booking_id', 'order_id', 'transaction_id', 'amount', 'payment_method', 'status', 'paid_at', 'created_at')
            ->orderByDesc('created_at')
            ->get();

        return response()->json([
            'success' => true,
            'data'    => $payments,
        ]);
    }

    public function adminRefunds()
    {
        $payments = Payment::with([
                'booking'         => fn ($q) => $q->select('id', 'booking_code', 'user_id', 'barber_id', 'booking_date', 'booking_time', 'total_price', 'status', 'created_at'),
                'booking.user'    => fn ($q) => $q->select('id', 'name', 'email', 'phone'),
                'booking.services'=> fn ($q) => $q->select('services.id', 'services.name', 'services.price'),
                'booking.barber'  => fn ($q) => $q->select('barbers.id', 'barbers.name'),
            ])
            ->where('status', 'refund_pending')
            ->select('id', 'booking_id', 'order_id', 'transaction_id', 'amount', 'payment_method', 'status', 'cancel_reason', 'admin_note', 'paid_at', 'created_at')
            ->orderByDesc('created_at')
            ->get();

        return response()->json([
            'success' => true,
            'data'    => $payments,
        ]);
    }

    public function adminRefundHistory()
    {
        $payments = Payment::with([
                'booking'         => fn ($q) => $q->select('id', 'booking_code', 'user_id', 'barber_id', 'booking_date', 'booking_time', 'total_price', 'status', 'created_at'),
                'booking.user'    => fn ($q) => $q->select('id', 'name', 'email', 'email', 'phone'),
                'booking.services'=> fn ($q) => $q->select('services.id', 'services.name', 'services.price'),
                'booking.barber'  => fn ($q) => $q->select('barbers.id', 'barbers.name'),
            ])
            ->where('status', 'refunded')
            ->select('id', 'booking_id', 'order_id', 'transaction_id', 'amount', 'payment_method', 'status', 'cancel_reason', 'admin_note', 'paid_at', 'created_at')
            ->orderByDesc('created_at')
            ->get();

        return response()->json([
            'success' => true,
            'data'    => $payments,
        ]);
    }

    public function approveRefund(Request $request, $id)
    {
        $request->validate([
            'admin_note' => 'nullable|string|max:500',
        ]);

        $payment = Payment::with('booking.user')->findOrFail($id);

        if ($payment->status !== 'refund_pending') {
            return response()->json([
                'success' => false,
                'message' => 'Status pembayaran bukan refund_pending.',
            ], 422);
        }

        $payment->update([
            'status'     => 'refunded',
            'paid_at'    => null,
            'admin_note' => $request->admin_note,
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Refund berhasil dikonfirmasi.',
            'data'    => $payment,
        ]);
    }

    public function revenueReport(Request $request)
    {
        $request->validate([
            'start_date' => 'required|date',
            'end_date'   => 'required|date|after_or_equal:start_date',
        ]);

        $report = Payment::where('status', 'paid')
            ->whereBetween('paid_at', [
                $request->start_date . ' 00:00:00',
                $request->end_date   . ' 23:59:59',
            ])
            ->selectRaw('DATE(paid_at) as date, SUM(amount) as total, COUNT(*) as count')
            ->groupBy('date')
            ->orderBy('date')
            ->get();

        return response()->json([
            'success' => true,
            'data'    => [
                'report'        => $report,
                'total_revenue' => $report->sum('total'),
                'start_date'    => $request->start_date,
                'end_date'      => $request->end_date,
            ],
        ]);
    }
}
