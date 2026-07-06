// lib/providers/admin_refund_provider.dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/api_list_helper.dart';

class AdminRefundProvider with ChangeNotifier {
  final _api = ApiService();

  List _refunds = [];
  bool _isLoading = false;
  String? _error;

  List get refunds => _refunds;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get pendingCount => _refunds.length;

  Future<void> fetchRefunds() async {
    _error = null;
    _isLoading = true;
    notifyListeners();

    try {
      final res = await _api.adminGetRefunds();
      _refunds = apiDataAsList(res.data['data']);
      _error = null;
    } catch (e) {
      String msg = 'Gagal memuat daftar refund';
      if (e is DioException) {
        msg = e.response?.data?['message'] ?? msg;
      }
      if (_refunds.isEmpty) _error = msg;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> approveRefund(int id, {String? adminNote}) async {
    try {
      await _api.approveRefund(id, adminNote: adminNote);
      _refunds.removeWhere((r) => r['id'] == id);
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
