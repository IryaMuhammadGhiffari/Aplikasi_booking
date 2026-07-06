import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'providers/booking_provider.dart';
import 'providers/service_provider.dart';
import 'providers/barber_provider.dart';
import 'providers/admin_booking_provider.dart';
import 'providers/admin_transaction_provider.dart';
import 'providers/admin_barber_provider.dart';
import 'providers/admin_refund_provider.dart';
import 'services/api_service.dart';
import 'utils/app_theme.dart';
import 'utils/app_routes.dart';
import 'widgets/connectivity_banner.dart';

// Screens - User
import 'screens/splash_screen.dart';
import 'screens/user/login_screen.dart';
import 'screens/user/register_screen.dart';
import 'screens/user/forgot_password_screen.dart';
import 'screens/user/verify_otp_screen.dart';
import 'screens/user/reset_password_screen.dart';
import 'screens/user/home_screen.dart';
import 'screens/user/services_screen.dart';
import 'screens/user/barbers_screen.dart';
import 'screens/user/booking_screen.dart';
import 'screens/user/payment_screen.dart';
import 'screens/user/history_screen.dart';
import 'screens/user/profile_screen.dart';

// Screens - Admin
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/admin/admin_services_screen.dart';
import 'screens/admin/admin_barbers_screen.dart';
import 'screens/admin/admin_bookings_screen.dart';
import 'screens/admin/admin_transactions_screen.dart';
import 'screens/admin/admin_refund_screen.dart';
import 'screens/shared/transaction_detail_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor:          Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  await ApiService().init();

  runApp(const ArfanBarbershopApp());
}

class ArfanBarbershopApp extends StatelessWidget {
  const ArfanBarbershopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => BookingProvider()),
        ChangeNotifierProvider(create: (_) => ServiceProvider()),
        ChangeNotifierProvider(create: (_) => BarberProvider()),
        ChangeNotifierProvider(create: (_) => AdminBookingProvider()),
        ChangeNotifierProvider(create: (_) => AdminTransactionProvider()),
        ChangeNotifierProvider(create: (_) => AdminBarberProvider()),
        ChangeNotifierProvider(create: (_) => AdminRefundProvider()),
      ],
      child: MaterialApp(
        title:                     'Arfan Barbershop',
        debugShowCheckedModeBanner: false,
        theme:                     AppTheme.darkTheme,
        builder: (context, child) => ConnectivityBanner(child: child!),
        initialRoute: AppRoutes.splash,
        onGenerateRoute: (settings) {
          switch (settings.name) {
            case AppRoutes.splash:
              return MaterialPageRoute(builder: (_) => const SplashScreen());
            case AppRoutes.login:
              return MaterialPageRoute(builder: (_) => const LoginScreen());
            case AppRoutes.register:
              return MaterialPageRoute(builder: (_) => const RegisterScreen());
            case AppRoutes.forgotPassword:
              return MaterialPageRoute(builder: (_) => const ForgotPasswordScreen());
            case AppRoutes.verifyOtp:
              final args = settings.arguments;
              if (args is String) {
                return MaterialPageRoute(builder: (_) => VerifyOtpScreen(email: args));
              }
              final data = args as Map<String, String>;
              return MaterialPageRoute(builder: (_) => VerifyOtpScreen(email: data['email']!, debugOtp: data['otp']));
            case AppRoutes.resetPassword:
              final args = settings.arguments as Map<String, String>;
              return MaterialPageRoute(builder: (_) => ResetPasswordScreen(email: args['email']!, otp: args['otp']!));
            case AppRoutes.home:
              final tab = settings.arguments is int ? settings.arguments as int : 0;
              return MaterialPageRoute(builder: (_) => HomeScreen(initialTab: tab));
            case AppRoutes.services:
              return MaterialPageRoute(builder: (_) => const ServicesScreen());
            case AppRoutes.barbers:
              return MaterialPageRoute(builder: (_) => const BarbersScreen());
            case AppRoutes.booking:
              return MaterialPageRoute(builder: (_) => const BookingScreen());
            case AppRoutes.history:
              return MaterialPageRoute(builder: (_) => const HistoryScreen());
            case AppRoutes.profile:
              return MaterialPageRoute(builder: (_) => const ProfileScreen());
            case AppRoutes.adminDashboard:
              return MaterialPageRoute(builder: (_) => const AdminDashboardScreen());
            case AppRoutes.adminServices:
              return MaterialPageRoute(builder: (_) => const AdminServicesScreen());
            case AppRoutes.adminBarbers:
              return MaterialPageRoute(builder: (_) => const AdminBarbersScreen());
            case AppRoutes.adminBookings:
              return MaterialPageRoute(builder: (_) => const AdminBookingsScreen());
            case AppRoutes.adminTrx:
              return MaterialPageRoute(builder: (_) => const AdminTransactionsScreen());
            case AppRoutes.adminRefund:
              return MaterialPageRoute(builder: (_) => const AdminRefundScreen());
            case AppRoutes.payment:
              final booking = settings.arguments;
              return MaterialPageRoute(
                builder: (_) => PaymentScreen(booking: booking as dynamic),
              );
            case AppRoutes.transactionDetail:
              final args = settings.arguments as TransactionDetailArgs;
              return MaterialPageRoute(
                builder: (_) => TransactionDetailScreen(args: args),
              );
            default:
              return MaterialPageRoute(builder: (_) => const LoginScreen());
          }
        },
      ),
    );
  }
}
