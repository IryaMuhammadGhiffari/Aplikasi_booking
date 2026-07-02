<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Services\FonnteService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Validation\ValidationException;
use Illuminate\Support\Str;

class AuthController extends Controller
{
    protected FonnteService $fonnte;

    public function __construct(FonnteService $fonnte)
    {
        $this->fonnte = $fonnte;
    }
    /**
     * REGISTER - Daftar user baru
     */
    public function register(Request $request)
    {
        $request->validate([
            'name'     => 'required|string|max:255',
            'email'    => 'required|email|unique:users',
            'phone'    => 'required|string|max:20',
            'password' => 'required|min:6|confirmed',
        ]);

        $user = User::create([
            'name'     => $request->name,
            'email'    => $request->email,
            'phone'    => $request->phone,
            'password' => Hash::make($request->password),
            'role'     => 'user',
        ]);

        $token = $user->createToken('auth_token')->plainTextToken;

        return response()->json([
            'success' => true,
            'message' => 'Registrasi berhasil',
            'data'    => [
                'user'  => $user,
                'token' => $token,
            ],
        ], 201);
    }

    /**
     * LOGIN - Masuk ke akun
     */
    public function login(Request $request)
    {
        $request->validate([
            'email'    => 'required|email',
            'password' => 'required',
        ]);

        $user = User::where('email', $request->email)->first();

        if (! $user || ! Hash::check($request->password, $user->password)) {
            throw ValidationException::withMessages([
                'email' => ['Email atau password salah.'],
            ]);
        }

        // Hapus token expired/lama (tidak semua token — agar token Flutter tidak ikut terhapus)
        $user->tokens()
            ->where('created_at', '<', now()->subDays(7))
            ->delete();

        $token = $user->createToken('auth_token')->plainTextToken;

        return response()->json([
            'success' => true,
            'message' => 'Login berhasil',
            'data'    => [
                'user'  => $user,
                'token' => $token,
            ],
        ]);
    }

    /**
     * LOGOUT - Keluar dari akun
     */
    public function logout(Request $request)
    {
        $request->user()->currentAccessToken()->delete();

        return response()->json([
            'success' => true,
            'message' => 'Logout berhasil',
        ]);
    }

    /**
     * PROFILE - Lihat data profil sendiri
     */
    public function profile(Request $request)
    {
        return response()->json([
            'success' => true,
            'data'    => $request->user(),
        ]);
    }

    /**
     * FORGOT PASSWORD - Kirim OTP via WhatsApp
     */
    public function forgotPassword(Request $request)
    {
        $request->validate([
            'email' => 'required|email|exists:users,email',
        ]);

        $user = User::where('email', $request->email)->first();

        if (!$user->phone) {
            return response()->json([
                'success' => false,
                'message' => 'Nomor telepon tidak terdaftar. Hubungi admin.',
            ], 422);
        }

        // Generate 6-digit OTP
        $otp = (string) random_int(100000, 999999);

        // Simpan OTP ke database (password_reset_tokens)
        DB::table('password_reset_tokens')->updateOrInsert(
            ['email' => $user->email],
            [
                'token' => $otp,
                'created_at' => now(),
            ]
        );

        // Kirim OTP via WhatsApp
        $result = $this->fonnte->sendOtp($user->phone, $otp);

        if (!$result['success']) {
            Log::error('Gagal kirim OTP WA', ['user_id' => $user->id, 'error' => $result['message']]);
            // Debug: tetap kasih OTP di response biar bisa test flow-nya
        }

        return response()->json([
            'success' => true,
            'message' => 'Kode OTP telah dikirim ke WhatsApp Anda.',
            'debug_otp' => $otp, // HAPUS baris ini setelah WA berhasil
        ]);
    }

    /**
     * VERIFY OTP - Cek kode OTP
     */
    public function verifyOtp(Request $request)
    {
        $request->validate([
            'email' => 'required|email|exists:users,email',
            'otp'   => 'required|string|size:6',
        ]);

        $record = DB::table('password_reset_tokens')
            ->where('email', $request->email)
            ->where('token', $request->otp)
            ->first();

        if (!$record) {
            return response()->json([
                'success' => false,
                'message' => 'Kode OTP salah atau sudah kadaluarsa.',
            ], 422);
        }

        // Cek kadaluarsa (10 menit)
        if ($record->created_at->diffInMinutes(now()) > 10) {
            DB::table('password_reset_tokens')->where('email', $request->email)->delete();
            return response()->json([
                'success' => false,
                'message' => 'Kode OTP sudah kadaluarsa. Minta kode baru.',
            ], 422);
        }

        return response()->json([
            'success' => true,
            'message' => 'Kode OTP valid.',
        ]);
    }

    /**
     * RESET PASSWORD - Ganti password baru
     */
    public function resetPassword(Request $request)
    {
        $request->validate([
            'email'                 => 'required|email|exists:users,email',
            'otp'                   => 'required|string|size:6',
            'password'              => 'required|min:6|confirmed',
        ]);

        $record = DB::table('password_reset_tokens')
            ->where('email', $request->email)
            ->where('token', $request->otp)
            ->first();

        if (!$record) {
            return response()->json([
                'success' => false,
                'message' => 'Kode OTP salah atau sudah kadaluarsa.',
            ], 422);
        }

        if ($record->created_at->diffInMinutes(now()) > 10) {
            DB::table('password_reset_tokens')->where('email', $request->email)->delete();
            return response()->json([
                'success' => false,
                'message' => 'Kode OTP sudah kadaluarsa. Minta kode baru.',
            ], 422);
        }

        // Update password
        $user = User::where('email', $request->email)->first();
        $user->password = Hash::make($request->password);
        $user->save();

        // Hapus token
        DB::table('password_reset_tokens')->where('email', $request->email)->delete();

        // Revoke semua token lama
        $user->tokens()->delete();

        return response()->json([
            'success' => true,
            'message' => 'Password berhasil direset. Silakan login dengan password baru.',
        ]);
    }
}
