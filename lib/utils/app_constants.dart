// lib/utils/app_constants.dart
//
// API_BASE_URL di-inject via --dart-define saat CI/CD build.
// Fallback: Render production URL.
// Ganti lokal: flutter build apk --dart-define=API_BASE_URL=http://IP:8000/api

class AppConstants {
  /// Base URL API — di-inject via --dart-define di CI/CD.
  /// Fallback: Render production URL.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://booking-barbershop-1.onrender.com/api',
  );

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
