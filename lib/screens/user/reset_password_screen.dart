import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_routes.dart';
import '../../widgets/gold_button.dart';
import '../../widgets/custom_text_field.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String email;
  final String otp;
  const ResetPasswordScreen({super.key, required this.email, required this.otp});
  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure1 = true;
  bool _obscure2 = true;

  @override
  void dispose() {
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final success = await auth.resetPassword(
      widget.email,
      widget.otp,
      _passCtrl.text,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Password berhasil direset'),
        backgroundColor: AppColors.success,
      ));
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.login,
        (route) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(auth.errorMessage ?? 'Gagal mereset password'),
        backgroundColor: AppColors.error,
      ));
    }
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
                Text('Atur Password Baru', style: Theme.of(context).textTheme.displayMedium),
                const SizedBox(height: 6),
                Text('Masukkan password baru Anda (minimal 6 karakter)',
                    style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 32),

                Text('Password Baru', style: GoogleFonts.poppins(color: AppColors.lightGrey, fontSize: 13)),
                const SizedBox(height: 8),
                CustomTextField(
                  controller: _passCtrl,
                  hintText: 'Minimal 6 karakter',
                  prefixIcon: Icons.lock_outlined,
                  obscureText: _obscure1,
                  suffixIcon: IconButton(
                    icon: Icon(_obscure1 ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: AppColors.grey),
                    onPressed: () => setState(() => _obscure1 = !_obscure1),
                  ),
                  validator: (v) {
                    if (v?.isEmpty ?? true) return 'Password wajib diisi';
                    if (v!.length < 6) return 'Password minimal 6 karakter';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                Text('Konfirmasi Password', style: GoogleFonts.poppins(color: AppColors.lightGrey, fontSize: 13)),
                const SizedBox(height: 8),
                CustomTextField(
                  controller: _confirmCtrl,
                  hintText: 'Ulangi password',
                  prefixIcon: Icons.lock_outlined,
                  obscureText: _obscure2,
                  suffixIcon: IconButton(
                    icon: Icon(_obscure2 ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: AppColors.grey),
                    onPressed: () => setState(() => _obscure2 = !_obscure2),
                  ),
                  validator: (v) => v != _passCtrl.text ? 'Password tidak cocok' : null,
                ),
                const SizedBox(height: 36),

                Consumer<AuthProvider>(
                  builder: (_, auth, __) => GoldButton(
                    onPressed: auth.isLoading ? null : _resetPassword,
                    isLoading: auth.isLoading,
                    label: 'RESET PASSWORD',
                  ),
                ),
                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Kembali ke ', style: Theme.of(context).textTheme.bodyLarge),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Text('Verifikasi OTP',
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