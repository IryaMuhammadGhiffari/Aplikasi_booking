import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/booking_provider.dart';
import '../../providers/service_provider.dart';
import '../../providers/barber_provider.dart';
import '../../providers/admin_booking_provider.dart';
import '../../providers/admin_transaction_provider.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_routes.dart';
import '../../utils/saved_accounts.dart';
import '../../widgets/gold_button.dart';
import '../../widgets/custom_text_field.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _obscure = true;
  List<SavedAccount> _savedAccounts = [];

  @override
  void initState() {
    super.initState();
    _loadSavedAccounts();
  }

  Future<void> _loadSavedAccounts() async {
    try {
      final accounts = await SavedAccounts.load();
      if (!mounted) return;
      setState(() => _savedAccounts = accounts);
    } catch (_) {}
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final success = await auth.login(
      _emailCtrl.text.trim(),
      _passwordCtrl.text,
    );

    if (!mounted) return;

    if (success) {
      // Simpan akun untuk login cepat berikutnya
      final user = auth.user;
      if (user != null) {
        await SavedAccounts.save(user.email, user.name);
      }
      _prefetchData(); // fire & forget — data siap ketika screen terbuka
      if (!mounted) return;
      Navigator.pushReplacementNamed(
        context,
        auth.isAdmin ? AppRoutes.adminDashboard : AppRoutes.home,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(auth.errorMessage ?? 'Login gagal'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  /// Pre-fetch data di background agar langsung siap ketika screen terbuka.
  void _prefetchData() {
    final isAdmin = context.read<AuthProvider>().isAdmin;
    if (isAdmin) {
      context.read<AdminBookingProvider>().fetch();
      context.read<AdminTransactionProvider>().fetchTransactions();
    } else {
      context.read<BookingProvider>().fetchMyBookings();
      context.read<ServiceProvider>().fetchServices();
      context.read<BarberProvider>().fetchBarbers();
    }
  }

  Widget _buildSavedAccounts(List<SavedAccount> accounts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Akun Tersimpan',
            style: GoogleFonts.poppins(
                color: AppColors.lightGrey,
                fontSize: 12,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 10),
        SizedBox(
          height: 56,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: accounts.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final acc = accounts[i];
              final initial = acc.name.isNotEmpty
                  ? acc.name[0].toUpperCase()
                  : acc.email[0].toUpperCase();
              return GestureDetector(
                onTap: () {
                  _emailCtrl.text = acc.email;
                  // Fokus ke password
                  _passwordFocus.requestFocus();
                  setState(() {});
                },
                onLongPress: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      backgroundColor: AppColors.surface,
                      title: Text('Hapus akun?',
                          style: GoogleFonts.poppins(
                              color: AppColors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15)),
                      content: Text(
                        'Hapus ${acc.email} dari daftar?',
                        style: GoogleFonts.poppins(
                            color: AppColors.grey, fontSize: 13),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: Text('Batal',
                              style:
                                  GoogleFonts.poppins(color: AppColors.grey)),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: Text('Hapus',
                              style:
                                  GoogleFonts.poppins(color: AppColors.error)),
                        ),
                      ],
                    ),
                  );
                  if (ok == true) {
                    await SavedAccounts.remove(acc.email);
                    await _loadSavedAccounts();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor:
                            AppColors.secondary.withOpacity(0.2),
                        child: Text(initial,
                            style: GoogleFonts.poppins(
                                color: AppColors.secondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 100),
                            child: Text(acc.name,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                    color: AppColors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500)),
                          ),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 100),
                            child: Text(acc.email,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                    color: AppColors.grey, fontSize: 10)),
                          ),
                        ],
                      ),
                      const SizedBox(width: 4),
                      if (_emailCtrl.text == acc.email)
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check,
                              color: AppColors.secondary, size: 12),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D0D0D), Color(0xFF1A1A1A), Color(0xFF121212)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 32),
                _buildHeader(),
                const SizedBox(height: 28),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(22, 28, 22, 28),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.divider),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Masuk',
                            style: GoogleFonts.playfairDisplay(
                              color: AppColors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Gunakan email dan password terdaftar',
                            style: GoogleFonts.poppins(
                              color: AppColors.grey,
                              fontSize: 12,
                            ),
                          ),
                          // ── Akun tersimpan ──
                          if (_savedAccounts.isNotEmpty) ...[
                            _buildSavedAccounts(_savedAccounts),
                            const SizedBox(height: 24),
                          ],
                          Text(
                            'Email',
                            style: GoogleFonts.poppins(
                              color: AppColors.lightGrey,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          CustomTextField(
                            controller: _emailCtrl,
                            hintText: 'nama@email.com',
                            prefixIcon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Email wajib diisi';
                              }
                              if (!v.contains('@')) {
                                return 'Format email tidak valid';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'Password',
                            style: GoogleFonts.poppins(
                              color: AppColors.lightGrey,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          CustomTextField(
                            controller: _passwordCtrl,
                            hintText: '••••••••',
                            prefixIcon: Icons.lock_outlined,
                            obscureText: _obscure,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: AppColors.grey,
                              ),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Password wajib diisi';
                              }
                              if (v.length < 6) {
                                return 'Password minimal 6 karakter';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 28),
                          Consumer<AuthProvider>(
                            builder: (_, auth, __) => GoldButton(
                              onPressed: auth.isLoading ? null : _login,
                              isLoading: auth.isLoading,
                              label: 'MASUK',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Belum punya akun? ',
                      style: GoogleFonts.poppins(
                        color: AppColors.grey,
                        fontSize: 14,
                      ),
                    ),
                    GestureDetector(
                      onTap: () =>
                          Navigator.pushNamed(context, AppRoutes.register),
                      child: Text(
                        'Daftar',
                        style: GoogleFonts.poppins(
                          color: AppColors.secondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
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

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            gradient: AppColors.goldGradient,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: AppColors.secondary.withValues(alpha: 0.35),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(
            Icons.content_cut_rounded,
            color: AppColors.primary,
            size: 42,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Arfan Barbershop',
          style: GoogleFonts.playfairDisplay(
            color: AppColors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Gaya rapi, percaya diri',
          style: GoogleFonts.poppins(
            color: AppColors.lightGrey,
            fontSize: 13,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}
