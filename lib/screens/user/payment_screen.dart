// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/booking_model.dart';
import '../../providers/booking_provider.dart';
import '../../utils/app_colors.dart';
import '../../utils/extensions.dart';
import '../../utils/app_routes.dart';
import '../../widgets/gold_button.dart';
import '../../widgets/midtrans_payment_webview.dart';
import '../../widgets/payment_success_view.dart';

/// Layar pembayaran — hanya untuk booking yang sudah dikonfirmasi admin.
class PaymentScreen extends StatefulWidget {
  final BookingModel booking;
  const PaymentScreen({super.key, required this.booking});
  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _loadingPayment = false;
  bool _loadingCashless = false;
  bool _showWebView = false;
  bool _showSuccess = false;
  String? _snapUrl;
  late BookingModel _booking;

  @override
  void initState() {
    super.initState();
    _booking = widget.booking;
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkInitialStatus());
  }

  Future<void> _checkInitialStatus() async {
    if (_booking.isPaid) {
      setState(() => _showSuccess = true);
      return;
    }
    if (_booking.isCashlessPending) {
      if (!mounted) return;
      Navigator.pop(context);
      return;
    }
    if (!_booking.canPayGateway) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Pembayaran belum tersedia. Tunggu konfirmasi admin terlebih dahulu.'),
        backgroundColor: AppColors.warning,
      ));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      switchInCurve: Curves.easeInOut,
      switchOutCurve: Curves.easeInOut,
      child: _buildScreen(context),
    );
  }

  Widget _buildScreen(BuildContext context) {
    if (_showSuccess) {
      return PaymentSuccessView(
        key: const ValueKey('success'),
        bookingCode: _booking.bookingCode,
        onDone: () {
          Navigator.pushNamedAndRemoveUntil(
            context,
            AppRoutes.home,
            (_) => false,
            arguments: 2,
          );
        },
      );
    }

    if (!_booking.canPayGateway) {
      return const Scaffold(
        key: ValueKey('loading'),
        body: Center(
          child: CircularProgressIndicator(color: AppColors.secondary),
        ),
      );
    }

    return _showWebView ? _buildWebView() : _buildDetail();
  }

  Widget _buildDetail() {
    final b = _booking;

    return Scaffold(
      key: const ValueKey('detail'),
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Pembayaran'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.verified,
                    color: AppColors.success, size: 32),
              ),
              const SizedBox(height: 14),
              Text(
                'Booking Dikonfirmasi',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'Pilih metode pembayaran',
                style: GoogleFonts.poppins(color: AppColors.grey, fontSize: 12),
              ),
              const SizedBox(height: 6),
              Text(
                b.bookingCode,
                style: GoogleFonts.poppins(
                  color: AppColors.secondary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(children: [
              _detailRow('Layanan', b.servicesDisplay),
              _detailRow('Barber', b.barber?.name ?? '-'),
              _detailRow('Tanggal', b.bookingDate.formattedDate),
              _detailRow('Waktu', b.timeDisplay),
              const Divider(color: AppColors.divider),
              _detailRow('Total', b.priceFormatted, isTotal: true),
            ]),
          ),
          const Spacer(),
          GoldButton(
            onPressed: _loadingPayment ? null : _startPayment,
            isLoading: _loadingPayment,
            label: 'BAYAR VIA MIDTRANS',
            icon: Icons.payment,
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _loadingCashless ? null : _chooseCashless,
            icon: _loadingCashless
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.secondary),
                  )
                : const Icon(Icons.storefront_outlined,
                    color: AppColors.secondary),
            label: Text(
              'BAYAR DI TEMPAT (TUNAI)',
              style: GoogleFonts.poppins(
                color: AppColors.secondary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              side: const BorderSide(color: AppColors.secondary),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildWebView() {
    return MidtransPaymentWebView(
      key: const ValueKey('webview'),
      bookingId: _booking.id,
      initialSnapUrl: _snapUrl!,
      onClose: () {
        setState(() => _showWebView = false);
        // Verifikasi pembayaran ketika user tutup WebView
        _onPaymentDone(success: true);
      },
      onPaymentFinished: (success) => _onPaymentDone(success: success),
    );
  }

  Future<void> _chooseCashless() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Bayar di Tempat?',
            style: GoogleFonts.poppins(
                color: AppColors.white, fontWeight: FontWeight.bold)),
        content: Text(
          'Kamu akan membayar tunai saat datang ke Arfan Barbershop. '
          'Tunjukkan kode booking ${_booking.bookingCode} ke kasir.',
          style: GoogleFonts.poppins(color: AppColors.grey, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Batal',
                style: GoogleFonts.poppins(color: AppColors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ya, Bayar di Tempat'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _loadingCashless = true);
    final success =
        await context.read<BookingProvider>().chooseCashless(_booking.id);
    setState(() => _loadingCashless = false);
    if (!mounted) return;

    if (success) {
      await context.read<BookingProvider>().fetchMyBookings();
      if (!mounted) return;
      // Langsung balik ke home — user belum bayar, hanya booking dikonfirmasi
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            'Booking dikonfirmasi. Bayar tunai saat datang ke barbershop.',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ));
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.home,
          (_) => false,
          arguments: 2,
        );
      }
      return;
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.read<BookingProvider>().error ?? 'Gagal'),
        backgroundColor: AppColors.error,
      ));
    }
  }

  Future<void> _startPayment() async {
    setState(() => _loadingPayment = true);

    final bp = context.read<BookingProvider>();
    Map<String, dynamic>? data;
    for (var attempt = 0; attempt < 3; attempt++) {
      if (!mounted) return;
      data = await bp.createPayment(_booking.id);
      if (data != null) break;
      if (attempt < 2) await Future.delayed(const Duration(seconds: 2));
    }

    setState(() => _loadingPayment = false);

    if (data == null || !mounted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(context.read<BookingProvider>().error ??
              'Gagal memuat pembayaran'),
          backgroundColor: AppColors.error,
        ));
      }
      return;
    }

    final snapUrl = data['snap_url'] as String?;
    if (snapUrl == null) return;

    setState(() {
      _snapUrl = snapUrl;
      _showWebView = true;
    });
  }

  Future<void> _onPaymentDone({required bool success}) async {
    if (!mounted) return;

    // WebView sudah verify via polling + timeout, tinggal cek sekali
    final isPaid = success
        ? await context.read<BookingProvider>().verifyBookingPaid(_booking.id)
        : false;

    if (!mounted) return;

    setState(() => _showWebView = false);

    if (isPaid) {
      await context.read<BookingProvider>().fetchMyBookings();
      if (!mounted) return;
      setState(() => _showSuccess = true);
    }
    // Jika belum paid, kembali ke detail pembayaran (silent)
  }

  Widget _detailRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label,
            style: GoogleFonts.poppins(color: AppColors.grey, fontSize: 13)),
        Flexible(
          child: Text(value,
              textAlign: TextAlign.end,
              style: GoogleFonts.poppins(
                color: isTotal ? AppColors.secondary : AppColors.white,
                fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
                fontSize: isTotal ? 16 : 13,
              )),
        ),
      ]),
    );
  }
}
