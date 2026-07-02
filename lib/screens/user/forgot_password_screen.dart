import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_routes.dart';
import '../../widgets/gold_button.dart';
import '../../widgets/custom_text_field.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final success = await auth.forgotPassword(_emailCtrl.text.trim());

    if (!mounted) return;

    if (success) {
      Navigator.pushNamed(
        context,
        AppRoutes.verifyOtp,
        arguments: _emailCtrl.text.trim(),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(auth.errorMessage ?? 'Gagal mengirim OTP'),
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
                Text('Lupa Password', style: Theme.of(context).textTheme.displayMedium),
                const SizedBox(height: 6),
                Text('Masukkan email terdaftar untuk menerima kode OTP via WhatsApp',
                    style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 32),

                Text('Email', style: GoogleFonts.poppins(color: AppColors.lightGrey, fontSize: 13)),
                const SizedBox(height: 8),
                CustomTextField(
                  controller: _emailCtrl,
                  hintText: 'email@kamu.com',
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v?.isEmpty ?? true) return 'Email wajib diisi';
                    if (!v!.contains('@')) return 'Format email tidak valid';
                    return null;
                  },
                ),
                const SizedBox(height: 36),

                Consumer<AuthProvider>(
                  builder: (_, auth, __) => GoldButton(
                    onPressed: auth.isLoading ? null : _sendOtp,
                    isLoading: auth.isLoading,
                    label: 'KIRIM KODE OTP',
                  ),
                ),
                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Ingat password? ', style: Theme.of(context).textTheme.bodyLarge),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Text('Kembali Login',
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