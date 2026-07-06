// lib/providers/booking_provider.dart
// Simplified: only handles user's bookings and payment flow.
// Services → ServiceProvider, Barbers/Slots → BarberProvider

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../models/booking_model.dart';
import '../services/api_service.dart';

class BookingProvider with ChangeNotifier {
  final _api = ApiService();

  List<BookingModel> _bookings = [];
  bool _isLoading = false;
  String? _error;

  bool _isFetchingMyBookings = false;
  final Map<int, String> _lastKnownStatus = {};
  final List<int> _newlyConfirmedIds = [];

  List<BookingModel> get bookings => _bookings;
  List<BookingModel> get bookingsReadyToPay =>
      _bookings.where((b) => b.canPay).toList();
  bool get isLoading => _isLoading;
  String? get error => _error;

  // ── MY BOOKINGS ──────────────────────────────────────────

  Future<void> fetchMyBookings() async {
    if (_isFetchingMyBookings) return;
    _isFetchingMyBookings = true;
    _error = null;
    _isLoading = true;
    notifyListeners();

    try {
      final res = await _api.getMyBookings();
      _bookings = (res.data['data'] as List)
          .map((b) => BookingModel.fromJson(b))
          .toList();
      _trackStatusChanges();
      _error = null;
    } catch (e) {
      if (_bookings.isEmpty) {
        _error = 'Gagal memuat riwayat booking';
      }
    } finally {
      _isLoading = false;
      _isFetchingMyBookings = false;
      notifyListeners();
    }
  }

  void _trackStatusChanges() {
    for (final b in _bookings) {
      final prev = _lastKnownStatus[b.id];
      if (prev != null && prev == 'pending' && b.status == 'confirmed' && !b.isPaid) {
        if (!_newlyConfirmedIds.contains(b.id)) {
          _newlyConfirmedIds.add(b.id);
        }
      }
      _lastKnownStatus[b.id] = b.status;
    }
  }

  BookingModel? takeNewlyConfirmedBooking() {
    if (_newlyConfirmedIds.isEmpty) return null;
    final id = _newlyConfirmedIds.removeAt(0);
    try {
      return _bookings.firstWhere((b) => b.id == id);
    } catch (_) {
      return null;
    }
  }

  void seedBookingStatus(BookingModel booking) {
    _lastKnownStatus[booking.id] = booking.status;
  }

  // ── CREATE BOOKING ──────────────────────────────────────

  Future<BookingModel?> createBooking({
    required int barberId,
    required List<int> serviceIds,
    required String bookingDate,
    required String bookingTime,
    String? notes,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = {
        'barber_id': barberId,
        'service_ids': serviceIds,
        'booking_date': bookingDate,
        'booking_time': bookingTime,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      };
      final res = await _api.createBooking(data);
      final booking = BookingModel.fromJson(res.data['data']);
      _bookings.insert(0, booking);
      seedBookingStatus(booking);
      notifyListeners();
      return booking;
    } catch (e) {
      _error = _parseError(e);
      notifyListeners();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── PAYMENT ─────────────────────────────────────────────

  Future<Map<String, dynamic>?> createPayment(int bookingId,
      {bool refresh = false}) async {
    try {
      final res = await _api.createPayment(bookingId, refresh: refresh);
      if (res.data['success'] == true) {
        return res.data['data'] as Map<String, dynamic>;
      } else {
        _error = res.data['message'] ?? 'Gagal membuat transaksi';
        notifyListeners();
        return null;
      }
    } on DioException catch (e) {
      _error = e.response?.data?['message'] ??
          e.message ??
          'Gagal membuat transaksi';
      notifyListeners();
      return null;
    } catch (e) {
      _error = 'Tidak dapat terhubung ke server: $e';
      notifyListeners();
      return null;
    }
  }

  Future<Map<String, dynamic>?> checkPaymentStatus(int bookingId) async {
    try {
      final res = await _api.checkPaymentStatus(bookingId);
      return res.data['data'] as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<bool> verifyBookingPaid(int bookingId) async {
    final data = await checkPaymentStatus(bookingId);
    return data?['payment']?['status'] == 'paid';
  }

  Future<bool> chooseCashless(int bookingId) async {
    _error = null;
    try {
      final res = await _api.chooseCashless(bookingId);
      if (res.data['success'] == true) {
        await fetchMyBookings();
        return true;
      }
      _error = res.data['message'] ?? 'Gagal memilih bayar di tempat';
      notifyListeners();
      return false;
    } on DioException catch (e) {
      _error = e.response?.data?['message'] ?? 'Gagal memilih bayar di tempat';
      notifyListeners();
      return false;
    } catch (_) {
      _error = 'Gagal memilih bayar di tempat';
      notifyListeners();
      return false;
    }
  }

  // ── CANCEL / RESCHEDULE ─────────────────────────────────

  Future<bool> cancelBooking(int bookingId, {String? cancelReason}) async {
    _error = null;
    try {
      await _api.cancelBooking(bookingId, cancelReason: cancelReason);
      await fetchMyBookings();
      return true;
    } on DioException catch (e) {
      _error = e.response?.data?['message'] ?? 'Gagal membatalkan booking';
      notifyListeners();
      return false;
    } catch (_) {
      _error = 'Gagal membatalkan booking';
      notifyListeners();
      return false;
    }
  }

  Future<BookingModel?> rescheduleBooking({
    required int bookingId,
    required String bookingDate,
    required String bookingTime,
  }) async {
    _error = null;
    _isLoading = true;
    notifyListeners();
    try {
      final res = await _api.rescheduleBooking(bookingId, {
        'booking_date': bookingDate,
        'booking_time': bookingTime,
      });
      final updated = BookingModel.fromJson(res.data['data']);
      final idx = _bookings.indexWhere((b) => b.id == bookingId);
      if (idx != -1) {
        _bookings[idx] = updated;
      }
      notifyListeners();
      return updated;
    } on DioException catch (e) {
      _error = e.response?.data?['message'] ?? 'Gagal mengubah jadwal';
      notifyListeners();
      return null;
    } catch (_) {
      _error = 'Gagal mengubah jadwal';
      notifyListeners();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── HELPERS ─────────────────────────────────────────────

  String _parseError(dynamic e) {
    try {
      if (e is DioException) {
        return e.response?.data?['message'] ?? e.message ?? 'Terjadi kesalahan';
      }
      return e.toString();
    } catch (_) {
      return 'Tidak dapat terhubung ke server';
    }
  }
}
