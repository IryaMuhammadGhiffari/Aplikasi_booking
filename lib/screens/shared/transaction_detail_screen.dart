// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/booking_model.dart';
import '../../providers/booking_provider.dart';
import '../../utils/app_colors.dart';
import '../../utils/transaction_helpers.dart';
import '../../widgets/booking_status_badge.dart';
import '../../widgets/reschedule_sheet.dart';
import '../user/payment_screen.dart';

class TransactionDetailArgs {
  final bool isAdmin;
  final BookingModel? booking;
  final Map<String, dynamic>? transaction;

  const TransactionDetailArgs({
    required this.isAdmin,
    this.booking,
    this.transaction,
  });
}

class TransactionDetailScreen extends StatefulWidget {
  final TransactionDetailArgs args;

  const TransactionDetailScreen({super.key, required this.args});

  @override
  State<TransactionDetailScreen> createState() =>
      _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  late TransactionDetailData _data;
  BookingModel? _booking;
  bool _loadingAction = false;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  void _initData() {
    if (widget.args.isAdmin && widget.args.transaction != null) {
      _data =
          TransactionDetailData.fromAdminTransaction(widget.args.transaction!);
    } else if (widget.args.booking != null) {
      _booking = widget.args.booking;
      _data = TransactionDetailData.fromBooking(_booking!);
    }
  }

  Future<void> _refreshUserBooking() async {
    if (widget.args.isAdmin || _booking == null) return;
    setState(() => _refreshing = true);
    try {
      final provider = context.read<BookingProvider>();
      await provider.fetchMyBookings();
      BookingModel? updated;
      try {
        updated = provider.bookings.firstWhere((b) => b.id == _booking!.id);
      } catch (_) {}
      if (updated != null) {
        final fresh = updated;
        setState(() {
          _booking = fresh;
          _data = TransactionDetailData.fromBooking(fresh);
        });
      }
    } catch (_) {}
    setState(() => _refreshing = false);
  }

