import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../utils/app_constants.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final _storage = const FlutterSecureStorage();
  late Dio _dio;

  Future<void> init() async {
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'ngrok-skip-browser-warning': 'true',
      },
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: AppConstants.tokenKey);
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          await _storage.delete(key: AppConstants.tokenKey);
          await _storage.delete(key: AppConstants.userKey);
        }
        return handler.next(error);
      },
    ));
  }

  // AUTH
  Future<Response> register(Map<String, dynamic> data) =>
      _dio.post('/auth/register', data: data);
  Future<Response> login(String email, String password) =>
      _dio.post('/auth/login', data: {'email': email, 'password': password});
  Future<Response> logout() => _dio.post('/auth/logout',
      options: Options(sendTimeout: const Duration(seconds: 5), receiveTimeout: const Duration(seconds: 5)));
  Future<Response> getProfile() => _dio.get('/auth/profile');
  Future<Response> updateProfile(Map<String, dynamic> data) =>
      _dio.put('/auth/profile', data: data);

  // SERVICES
  Future<Response> getServices() => _dio.get('/services');
  Future<Response> getService(int id) => _dio.get('/services/$id');
  Future<Response> createService(Map<String, dynamic> d) =>
      _dio.post('/admin/services', data: d);
  Future<Response> updateService(int id, Map<String, dynamic> d) =>
      _dio.put('/admin/services/$id', data: d);
  Future<Response> deleteService(int id) => _dio.delete('/admin/services/$id');

  // BARBERS
  Future<Response> getBarbers() => _dio.get('/barbers');
  Future<Response> getBarber(int id) => _dio.get('/barbers/$id');
  Future<Response> getAvailableSlots(int barberId, String date) =>
      _dio.get('/barbers/$barberId/available-slots',
          queryParameters: {'date': date});
  Future<Response> getUnavailableDates(int barberId, String from, String to) =>
      _dio.get('/barbers/$barberId/unavailable-dates',
          queryParameters: {'from': from, 'to': to});
  Future<Response> getBarberUnavailabilities(int barberId) =>
      _dio.get('/admin/barbers/$barberId/unavailabilities');
  Future<Response> createBarberUnavailability(int barberId, Map<String, dynamic> d) =>
      _dio.post('/admin/barbers/$barberId/unavailabilities', data: d);
  Future<Response> deleteBarberUnavailability(int barberId, int id) =>
      _dio.delete('/admin/barbers/$barberId/unavailabilities/$id');
  Future<Response> adminGetBarbers() => _dio.get('/admin/barbers');
  Future<Response> createBarber(Map<String, dynamic> d) =>
      _dio.post('/admin/barbers', data: d);
  Future<Response> updateBarber(int id, Map<String, dynamic> d) =>
      _dio.put('/admin/barbers/$id', data: d);
  Future<Response> deleteBarber(int id) => _dio.delete('/admin/barbers/$id');

  // BOOKINGS
  Future<Response> getMyBookings() => _dio.get('/bookings');
  Future<Response> getBooking(int id) => _dio.get('/bookings/$id');
  Future<Response> createBooking(Map<String, dynamic> d) =>
      _dio.post('/bookings', data: d);
  Future<Response> cancelBooking(int id) => _dio.patch('/bookings/$id/cancel');
  Future<Response> rescheduleBooking(int id, Map<String, dynamic> d) =>
      _dio.patch('/bookings/$id/reschedule', data: d);
  Future<Response> adminGetBookings({String? status, String? date}) {
    final params = <String, dynamic>{};
    if (status != null) params['status'] = status;
    if (date != null) params['date'] = date;
    return _dio.get('/admin/bookings', queryParameters: params);
  }

  Future<Response> adminUpdateStatus(int id, String status) =>
      _dio.patch('/admin/bookings/$id/status', data: {'status': status});

  // PAYMENTS
  Future<Response> createPayment(int bookingId, {bool refresh = false}) =>
      _dio.post('/bookings/$bookingId/pay',
          queryParameters: refresh ? {'refresh': '1'} : null);
  Future<Response> chooseCashless(int bookingId) =>
      _dio.post('/bookings/$bookingId/pay-cashless');
  Future<Response> checkPaymentStatus(int bookingId) =>
      _dio.get('/bookings/$bookingId/payment-status');
  Future<Response> adminGetTransactions() => _dio.get('/admin/transactions');
  Future<Response> getRevenueReport(String start, String end) =>
      _dio.get('/admin/revenue-report',
          queryParameters: {'start_date': start, 'end_date': end});
}
