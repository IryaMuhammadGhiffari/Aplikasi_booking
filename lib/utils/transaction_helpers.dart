import 'package:flutter/material.dart';
import '../models/booking_model.dart';
import 'app_colors.dart';

class TransactionDetailData {
  final int? paymentId;
  final String orderId;
  final String? transactionId;
  final double amount;
  final String paymentStatus;
  final String? paymentMethod;
  final String? paidAt;
  final String? createdAt;

  final int bookingId;
  final String bookingCode;
  final String services;
  final String barberName;
  final String bookingDate;
  final String bookingTime;
  final String bookingStatus;
  final String? notes;
  final double totalPrice;

  final String? customerName;

  const TransactionDetailData({
    this.paymentId,
    required this.orderId,
    this.transactionId,
    required this.amount,
    required this.paymentStatus,
    this.paymentMethod,
    this.paidAt,
    this.createdAt,
    required this.bookingId,
    required this.bookingCode,
    required this.services,
    required this.barberName,
    required this.bookingDate,
    required this.bookingTime,
    required this.bookingStatus,
    this.notes,
    required this.totalPrice,
    this.customerName,
  });

  bool get hasPayment => paymentId != null;

  factory TransactionDetailData.fromBooking(BookingModel booking) {
    final payment = booking.payment;
    return TransactionDetailData(
      paymentId: payment?.id,
      orderId: payment?.orderId ?? '-',
      transactionId: payment?.transactionId,
      amount: payment?.amount ?? booking.totalPrice,
      paymentStatus: payment?.status ?? 'none',
      paymentMethod: payment?.paymentMethod,
      paidAt: payment?.paidAt,
      createdAt: booking.createdAt,
      bookingId: booking.id,
      bookingCode: booking.bookingCode,
      services: booking.servicesDisplay,
      barberName: booking.barber?.name ?? '-',
      bookingDate: booking.bookingDateFormatted,
      bookingTime: booking.timeDisplay,
      bookingStatus: booking.status,
      notes: booking.notes,
      totalPrice: booking.totalPrice,
    );
  }

  factory TransactionDetailData.fromAdminTransaction(Map transaction) {
    final booking = transaction['booking'] as Map?;
    final services = booking?['services'] as List?;
    final serviceNames = (services != null && services.isNotEmpty)
        ? services.map((s) => s['name']).join(', ')
        : (booking?['service']?['name']?.toString() ?? '-');
    final time = (booking?['booking_time'] as String? ?? '');
    final timeShort = time.length >= 5 ? time.substring(0, 5) : time;

    return TransactionDetailData(
      paymentId: transaction['id'] as int?,
      orderId: transaction['order_id']?.toString() ?? '-',
      transactionId: transaction['transaction_id']?.toString(),
      amount: double.tryParse(transaction['amount']?.toString() ?? '0') ?? 0,
      paymentStatus: transaction['status']?.toString() ?? 'none',
      paymentMethod: transaction['payment_method']?.toString(),
      paidAt: transaction['paid_at']?.toString(),
      createdAt: transaction['created_at']?.toString(),
      bookingId: booking?['id'] as int? ?? 0,
      bookingCode: booking?['booking_code']?.toString() ?? '-',
      services: serviceNames,
      barberName: booking?['barber']?['name']?.toString() ?? '-',
      bookingDate: TransactionHelpers.formatDate(booking?['booking_date']?.toString()),
      bookingTime: timeShort,
      bookingStatus: booking?['status']?.toString() ?? '-',
      notes: booking?['notes']?.toString(),
      totalPrice:
          double.tryParse(booking?['total_price']?.toString() ?? '0') ?? 0,
      customerName: booking?['user']?['name']?.toString(),
    );
  }
}

class TransactionHelpers {
  static String formatRp(double value) =>
      'Rp ${value.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';

  static String formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '-';
    try {
      final d = DateTime.parse(raw);
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'Mei',
        'Jun',
        'Jul',
        'Agu',
        'Sep',
        'Okt',
        'Nov',
        'Des'
      ];
      return '${d.day} ${months[d.month - 1]} ${d.year}';
    } catch (_) {
      return raw;
    }
  }

  static String formatDateTime(String? raw) {
    if (raw == null || raw.isEmpty) return '-';
    try {
      final d = DateTime.parse(raw);
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'Mei',
        'Jun',
        'Jul',
        'Agu',
        'Sep',
        'Okt',
        'Nov',
        'Des'
      ];
      final hour = d.hour.toString().padLeft(2, '0');
      final minute = d.minute.toString().padLeft(2, '0');
      return '${d.day} ${months[d.month - 1]} ${d.year}, $hour:$minute';
    } catch (_) {
      return raw;
    }
  }

  static String formatPaymentMethod(String? method) {
    if (method == null || method.isEmpty) return '-';
    const labels = {
      'credit_card': 'Kartu Kredit',
      'bank_transfer': 'Transfer Bank',
      'echannel': 'Mandiri Bill',
      'bca_va': 'BCA Virtual Account',
      'bni_va': 'BNI Virtual Account',
      'bri_va': 'BRI Virtual Account',
      'permata_va': 'Permata Virtual Account',
      'other_va': 'Virtual Account',
      'gopay': 'GoPay',
      'shopeepay': 'ShopeePay',
      'qris': 'QRIS',
      'cstore': 'Alfamart/Indomaret',
      'cashless': 'Bayar di Tempat (Tunai)',
    };
    return labels[method] ?? method.replaceAll('_', ' ');
  }

  static String paymentStatusLabel(String status, String? method) {
    switch (status) {
      case 'paid':
        return 'Dibayar';
      case 'pending':
        return 'Menunggu Pembayaran';
      case 'expired':
        return 'Kadaluarsa';
      case 'failed':
        return 'Gagal';
      case 'none':
        return 'Belum Ada';
      default:
        return status;
    }
  }

  static String bookingStatusLabel(String status) {
    const labels = {
      'pending': 'Menunggu',
      'confirmed': 'Dikonfirmasi',
      'in_progress': 'Sedang Dikerjakan',
      'completed': 'Selesai',
      'cancelled': 'Dibatalkan',
    };
    return labels[status] ?? status;
  }

  static Color paymentStatusColor(String status, String? method) {
    switch (status) {
      case 'paid':
        return AppColors.success;
      case 'pending':
        return AppColors.warning;
      case 'expired':
      case 'failed':
        return AppColors.error;
      case 'none':
        return AppColors.grey;
      default:
        return AppColors.error;
    }
  }
}
