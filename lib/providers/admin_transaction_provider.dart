// lib/providers/admin_transaction_provider.dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../utils/api_list_helper.dart';

/// Admin-specific transaction & revenue management.
class AdminTransactionProvider with ChangeNotifier {
  final _api = ApiService();

  List _transactions = [];
  bool _isLoading = false;
  String? _error;

  int _seenPaymentCount = 0;

  /// Ada pembayaran baru yang belum dilihat admin?
  bool get hasNewPayments => todayPaymentCount > _seenPaymentCount;

  /// Tandai pembayaran hari ini sudah dilihat admin
  void markPaymentsSeen() {
    _seenPaymentCount = todayPaymentCount;
    notifyListeners();
  }

  List _report = [];
  double _totalRevenue = 0;
  bool _showReport = false;
  bool _isLoadingReport = false;
  DateTimeRange? _range;

  List get transactions => _transactions;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List get report => _report;
  double get totalRevenue => _totalRevenue;
  bool get showReport => _showReport;
  bool get isLoadingReport => _isLoadingReport;
  DateTimeRange? get range => _range;

  /// Pembayaran LUNAS hari ini (untuk notifikasi admin)
  int get todayPaymentCount {
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    return _transactions.where((t) {
      if (t['status'] != 'paid') return false;
      final paidAt = t['paid_at'] as String?;
      return paidAt != null && paidAt.startsWith(todayStr);
    }).length;
  }

  double get todayPaymentTotal {
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    return _transactions.where((t) {
      if (t['status'] != 'paid') return false;
      final paidAt = t['paid_at'] as String?;
      return paidAt != null && paidAt.startsWith(todayStr);
    }).fold<double>(0, (sum, t) => sum + double.parse(t['amount'].toString()));
  }

  Future<void> fetchTransactions() async {
    _error = null;
    _isLoading = true;
    notifyListeners();

    try {
      final res = await _api.adminGetTransactions();
      _transactions = apiDataAsList(res.data['data']);
      _error = null;
    } catch (e) {
      String msg = 'Gagal memuat transaksi';
      if (e is DioException) {
        msg = e.response?.data?['message'] ?? msg;
      }
      if (_transactions.isEmpty) _error = msg;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchRevenueReport(DateTimeRange picked) async {
    _range = picked;
    _isLoadingReport = true;
    notifyListeners();

    try {
      final s = DateFormat('yyyy-MM-dd').format(picked.start);
      final e = DateFormat('yyyy-MM-dd').format(picked.end);
      final res = await _api.getRevenueReport(s, e);
      _report = res.data['data']['report'];
      _totalRevenue =
          double.parse(res.data['data']['total_revenue'].toString());
      _showReport = true;
    } catch (_) {
      // silent — report tetap kosong
    } finally {
      _isLoadingReport = false;
      notifyListeners();
    }
  }

  void resetReport() {
    _showReport = false;
    _report = [];
    _totalRevenue = 0;
    _range = null;
    notifyListeners();
  }
}
