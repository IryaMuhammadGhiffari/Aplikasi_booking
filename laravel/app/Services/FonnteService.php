<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class FonnteService
{
    protected ?string $apiToken = null;
    protected string $baseUrl = 'https://api.fonnte.com';

    public function __construct()
    {
        $this->apiToken = config('services.fonnte.api_token') ?? env('FONNTE_API_TOKEN');
    }

    /**
     * Kirim pesan WhatsApp via Fonnte
     */
    public function sendMessage(string $target, string $message): array
    {
        if (!$this->apiToken) {
            Log::error('Fonnte API token not configured');
            return ['success' => false, 'message' => 'Fonnte API token not configured'];
        }

        try {
            $response = Http::withHeaders([
                'Authorization' => $this->apiToken,
            ])->asMultipart()->post("{$this->baseUrl}/send", [
                'target' => $this->formatPhoneNumber($target),
                'message' => $message,
            ]);

            $data = $response->json();

            if ($response->successful() && ($data['status'] ?? false)) {
                return ['success' => true, 'data' => $data];
            }

            Log::error('Fonnte send failed', ['response' => $data]);
            return ['success' => false, 'message' => $data['reason'] ?? 'Gagal mengirim pesan'];

        } catch (\Exception $e) {
            Log::error('Fonnte exception', ['error' => $e->getMessage()]);
            return ['success' => false, 'message' => 'Terjadi kesalahan: ' . $e->getMessage()];
        }
    }

    /**
     * Format nomor telepon ke format internasional (62xxx)
     */
    protected function formatPhoneNumber(string $phone): string
    {
        // Hapus karakter non-digit
        $phone = preg_replace('/\D/', '', $phone);

        // Jika sudah pakai 62, biarkan
        if (str_starts_with($phone, '62')) {
            return $phone;
        }

        // Jika pakai 0 di depan, ganti ke 62
        if (str_starts_with($phone, '0')) {
            return '62' . substr($phone, 1);
        }

        // Default tambah 62
        return '62' . $phone;
    }

    /**
     * Kirim OTP via WhatsApp
     */
    public function sendOtp(string $phone, string $otp): array
    {
        $message = "Kode OTP Arfan Barbershop: {$otp}\n\nKode ini berlaku 10 menit. Jangan bagikan ke siapapun.";
        return $this->sendMessage($phone, $message);
    }
}