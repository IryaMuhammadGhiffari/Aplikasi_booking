// lib/providers/admin_refund_provider.dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/api_list_helper.dart';

class AdminRefundProvider with ChangeNotifier {
  final _api = ApiService();

  List _pendingRefunds = [];
  List _historyRefunds = [];
  bool _isLoading = false;
  String? _error;

  List get pendingRefunds => _pendingRefunds;
  List get historyRefunds => _historyRefunds;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get pendingCount => _pendingRefunds.length;

  /// Gabungan pending + history, diurutkan created_at terbaru
  List get allRefunds {
    final combined = [..._pendingRefunds, ..._historyRefunds];
    combined.sort((a, b) {
      final aTime = a['created_at'] as String? ?? '';
      final bTime = b['created_at'] as String? ?? '';
      return bTime.compareTo(aTime);
    });
    return combined;
  }

  Future<void> fetchRefunds() async {
    _error = null;
    _isLoading = true;
    notifyListeners();

    try {
      final res = await _api.adminGetRefunds();
      _pendingRefunds = apiDataAsList(res.data['data']);
      _error = null;
    } catch (e) {
      String msg = 'Gagal memuat daftar refund';
      if (e is DioException) {
        msg = e.response?.data?['message'] ?? msg;
      }
      if (_pendingRefunds.isEmpty) _error = msg;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchRefundHistory() async {
    _error = null;
    _isLoading = true;
    notifyListeners();

    try {
      final res = await _api.adminGetRefundHistory();
      _historyRefunds = apiDataAsList(res.data['data']);
      _error = null;
    } catch (e) {
      String msg = 'Gagal memuat riwayat refund';
      if (e is DioException) {
        msg = e.response?.data?['message'] ?? msg;
      }
      if (_historyRefunds.isEmpty) _error = msg;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> approveRefund(int id, {String? adminNote}) async {
    try {
      await _api.approveRefund(id, adminNote: adminNote);
      // Move from pending to history
      final idx = _pendingRefunds.indexWhere((r) => r['id'] == id);
      if (idx != -1) {
        final item = _pendingRefunds.removeAt(idx);
        item['status'] = 'refunded';
        _historyRefunds.insert(0, item);
      }
      notifyListeners();
      return true;
    } catch (e) {
      String msg = 'Gagal mengonfirmasi refund';
      if (e is DioException) {
        msg = e.response?.data?['message'] ?? msg;
      }
      _error = msg;
      notifyListeners();
      return false;
    }
  }
}
