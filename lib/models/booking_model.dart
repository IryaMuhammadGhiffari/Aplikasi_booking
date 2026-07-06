// ignore_for_file: avoid_print

import 'barber_model.dart';
import 'service_model.dart';
import 'payment_model.dart';

class BookingModel {
  final int id;
  final String bookingCode;
  final int userId;
  final BarberModel? barber;
  final List<ServiceModel> services;
  final String bookingDate;
  final String bookingTime;
  final double totalPrice;
  final String status;
  final String? notes;
  final PaymentModel? payment;
  final String? createdAt;

  BookingModel({
    required this.id,
    required this.bookingCode,
    required this.userId,
    this.barber,
    this.services = const [],
    required this.bookingDate,
    required this.bookingTime,
    required this.totalPrice,
    required this.status,
    this.notes,
    this.payment,
    this.createdAt,
  });

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    List<ServiceModel> parsedServices = [];
    if (json['services'] != null) {
      parsedServices = (json['services'] as List)
          .map((s) => ServiceModel.fromJson(s))
          .toList();
    } else if (json['service'] != null) {
      parsedServices = [ServiceModel.fromJson(json['service'])];
    }

    return BookingModel(
      id: json['id'],
      bookingCode: json['booking_code'],
      userId: json['user_id'],
      barber:
          json['barber'] != null ? BarberModel.fromJson(json['barber']) : null,
      services: parsedServices,
      bookingDate: json['booking_date'],
      bookingTime: json['booking_time'],
      totalPrice: double.parse(json['total_price'].toString()),
      status: json['status'],
      notes: json['notes'],
      payment: json['payment'] != null
          ? PaymentModel.fromJson(json['payment'])
          : null,
      createdAt: json['created_at'],
    );
  }

  String get servicesDisplay {
    if (services.isEmpty) return '-';
    return services.map((s) => s.name).join(', ');
  }

  int get totalDuration =>
      services.fold(0, (sum, s) => sum + s.duration);

  String get bookingDateFormatted {
    try {
      final d = DateTime.parse(bookingDate);
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
    } catch (e) {
      print('DATE ERROR: $bookingDate - $e');
      return bookingDate;
    }
  }

  String get statusLabel {
    const labels = {
      'pending': 'Menunggu',
      'confirmed': 'Dikonfirmasi',
      'in_progress': 'Sedang Dikerjakan',
      'completed': 'Selesai',
      'cancelled': 'Dibatalkan',
    };
    return labels[status] ?? status;
  }

  String get paymentStatusLabel {
    if (payment?.status == 'paid' && payment?.paymentMethod == 'cashless') {
      return 'Bayar di Tempat';
    }
    if (payment?.status == 'paid') return 'Lunas';
    switch (payment?.status) {
      case 'pending':
        return 'Belum Dibayar';
      case 'failed':
        return 'Gagal';
      case 'expired':
        return 'Kadaluarsa';
      default:
        return 'Belum Ada';
    }
  }

  String get priceFormatted {
    final formatted = totalPrice.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        );
    return 'Rp $formatted';
  }

  String get timeDisplay =>
      bookingTime.length >= 5 ? bookingTime.substring(0, 5) : bookingTime;

  bool get isPaid => payment?.status == 'paid';

  bool get isCashlessPending =>
      payment?.status == 'pending' && payment?.paymentMethod == 'cashless';

  bool get canPayGateway =>
      (status == 'confirmed' || status == 'in_progress') && !isPaid && !isCashlessPending;

  bool get canPay => canPayGateway;

  bool get canReschedule =>
      status == 'pending' || status == 'confirmed';

  /// Cancel: minimal 6 jam sebelum jadwal
  bool get canCancel {
    if (status != 'pending' && status != 'confirmed') return false;
    return _isMoreThan6HoursBefore;
  }

  /// Cek minimal 6 jam dari sekarang ke jadwal booking
  bool get _isMoreThan6HoursBefore {
    try {
      final date = DateTime.parse(bookingDate);
      final parts = bookingTime.split(':');
      final bookingDt = DateTime(
        date.year, date.month, date.day,
        int.parse(parts[0]), int.parse(parts[1]),
      );
      return bookingDt.difference(DateTime.now()).inHours >= 6;
    } catch (_) {
      return true; // error parsing → izinin cancel aja
    }
  }

  bool get isAwaitingAdmin => status == 'pending';
}
