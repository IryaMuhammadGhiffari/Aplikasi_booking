import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/booking_model.dart';
import '../../providers/booking_provider.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_routes.dart';
import '../../widgets/gold_button.dart';

/// Ditampilkan setelah user berhasil membuat booking (status pending).
/// Polling tiap 15s untuk deteksi otomatis jika admin sudah konfirmasi,
/// lalu menampilkan tombol bayar.
class BookingSubmittedScreen extends StatefulWidget {
  final BookingModel booking;

  const BookingSubmittedScreen({super.key, required this.booking});

  @override
  State<BookingSubmittedScreen> createState() => _BookingSubmittedScreenState();
}

class _BookingSubmittedScreenState extends State<BookingSubmittedScreen> {
  bool _isConfirmed = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Seed the provider so it can track status changes
    context.read<BookingProvider>().seedBookingStatus(widget.booking);
    _startPolling();
  }

  void _startPolling() {
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      context.read<BookingProvider>().fetchMyBookings();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatTgl(String raw) {
    try {
      final d = DateTime.parse(raw);
      const m = [
        'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
        'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
      ];
      return '${d.day} ${m[d.month - 1]} ${d.year}';
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen for newly confirmed bookings from the provider
    final provider = context.watch<BookingProvider>();
    final newlyConfirmed = provider.takeNewlyConfirmedBooking();
    if (newlyConfirmed != null && newlyConfirmed.id == widget.booking.id) {
      // Defer to avoid build-during-build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _isConfirmed = true);
      });
    }

    final booking = widget.booking;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Booking Dikirim'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(children: [
          // ── Status card ──
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
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: (_isConfirmed ? AppColors.success : AppColors.warning)
                      .withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isConfirmed ? Icons.check_circle_rounded : Icons.send_rounded,
                  color: _isConfirmed ? AppColors.success : AppColors.warning,
                  size: 36,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                _isConfirmed ? 'Booking Disetujui!' : 'Booking Berhasil Dikirim!',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                booking.bookingCode,
                style: GoogleFonts.poppins(
                  color: AppColors.secondary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ]),
          ),
          const SizedBox(height: 20),

          // ── Step indicator ──
          _buildStep(
            step: 1,
            title: 'Booking dibuat',
            subtitle: 'Permintaan jadwal sudah masuk ke sistem',
            done: true,
            active: false,
          ),
          _buildStep(
            step: 2,
            title: 'Konfirmasi admin',
            subtitle: _isConfirmed
                ? 'Booking sudah disetujui'
                : 'Admin meninjau ketersediaan barber & jadwal',
            done: _isConfirmed,
            active: !_isConfirmed,
          ),
          _buildStep(
            step: 3,
            title: 'Pembayaran',
            subtitle: _isConfirmed
                ? 'Selesaikan pembayaran untuk konfirmasi'
                : 'Tombol bayar muncul setelah booking dikonfirmasi',
            done: false,
            active: _isConfirmed,
            locked: !_isConfirmed,
          ),
          const SizedBox(height: 16),

          // ── Info banner ──
          AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: (_isConfirmed ? AppColors.success : AppColors.warning)
                  .withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (_isConfirmed ? AppColors.success : AppColors.warning)
                    .withOpacity(0.35),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, anim) =>
                      ScaleTransition(scale: anim, child: child),
                  child: Icon(
                    key: ValueKey(_isConfirmed),
                    _isConfirmed
                        ? Icons.check_circle_outline
                        : Icons.notifications_active_outlined,
                    color: _isConfirmed ? AppColors.success : AppColors.warning,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      key: ValueKey(_isConfirmed),
                      _isConfirmed
                          ? 'Booking sudah disetujui! Tekan tombol bayar untuk menyelesaikan pembayaran.'
                          : 'Tunggu konfirmasi admin. Halaman ini akan otomatis memperbarui status.',
                      style: GoogleFonts.poppins(
                        color: _isConfirmed ? AppColors.success : AppColors.warning,
                        fontSize: 11,
                        height: 1.45,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Payment button (visible only after confirmed) ──
          if (_isConfirmed) ...[
            const SizedBox(height: 16),
            GoldButton(
              onPressed: () => Navigator.pushNamed(
                context,
                AppRoutes.payment,
                arguments: booking,
              ),
              label: 'LANJUTKAN KE PEMBAYARAN',
              icon: Icons.payment_outlined,
            ),
          ],

          const SizedBox(height: 16),

          // ── Booking details ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(children: [
              _detailRow('Layanan', booking.servicesDisplay),
              _detailRow('Barber', booking.barber?.name ?? '-'),
              _detailRow('Tanggal', _formatTgl(booking.bookingDate)),
              _detailRow('Waktu', booking.timeDisplay),
              const Divider(color: AppColors.divider),
              _detailRow('Total', booking.priceFormatted, isTotal: true),
            ]),
          ),
          const SizedBox(height: 24),
          GoldButton(
            onPressed: () => Navigator.pushNamedAndRemoveUntil(
              context,
              AppRoutes.home,
              (_) => false,
            ),
            label: 'KE BERANDA',
            icon: Icons.home_outlined,
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => Navigator.pushNamedAndRemoveUntil(
              context,
              AppRoutes.home,
              (_) => false,
              arguments: 2,
            ),
            child: Text(
              'Lihat Riwayat Booking',
              style: GoogleFonts.poppins(
                color: AppColors.secondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildStep({
    required int step,
    required String title,
    required String subtitle,
    required bool done,
    required bool active,
    bool locked = false,
  }) {
    final color = done
        ? AppColors.success
        : active
            ? AppColors.secondary
            : AppColors.grey;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.5)),
            ),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, anim) =>
                    FadeTransition(opacity: anim, child: child),
                child: done
                    ? Icon(Icons.check, key: const ValueKey('done'), size: 14, color: color)
                    : locked
                        ? Icon(Icons.lock_outline, key: const ValueKey('locked'), size: 12, color: color)
                        : Text(
                            '$step',
                            key: ValueKey('step_$step'),
                            style: GoogleFonts.poppins(
                              color: color,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    color: active || done ? AppColors.white : AppColors.grey,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    color: AppColors.grey,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.poppins(color: AppColors.grey, fontSize: 12)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: GoogleFonts.poppins(
                color: isTotal ? AppColors.secondary : AppColors.white,
                fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
                fontSize: isTotal ? 15 : 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
