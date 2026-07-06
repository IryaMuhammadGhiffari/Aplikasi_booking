// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/booking_model.dart';
import '../../providers/booking_provider.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_routes.dart';
import '../shared/transaction_detail_screen.dart';
import '../../widgets/booking_status_badge.dart';
import '../../widgets/gold_button.dart';
import '../../widgets/booking_confirmed_dialog.dart';
import '../../widgets/reschedule_sheet.dart';
import '../../widgets/shimmer_loading.dart';
import 'payment_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  // Timer.periodic telah dihapus — refresh via HomeScreen saja

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Riwayat Booking')),
      body: Consumer<BookingProvider>(
        builder: (_, provider, __) {
          if (provider.isLoading && provider.bookings.isEmpty) {
            return const ShimmerList(
              itemBuilder: ShimmerBookingCard.new,
              count: 5,
            );
          }

          if (provider.bookings.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: const Icon(Icons.calendar_today_outlined,
                        size: 36, color: AppColors.grey),
                  ),
                  const SizedBox(height: 20),
                  Text('Belum ada booking',
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 8),
                  Text('Buat booking pertamamu sekarang!',
                      style: GoogleFonts.poppins(
                          color: AppColors.grey, fontSize: 13),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  GoldButton(
                    onPressed: () =>
                        Navigator.pushNamed(context, AppRoutes.booking),
                    label: 'BUAT BOOKING',
                    icon: Icons.add,
                  ),
                ]),
              ),
            );
          }

          return RefreshIndicator(
            color: AppColors.secondary,
            onRefresh: () async {
              await provider.fetchMyBookings();
              if (!context.mounted) return;
              final confirmed = provider.takeNewlyConfirmedBooking();
              if (confirmed != null) {
                await showBookingConfirmedDialog(context, confirmed);
              }
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: provider.bookings.length,
              itemBuilder: (_, i) => _HistoryCard(
                booking: provider.bookings[i],
                onRefresh: () => provider.fetchMyBookings(),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HistoryCard extends StatefulWidget {
  final BookingModel booking;
  final VoidCallback onRefresh;
  const _HistoryCard({required this.booking, required this.onRefresh});

  @override
  State<_HistoryCard> createState() => _HistoryCardState();
}

class _HistoryCardState extends State<_HistoryCard> {
  bool _loadingCancel = false;

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    final paymentStatus = b.payment?.status ?? '';
    final paymentColor = paymentStatus == 'paid'
        ? AppColors.success
        : paymentStatus == 'failed' || paymentStatus == 'expired'
            ? AppColors.error
            : AppColors.warning;
    final paymentLabel = b.paymentStatusLabel;

    return GestureDetector(
      onTap: () async {
        await Navigator.pushNamed(
          context,
          AppRoutes.transactionDetail,
          arguments: TransactionDetailArgs(
            isAdmin: false,
            booking: b,
          ),
        );
        widget.onRefresh();
      },
      child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(b.bookingCode,
                style: GoogleFonts.poppins(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
            BookingStatusBadge(status: b.status),
          ]),
          const Divider(color: AppColors.divider),

          if (b.isAwaitingAdmin) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.warning.withOpacity(0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.hourglass_top,
                    color: AppColors.warning, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Menunggu konfirmasi admin. Bayar setelah dikonfirmasi.',
                    style: GoogleFonts.poppins(
                        color: AppColors.warning, fontSize: 11),
                  ),
                ),
              ]),
            ),
          ],

          Text(b.servicesDisplay,
              style: GoogleFonts.poppins(
                  color: AppColors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 15)),
          const SizedBox(height: 6),

          Row(children: [
            const Icon(Icons.person, color: AppColors.grey, size: 14),
            const SizedBox(width: 4),
            Text(b.barber?.name ?? '-',
                style:
                    GoogleFonts.poppins(color: AppColors.grey, fontSize: 12)),
          ]),
          const SizedBox(height: 2),

          Row(children: [
            const Icon(Icons.calendar_today, color: AppColors.grey, size: 14),
            const SizedBox(width: 4),
            Text('${b.bookingDateFormatted}  pukul ${b.timeDisplay}',
                style:
                    GoogleFonts.poppins(color: AppColors.grey, fontSize: 12)),
          ]),
          const SizedBox(height: 8),

          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            if (b.payment != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: paymentColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: paymentColor.withOpacity(0.3)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                      paymentStatus == 'paid'
                          ? Icons.check_circle
                          : Icons.payment,
                      color: paymentColor,
                      size: 12),
                  const SizedBox(width: 4),
                  Text(paymentLabel,
                      style: GoogleFonts.poppins(
                          color: paymentColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w600)),
                ]),
              )
            else if (b.isAwaitingAdmin)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Menunggu Admin',
                    style: GoogleFonts.poppins(
                        color: AppColors.warning,
                        fontSize: 10,
                        fontWeight: FontWeight.w600)),
              )
            else
              const SizedBox(),
            Text(b.priceFormatted,
                style: GoogleFonts.poppins(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.bold,
                    fontSize: 15)),
          ]),

          if (b.canPay ||
              b.isCashlessPending ||
              b.canReschedule ||
              b.canCancel) ...[
            const SizedBox(height: 12),
            const Divider(color: AppColors.divider, height: 1),
            const SizedBox(height: 10),
            if (b.isCashlessPending)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.secondary.withOpacity(0.3)),
                ),
                child: Text(
                  'Bayar tunai saat datang. Tunjukkan kode ${b.bookingCode} ke kasir.',
                  style: GoogleFonts.poppins(
                    color: AppColors.secondary,
                    fontSize: 11,
                  ),
                  textAlign: TextAlign.center,
                ),
              )
            else if (b.canPay)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _bayar,
                  icon: const Icon(Icons.payment, size: 16, color: Colors.black),
                  label: Text('BAYAR SEKARANG',
                      style: GoogleFonts.poppins(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            if (b.canReschedule || b.canCancel) ...[
              if (b.canPay) const SizedBox(height: 8),
              Row(children: [
                if (b.canReschedule)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => showRescheduleSheet(
                        context,
                        booking: b,
                        onDone: widget.onRefresh,
                      ),
                      icon: const Icon(Icons.edit_calendar, size: 14),
                      label: const Text('Ubah Jadwal'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.secondary,
                        side: const BorderSide(color: AppColors.secondary),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                if (b.canReschedule && b.canCancel)
                  const SizedBox(width: 8),
                if (b.canCancel)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _loadingCancel ? null : _cancel,
                      icon: _loadingCancel
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppColors.error))
                          : const Icon(Icons.cancel_outlined, size: 14),
                      label: Text(_loadingCancel ? '...' : 'Batalkan'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
              ]),
            ],
          ],
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('Lihat detail transaksi',
                  style: GoogleFonts.poppins(
                      color: AppColors.secondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600)),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right,
                  color: AppColors.secondary, size: 14),
            ],
          ),
        ]),
      ),
    ),
    );
  }

  Future<void> _cancel() async {
    final isPaid = widget.booking.isPaid;
    String? cancelReason;

    if (isPaid) {
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (ctx) => _CancelWithReasonDialog(),
      );
      if (result == null || !mounted) return;
      cancelReason = result['reason'] as String?;
    } else {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Batalkan Booking?'),
          content: const Text('Booking yang dibatalkan tidak dapat dikembalikan.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Tidak')),
            TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Ya, Batalkan',
                    style: TextStyle(color: AppColors.error))),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }

    setState(() => _loadingCancel = true);
    final provider = context.read<BookingProvider>();
    final success = await provider.cancelBooking(widget.booking.id,
        cancelReason: cancelReason);
    if (!mounted) return;
    setState(() => _loadingCancel = false);

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(success
          ? (isPaid
              ? 'Booking dibatalkan. Dana akan dikembalikan.'
              : 'Booking berhasil dibatalkan')
          : provider.error ?? 'Gagal membatalkan'),
      backgroundColor: success ? AppColors.success : AppColors.error,
      behavior: SnackBarBehavior.floating,
    ));
    if (success) widget.onRefresh();
  }

  Future<void> _bayar() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentScreen(booking: widget.booking),
      ),
    );
    widget.onRefresh();
  }
}

