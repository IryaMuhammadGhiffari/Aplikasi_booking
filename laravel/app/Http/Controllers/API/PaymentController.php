<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Models\Booking;
use App\Models\Payment;
use Illuminate\Http\Request;
use Midtrans\Config;
use Midtrans\Snap;
use Midtrans\Notification;
use Midtrans\Transaction;

class PaymentController extends Controller
{
    public function __construct()
    {
        Config::$serverKey    = 'Mid-server-aHPclL_F17BrzXl6nAZPBLQz';
        Config::$isProduction = false;
        Config::$isSanitized  = true;
        Config::$is3ds        = true;
        // Nonaktifkan SSL verify untuk development (Windows tanpa CA bundle)
        Config::$curlOptions = [
            CURLOPT_SSL_VERIFYPEER => false,
            CURLOPT_SSL_VERIFYHOST => false,
            CURLOPT_HTTPHEADER => [],
        ];
    }

    public function createTransaction(Request $request, $bookingId)
    {
        set_time_limit(120);

        $booking = Booking::with([
                'user'     => fn ($q) => $q->select('id', 'name', 'email', 'phone'),
                'services' => fn ($q) => $q->select('services.id', 'services.name', 'services.price'),
                'barber'   => fn ($q) => $q->select('id', 'name'),
                'payment'  => fn ($q) => $q->select('id', 'booking_id', 'order_id', 'amount', 'status', 'payment_method', 'snap_token', 'snap_url'),
            ])
            ->where('user_id', $request->user()->id)
            ->findOrFail($bookingId);

        if ($booking->status !== 'confirmed') {
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
            ->whereNotNull('snap_token')
            ->first();

        if ($existing && !$refresh) {
            return response()->json([
                'success' => true,
                'data'    => [
                    'snap_token' => $existing->snap_token,
                    'snap_url'   => $existing->snap_url,
                    'order_id'   => $existing->order_id,
                ],
            ]);
        }

        if ($existing && $refresh) {
            try {
                Transaction::cancel($existing->order_id);
            } catch (\Exception) {
                // Transaksi lama mungkin sudah tidak bisa dibatalkan di Midtrans
            }
        }

        $orderId = 'ARF-PAY-' . $booking->id . '-' . time();

        $params = [
            'transaction_details' => [
                'order_id'     => $orderId,
                'gross_amount' => (int) $booking->total_price,
            ],
            'customer_details' => [
                'first_name' => $booking->user->name,
                'email'      => $booking->user->email,
                'phone'      => $booking->user->phone ?? '',
            ],
            'item_details' => $booking->services->map(fn($service) => [
                'id'       => $service->id,
                'price'    => (int) $service->price,
                'quantity' => 1,
                'name'     => $service->name,
            ])->values()->toArray(),
        ];

        try {
            $snapToken = Snap::getSnapToken($params);
            $snapUrl   = 'https://app.sandbox.midtrans.com/snap/v2/vtweb/' . $snapToken;
        } catch (\Exception $e) {
            \Log::warning('Midtrans createTransaction error: ' . $e->getMessage());
            return response()->json([
                'success' => false,
                'message' => 'Gagal terhubung ke server pembayaran. Silakan coba lagi.',
            ], 502);
        }

        Payment::updateOrCreate(
            ['booking_id' => $booking->id],
            [
                'order_id'   => $orderId,
                'amount'     => $booking->total_price,
                'status'     => 'pending',
                'snap_token' => $snapToken,
                'snap_url'   => $snapUrl,
            ]
        );

        return response()->json([
            'success' => true,
            'data'    => [
                'snap_token' => $snapToken,
                'snap_url'   => $snapUrl,
                'order_id'   => $orderId,
            ],
        ]);
    }

    public function notification(Request $request)
    {
        try {
            $notification = new Notification();

            $payment = Payment::where('order_id', $notification->order_id)->firstOrFail();

            $this->applyMidtransUpdate($payment, [
                'transaction_status' => $notification->transaction_status,
                'fraud_status'       => $notification->fraud_status,
                'payment_type'       => $notification->payment_type,
                'transaction_id'     => $notification->transaction_id,
            ], $request->all());

            return response()->json(['success' => true]);

        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => $e->getMessage(),
            ], 500);
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
                'order_id'        => $orderId,
                'amount'          => $booking->total_price,
                'payment_method'  => 'cashless',
                'status'          => 'paid',
                'paid_at'         => now(),
                'snap_token'      => null,
                'snap_url'        => null,
                'transaction_id'  => null,
                'midtrans_response' => null,
            ]
        );

        return response()->json([
            'success' => true,
            'message' => 'Pembayaran tunai berhasil. Tunjukkan kode booking saat datang.',
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
                $this->syncPaymentFromMidtrans($booking->payment);
            }
            $booking->load(['payment' => fn ($q) => $q->select('id', 'booking_id', 'order_id', 'transaction_id', 'amount', 'status', 'payment_method', 'snap_token', 'snap_url', 'paid_at', 'midtrans_response')]);
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

    private function mapMidtransStatus(string $transactionStatus, ?string $fraudStatus = null): string
    {
        if ($transactionStatus === 'capture') {
            return ($fraudStatus === 'challenge') ? 'pending' : 'paid';
        }
        if ($transactionStatus === 'settlement') {
            return 'paid';
        }
        if (in_array($transactionStatus, ['cancel', 'deny'], true)) {
            return 'failed';
        }
        if ($transactionStatus === 'expire') {
            return 'expired';
        }

        return 'pending';
    }

    private function applyMidtransUpdate(Payment $payment, array $midtrans, ?array $rawResponse = null): void
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

    private function syncPaymentFromMidtrans(Payment $payment): void
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
}