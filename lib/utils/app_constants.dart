// lib/utils/app_constants.dart
//
// PENTING: Ganti baseUrl dengan IP komputer kamu!
// Cara cari IP:
//   Windows → buka CMD → ketik: ipconfig
//   Cari "IPv4 Address" misalnya 192.168.1.5
//   Lalu isi: http://192.168.1.5:8000/api
//
// JANGAN pakai localhost atau 127.0.0.1 dari HP!

class AppConstants {
  static const String baseUrl =
      'https://booking-barbershop-1.onrender.com/api'; // Render

  static const String appName = 'Arfan Barbershop';
  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_data';

  static const List<String> timeSlots = [
    '10:00',
    '11:00',
    '12:00',
    '13:00',
    '14:00',
    '15:00',
    '16:00',
    '17:00',
    '18:00',
    '19:00',
    '20:00',
    '21:00',
  ];
}
