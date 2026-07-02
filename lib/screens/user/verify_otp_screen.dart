import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_routes.dart';
import '../../widgets/gold_button.dart';
import '../../widgets/custom_text_field.dart';

class VerifyOtpScreen extends StatefulWidget {
  final String email;
  const VerifyOtpScreen({super.key, required this.email});
  @override
  State<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends State<VerifyOtpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _otpCtrl = TextEditingController();
  int _resendCooldown = 0;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  void _startCooldown() {
    setState(() => _resendCooldown = 60);
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _resendCooldown--);
      return _resendCooldown > 0;
    });
  }

  Future<void> _verifyOtp() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final success = await auth.verifyOtp(widget.email, _otpCtrl.text.trim());

    if (!mounted) return;

    if (success) {
      Navigator.pushNamed(
        context,
        AppRoutes.resetPassword,
        arguments: {'email': widget.email, 'otp': _otpCtrl.text.trim()},
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(auth.errorMessage ?? 'Kode OTP salah'),
        backgroundColor: AppColors.error,
      ));
    }
  }

  Future<void> _resendOtp() async {
    if (_resendCooldown > 0) return;

    final auth = context.read<AuthProvider>();
    final success = await auth.forgotPassword(widget.email);

    if (!mounted) return;

    if (success) {
      _startCooldown();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Kode OTP baru telah dikirim'),
        backgroundColor: AppColors.success,
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(auth.errorMessage ?? 'Gagal mengirim ulang'),
        backgroundColor: AppColors.error,
      ));
    }
  }

  @override
  void dispose() {
    _otpCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Verifikasi OTP', style: Theme.of(context).textTheme.displayMedium),
                const SizedBox(height: 6),
                Text('Masukkan 6 digit kode OTP yang dikirim ke WhatsApp',
                    style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 32),

                Text('Kode OTP', style: GoogleFonts.poppins(color: AppColors.lightGrey, fontSize: 13)),
                const SizedBox(height: 8),
                CustomTextField(
                  controller: _otpCtrl,
                  hintText: '123456',
                  prefixIcon: Icons.lock_outlined,
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v?.isEmpty ?? true) return 'Kode OTP wajib diisi';
                    if (v!.length != 6) return 'Kode OTP 6 digit';
                    return null;
                  },
                ),
                const SizedBox(height: 36),

                Consumer<AuthProvider>(
                  builder: (_, auth, __) => GoldButton(
                    onPressed: auth.isLoading ? null : _verifyOtp,
                    isLoading: auth.isLoading,
                    label: 'VERIFIKASI',
                  ),
                ),
                const SizedBox(height: 16),

                Center(
                  child: _resendCooldown > 0
                      ? Text('Kirim ulang dalam ${_resendCooldown}s',
                          style: GoogleFonts.poppins(color: AppColors.grey, fontSize: 13))
                      : GestureDetector(
                          onTap: _resendOtp,
                          child: Text('Kirim ulang kode OTP',
                              style: GoogleFonts.poppins(
                                  color: AppColors.secondary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14)),
                        ),
                ),
                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Kembali ke ', style: Theme.of(context).textTheme.bodyLarge),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Text('Lupa Password',
                          style: GoogleFonts.poppins(color: AppColors.secondary, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}