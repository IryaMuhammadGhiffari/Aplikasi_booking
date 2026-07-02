import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../utils/app_constants.dart';

class AuthProvider with ChangeNotifier {
  final _api     = ApiService();
  final _storage = const FlutterSecureStorage();

  UserModel? _user;
  bool       _isLoading    = false;
  String?    _errorMessage;

  UserModel? get user         => _user;
  bool       get isLoading    => _isLoading;
  String?    get errorMessage => _errorMessage;
  bool       get isLoggedIn   => _user != null;
  bool       get isAdmin      => _user?.isAdmin ?? false;

  void _setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }

  void _setError(String? msg) {
    _errorMessage = msg;
    notifyListeners();
  }

  /// Coba auto-login dari token yang tersimpan
  Future<bool> tryAutoLogin() async {
    try {
      final token    = await _storage.read(key: AppConstants.tokenKey);
      final userData = await _storage.read(key: AppConstants.userKey);
      if (token == null || userData == null) return false;
      _user = UserModel.fromJson(jsonDecode(userData));
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Login
  Future<bool> login(String email, String password) async {
    _setLoading(true);
    _setError(null);
    try {
      final res = await _api.login(email, password);
      final data = res.data['data'];
      await _saveSession(data['token'] as String, data['user'] as Map<String, dynamic>);
      return true;
    } catch (e) {
      _setError(_parseError(e));
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Register
  Future<bool> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String passwordConfirmation,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      final res = await _api.register({
        'name':                  name,
        'email':                 email,
        'phone':                 phone,
        'password':              password,
        'password_confirmation': passwordConfirmation,
      });
      final data = res.data['data'];
      await _saveSession(data['token'] as String, data['user'] as Map<String, dynamic>);
      return true;
    } catch (e) {
      _setError(_parseError(e));
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Logout
  Future<void> logout() async {
    try { await _api.logout(); } catch (_) {}
    await _storage.delete(key: AppConstants.tokenKey);
    await _storage.delete(key: AppConstants.userKey);
    _user = null;
    notifyListeners();
  }

  /// Update profil
  Future<bool> updateProfile({String? name, String? phone}) async {
    _setLoading(true);
    try {
      final data = <String, dynamic>{};
      if (name  != null && name.isNotEmpty)  data['name']  = name;
      if (phone != null && phone.isNotEmpty) data['phone'] = phone;
      final res = await _api.updateProfile(data);
      _user = UserModel.fromJson(res.data['data']);
      await _storage.write(
        key:   AppConstants.userKey,
        value: jsonEncode(_user!.toJson()),
      );
      notifyListeners();
      return true;
    } catch (e) {
      _setError(_parseError(e));
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Refresh profil dari server (pull-to-refresh)
  Future<void> refreshProfile() async {
    try {
      final res = await _api.getProfile();
      _user = UserModel.fromJson(res.data['data']);
      await _storage.write(
        key:   AppConstants.userKey,
        value: jsonEncode(_user!.toJson()),
      );
      notifyListeners();
    } catch (_) {
      // silent — data lokal masih dipakai
    }
  }

  /// Forgot password — send OTP via WA
  Future<bool> forgotPassword(String email) async {
    _setLoading(true);
    _setError(null);
    try {
      await _api.forgotPassword(email);
      return true;
    } catch (e) {
      _setError(_parseError(e));
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Verify OTP
  Future<bool> verifyOtp(String email, String otp) async {
    _setLoading(true);
    _setError(null);
    try {
      await _api.verifyOtp(email, otp);
      return true;
    } catch (e) {
      _setError(_parseError(e));
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Reset password
  Future<bool> resetPassword(String email, String otp, String password) async {
    _setLoading(true);
    _setError(null);
    try {
      await _api.resetPassword(email, otp, password);
      return true;
    } catch (e) {
      _setError(_parseError(e));
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _saveSession(String token, Map<String, dynamic> userData) async {
    await _storage.write(key: AppConstants.tokenKey, value: token);
    _user = UserModel.fromJson(userData);
    await _storage.write(
      key:   AppConstants.userKey,
      value: jsonEncode(_user!.toJson()),
    );
    notifyListeners();
  }

  String _parseError(dynamic e) {
    try {
      final response = e.response;
      if (response == null) return 'Tidak dapat terhubung ke server.\nPastikan Laravel sudah running.';
      final errors = response.data?['errors'];
      if (errors != null && errors is Map && errors.isNotEmpty) {
        final firstList = errors.values.first;
        if (firstList is List && firstList.isNotEmpty) {
          return firstList.first.toString();
        }
      }
      final message = response.data?['message'];
      if (message != null) return message.toString();
      return 'Error ${response.statusCode}: Login gagal';
    } catch (_) {
      return 'Tidak dapat terhubung ke server';
    }
  }
}