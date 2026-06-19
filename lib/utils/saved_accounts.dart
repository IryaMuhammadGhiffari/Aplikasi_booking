// lib/utils/saved_accounts.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

const _key = 'saved_accounts';
const _maxAccounts = 5;

class SavedAccount {
  final String email;
  final String name;
  final String lastLogin; // ISO string

  SavedAccount({
    required this.email,
    required this.name,
    required this.lastLogin,
  });

  Map<String, dynamic> toJson() => {
        'email': email,
        'name': name,
        'lastLogin': lastLogin,
      };

  factory SavedAccount.fromJson(Map<String, dynamic> json) => SavedAccount(
        email: json['email'] as String,
        name: json['name'] as String,
        lastLogin: json['lastLogin'] as String? ?? '',
      );
}

class SavedAccounts {
  /// Ambil daftar akun yang tersimpan
  static Future<List<SavedAccount>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => SavedAccount.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Simpan akun setelah login berhasil
  static Future<void> save(String email, String name) async {
    final prefs = await SharedPreferences.getInstance();
    final accounts = await load();

    // Hapus duplikat email (paling baru)
    accounts.removeWhere((a) => a.email == email);

    // Tambahkan di depan
    accounts.insert(
      0,
      SavedAccount(email: email, name: name, lastLogin: DateTime.now().toIso8601String()),
    );

    // Batasi jumlah
    if (accounts.length > _maxAccounts) {
      accounts.removeRange(_maxAccounts, accounts.length);
    }

    await prefs.setString(_key, jsonEncode(accounts.map((a) => a.toJson()).toList()));
  }

  /// Hapus satu akun
  static Future<void> remove(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final accounts = await load();
    accounts.removeWhere((a) => a.email == email);
    await prefs.setString(_key, jsonEncode(accounts.map((a) => a.toJson()).toList()));
  }

  /// Hapus semua akun
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