/// Dialog alasan pembatalan — wajib diisi untuk booking yang sudah dibayar.
class _CancelWithReasonDialog extends StatefulWidget {
  @override
  State<_CancelWithReasonDialog> createState() =>
      _CancelWithReasonDialogState();
}

class _CancelWithReasonDialogState extends State<_CancelWithReasonDialog> {
  final _controller = TextEditingController();
  bool _submitted = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Batalkan Booking?',
          style: GoogleFonts.poppins(
              color: AppColors.white, fontWeight: FontWeight.bold)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Booking sudah dibayar. Dana akan dikembalikan (refund).',
            style: GoogleFonts.poppins(color: AppColors.grey, fontSize: 13)),
        const SizedBox(height: 14),
        TextField(
          controller: _controller,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Alasan pembatalan (wajib) *',
            hintStyle: GoogleFonts.poppins(color: AppColors.grey, fontSize: 13),
            filled: true,
            fillColor: AppColors.background,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.secondary, width: 1.5)),
            errorText: _submitted && _controller.text.trim().isEmpty
                ? 'Alasan wajib diisi'
                : null,
            errorStyle: GoogleFonts.poppins(color: AppColors.error, fontSize: 11),
          ),
          style: GoogleFonts.poppins(color: AppColors.white, fontSize: 13),
          textCapitalization: TextCapitalization.sentences,
        ),
      ]),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Tidak',
              style: GoogleFonts.poppins(color: AppColors.grey)),
        ),
        ElevatedButton(
          onPressed: () {
            final reason = _controller.text.trim();
            if (reason.isEmpty) {
              setState(() => _submitted = true);
              return;
            }
            Navigator.pop(context, {'reason': reason});
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: Colors.white,
          ),
          child: Text('Ya, Batalkan',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
