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