  Future<void> _pay() async {
    if (_booking == null) return;
    // Refresh data dulu agar PaymentScreen mendapat status terbaru
    setState(() => _loadingAction = true);
    if (!widget.args.isAdmin) {
      final provider = context.read<BookingProvider>();
      await provider.fetchMyBookings();
      if (!mounted) return;
      BookingModel? updated;
      try {
        updated = provider.bookings.firstWhere((b) => b.id == _booking!.id);
      } catch (_) {}
      if (updated != null) {
        _booking = updated;
        _data = TransactionDetailData.fromBooking(updated);
      }
    }
    if (!mounted) return;
    setState(() => _loadingAction = false);
    // Kalau setelah refresh booking ternyata tidak bisa bayar, beri tahu user
    if (!_booking!.canPay) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          _booking!.isAwaitingAdmin
              ? 'Booking belum dikonfirmasi admin. Silakan tunggu.'
              : 'Pembayaran tidak tersedia untuk status ini.',
          style: GoogleFonts.poppins(color: Colors.white),
        ),
        backgroundColor: AppColors.warning,
      ));
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PaymentScreen(booking: _booking!)),
    );
    await _refreshUserBooking();
  }

  Future<void> _cancel() async {
    if (_booking == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Batalkan Booking?'),
        content:
            const Text('Booking yang dibatalkan tidak dapat dikembalikan.'),
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

    setState(() => _loadingAction = true);
    final provider = context.read<BookingProvider>();
    final success = await provider.cancelBooking(_booking!.id);
    if (!mounted) return;
    setState(() => _loadingAction = false);

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(success
          ? 'Booking berhasil dibatalkan'
          : provider.error ?? 'Gagal membatalkan'),
      backgroundColor: success ? AppColors.success : AppColors.error,
    ));
    if (success) {
      await _refreshUserBooking();
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = TransactionHelpers.paymentStatusColor(
      _data.paymentStatus,
      _data.paymentMethod,
    );
    final statusLabel = TransactionHelpers.paymentStatusLabel(
      _data.paymentStatus,
      _data.paymentMethod,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Detail Transaksi'),
        actions: [
          if (!widget.args.isAdmin)
            IconButton(
              onPressed: _refreshing ? null : _refreshUserBooking,
              icon: _refreshing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.secondary))
                  : const Icon(Icons.refresh, color: AppColors.secondary),
            ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.secondary,
        onRefresh: _refreshUserBooking,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildAmountHeader(statusColor, statusLabel),
            const SizedBox(height: 16),
            if (!_data.hasPayment)
              _infoBanner(
                Icons.info_outline,
                'Transaksi pembayaran belum dibuat. Tersedia setelah booking dikonfirmasi admin.',
                AppColors.grey,
              ),
            if (!_data.hasPayment) const SizedBox(height: 12),
            _buildSection(
              title: 'Informasi Pembayaran',
              icon: Icons.receipt_long_outlined,
              children: [
                _row('Order ID', _data.orderId),
                if (_data.transactionId != null &&
                    _data.transactionId!.isNotEmpty)
                  _row('ID Transaksi', _data.transactionId!),
                _row('Status Pembayaran', statusLabel, valueColor: statusColor),
                if (_data.paymentMethod != null)
                  _row(
                      'Metode Pembayaran',
                      TransactionHelpers.formatPaymentMethod(
                          _data.paymentMethod)),
                if (_data.paidAt != null)
                  _row('Dibayar Pada',
                      TransactionHelpers.formatDateTime(_data.paidAt)),
                if (_data.createdAt != null)
                  _row('Dibuat Pada',
                      TransactionHelpers.formatDateTime(_data.createdAt)),
              ],
            ),
            const SizedBox(height: 12),
            _buildSection(
              title: 'Informasi Booking',
              icon: Icons.calendar_month_outlined,
              children: [
                _row('Kode Booking', _data.bookingCode,
                    valueColor: AppColors.secondary),
                if (widget.args.isAdmin && _data.customerName != null)
                  _row('Pelanggan', _data.customerName!),
                _row('Layanan', _data.services),
                _row('Barber', _data.barberName),
                _row('Tanggal', _data.bookingDate),
                _row('Waktu', _data.bookingTime),
                _row(
                  'Status Booking',
                  TransactionHelpers.bookingStatusLabel(_data.bookingStatus),
                ),
                _row('Total Harga',
                    TransactionHelpers.formatRp(_data.totalPrice),
                    valueColor: AppColors.secondary, isBold: true),
                if (_data.notes != null && _data.notes!.trim().isNotEmpty)
                  _notesBox(_data.notes!),
              ],
            ),
            if (!widget.args.isAdmin && _booking != null) ...[
              const SizedBox(height: 20),
              _buildUserActions(),
            ],
            if (widget.args.isAdmin) ...[
              const SizedBox(height: 20),
              _buildAdminActions(),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountHeader(Color statusColor, String statusLabel) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.goldGradient,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondary.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Total Transaksi',
              style: GoogleFonts.poppins(
                  color: AppColors.primary.withOpacity(0.7), fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            TransactionHelpers.formatRp(_data.amount),
            style: GoogleFonts.playfairDisplay(
              color: AppColors.primary,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _data.paymentStatus == 'paid'
                      ? Icons.check_circle_outline
                      : Icons.receipt_outlined,
                  color: AppColors.primary,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(statusLabel,
                    style: GoogleFonts.poppins(
                        color: AppColors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          if (!widget.args.isAdmin && _booking != null) ...[
            const SizedBox(height: 10),
            BookingStatusBadge(status: _booking!.status),
          ],
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Icon(icon, color: AppColors.secondary, size: 18),
                const SizedBox(width: 8),
                Text(title,
                    style: GoogleFonts.poppins(
                        color: AppColors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
              ],
            ),
          ),
          const Divider(color: AppColors.divider, height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value,
      {Color? valueColor, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(label,
                style:
                    GoogleFonts.poppins(color: AppColors.grey, fontSize: 12)),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.poppins(
                color: valueColor ?? AppColors.lightGrey,
                fontSize: 12,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _notesBox(String notes) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.secondary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.secondary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Catatan Pelanggan',
              style: GoogleFonts.poppins(
                  color: AppColors.secondary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(notes,
              style: GoogleFonts.poppins(
                  color: AppColors.lightGrey, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildUserActions() {
    final b = _booking!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (b.payment == null && b.isAwaitingAdmin)
          _infoBanner(
            Icons.hourglass_top,
            'Menunggu konfirmasi admin. Pembayaran tersedia setelah dikonfirmasi.',
            AppColors.warning,
          ),
        if (b.isCashlessPending)
          _infoBanner(
            Icons.payments_outlined,
            'Bayar tunai saat datang. Tunjukkan kode ${b.bookingCode} ke kasir.',
            AppColors.secondary,
          ),
        if (b.canPay) ...[
          ElevatedButton.icon(
            onPressed: _loadingAction ? null : _pay,
            icon: const Icon(Icons.payment, color: Colors.black),
            label: Text('BAYAR SEKARANG',
                style: GoogleFonts.poppins(
                    color: Colors.black, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondary,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (b.canReschedule || b.canCancel)
          Row(children: [
            if (b.canReschedule)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _loadingAction
                      ? null
                      : () => showRescheduleSheet(
                            context,
                            booking: b,
                            onDone: _refreshUserBooking,
                          ),
                  icon: const Icon(Icons.edit_calendar, size: 16),
                  label: const Text('Ubah Jadwal'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.secondary,
                    side: const BorderSide(color: AppColors.secondary),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            if (b.canReschedule && b.canCancel) const SizedBox(width: 10),
            if (b.canCancel)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _loadingAction ? null : _cancel,
                  icon: const Icon(Icons.cancel_outlined, size: 16),
                  label: const Text('Batalkan'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
          ]),
      ],
    );
  }

  Widget _buildAdminActions() {
    final isCashless = _data.paymentMethod == 'cashless';

    // Cashless auto-paid sejak Juni 2026 — tidak perlu konfirmasi admin
    if (isCashless) return const SizedBox();

    if (_data.paymentStatus != 'pending') return const SizedBox();

    return _infoBanner(
      Icons.sync,
      'Menunggu pembayaran online dari pelanggan.',
      AppColors.warning,
    );
  }

  Widget _infoBanner(IconData icon, String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: GoogleFonts.poppins(color: color, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
