// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/booking_provider.dart';
import '../../providers/service_provider.dart';
import '../../providers/barber_provider.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_routes.dart';
import '../user/services_screen.dart';
import '../user/history_screen.dart';
import '../user/profile_screen.dart';
import '../user/payment_screen.dart';
import '../../widgets/booking_confirmed_dialog.dart';
import '../../widgets/shimmer_loading.dart';

class HomeScreen extends StatefulWidget {
  final int initialTab;
  const HomeScreen({super.key, this.initialTab = 0});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int _currentTab;
  Timer? _singleRefreshTimer;
  int _pollIntervalSec = 30;

  @override
  void initState() {
    super.initState();
    _currentTab = widget.initialTab;
    // Init fetch → setelah itu mulai polling dengan interval adaptif
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _initialFetch();
      if (!mounted) return;
      _scheduleNextPoll(); // polling dimulai SETELAH initial fetch
    });
  }

  /// Satu tick polling: fetch paralel → cek konfirmasi → jadwalkan tick berikutnya.
  Future<void> _pollTick() async {
    if (!mounted) return;
    await Future.wait([
      context.read<BookingProvider>().fetchMyBookings(),
      context.read<ServiceProvider>().fetchServices(),
      context.read<BarberProvider>().fetchBarbers(),
    ]);
    if (!mounted) return;

    // Cek booking baru dikonfirmasi
    if (_currentTab == 0) {
      final confirmed = context.read<BookingProvider>().takeNewlyConfirmedBooking();
      if (confirmed != null && mounted) {
        await showBookingConfirmedDialog(context, confirmed);
      }
    }

    // Adaptive: 5s jika masih ada pending, 30s jika tidak
    if (!mounted) return;
    final hasPending = context
        .read<BookingProvider>()
        .bookings
        .any((b) => b.status == 'pending');
    _pollIntervalSec = hasPending ? 5 : 30;
    _scheduleNextPoll();
  }

  /// Jadwalkan tick polling berikutnya setelah [delay] detik.
  void _scheduleNextPoll() {
    _singleRefreshTimer?.cancel();
    _singleRefreshTimer = Timer(Duration(seconds: _pollIntervalSec), _pollTick);
  }

  Future<void> _initialFetch() async {
    await Future.wait([
      context.read<BookingProvider>().fetchMyBookings(),
      context.read<ServiceProvider>().fetchServices(),
      context.read<BarberProvider>().fetchBarbers(),
    ]);
    if (!mounted) return;
    // Jika ada pending booking, polling langsung 5s (tidak perlu nunggu 30s)
    if (context.read<BookingProvider>().bookings.any((b) => b.status == 'pending')) {
      _pollIntervalSec = 5;
    }
  }

  @override
  void dispose() {
    _singleRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _currentTab,
        children: const [
          _HomeTab(),
          ServicesScreen(),
          HistoryScreen(),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentTab,
          onTap: (i) => setState(() => _currentTab = i),
          items: const [
            BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home),
                label: 'Home'),
            BottomNavigationBarItem(
                icon: Icon(Icons.grid_view_outlined),
                activeIcon: Icon(Icons.grid_view),
                label: 'Layanan'),
            BottomNavigationBarItem(
                icon: Icon(Icons.history_outlined),
                activeIcon: Icon(Icons.history),
                label: 'Riwayat'),
            BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                activeIcon: Icon(Icons.person),
                label: 'Profil'),
          ],
        ),
      ),
    );
  }
}

class _HomeTab extends StatefulWidget {
  const _HomeTab();
  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final booking = context.watch<BookingProvider>();
    final services = context.watch<ServiceProvider>();
    final barbers = context.watch<BarberProvider>();

    return RefreshIndicator(
      color: AppColors.secondary,
      edgeOffset: 50,
      displacement: 30,
      onRefresh: () async {
        await Future.wait([
          context.read<BookingProvider>().fetchMyBookings(),
          context.read<ServiceProvider>().fetchServices(force: true),
          context.read<BarberProvider>().fetchBarbers(force: true),
        ]);
      },
      child: CustomScrollView(
      slivers: [
        // Header sambutan
        SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1A1A1A), Color(0xFF2A2A2A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Halo, ${user?.name.split(' ').first ?? 'Pelanggan'} 👋',
                          style: GoogleFonts.poppins(
                              color: AppColors.lightGrey, fontSize: 14),
                        ),
                        Text('Mau potong hari ini?',
                            style: Theme.of(context).textTheme.headlineLarge),
                      ],
                    ),
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: AppColors.goldGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.content_cut,
                          color: AppColors.primary, size: 22),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Banner booking
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, AppRoutes.booking),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: AppColors.goldGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.secondary.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        )
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Booking Sekarang',
                                style: GoogleFonts.playfairDisplay(
                                  color: AppColors.primary,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Pilih barber & jadwal favoritmu',
                                style: GoogleFonts.poppins(
                                    color: AppColors.primary.withOpacity(0.7),
                                    fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.calendar_today,
                              color: AppColors.primary, size: 28),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        if (booking.bookingsReadyToPay.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: _PaymentReadyBanner(
                count: booking.bookingsReadyToPay.length,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          PaymentScreen(booking: booking.bookingsReadyToPay.first),
                    ),
                  );
                },
              ),
            ),
          ),

        // Section layanan — pakai ServiceProvider.isLoadingServices
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Layanan Kami',
                    style: Theme.of(context).textTheme.headlineMedium),
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, AppRoutes.services),
                  child: Text('Lihat Semua',
                      style: GoogleFonts.poppins(
                          color: AppColors.secondary, fontSize: 13)),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: services.isLoading && services.services.isEmpty
              ? SizedBox(
                  height: 155,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: 4,
                    itemBuilder: (_, __) => Container(
                      width: 135,
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ShimmerLoading(width: 38, height: 38, borderRadius: 10),
                          Spacer(),
                          ShimmerLoading(width: 90, height: 12, borderRadius: 4),
                          SizedBox(height: 2),
                          ShimmerLoading(width: 60, height: 11, borderRadius: 4),
                        ],
                      ),
                    ),
                  ),
                )
              : SizedBox(
                  height: 155,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: services.services.length > 6
                        ? 6
                        : services.services.length,
                    itemBuilder: (_, i) {
                      final s = services.services[i];
                      return GestureDetector(
                        onTap: () =>
                            Navigator.pushNamed(context, AppRoutes.booking),
                        child: Container(
                          width: 135,
                          margin: const EdgeInsets.only(right: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  gradient: AppColors.goldGradient,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.content_cut,
                                    color: AppColors.primary, size: 18),
                              ),
                              const Spacer(),
                              Text(s.name,
                                  style: GoogleFonts.poppins(
                                      color: AppColors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 2),
                              Text(s.priceFormatted,
                                  style: GoogleFonts.poppins(
                                      color: AppColors.secondary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),

        // Section barber — pakai BarberProvider
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Tim Barber',
                    style: Theme.of(context).textTheme.headlineMedium),
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, AppRoutes.barbers),
                  child: Text('Lihat Semua',
                      style: GoogleFonts.poppins(
                          color: AppColors.secondary, fontSize: 13)),
                ),
              ],
            ),
          ),
        ),
        if (barbers.isLoadingBarbers && barbers.barbers.isEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, __) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    children: [
                      ShimmerLoading(width: 56, height: 56, borderRadius: 28),
                      SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ShimmerLoading(width: 140, height: 15, borderRadius: 4),
                            SizedBox(height: 6),
                            ShimmerLoading(width: 100, height: 12, borderRadius: 4),
                            SizedBox(height: 6),
                            ShimmerLoading(width: 80, height: 11, borderRadius: 4),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                childCount: 3,
              ),
            ),
          )
        else if (barbers.barbers.isEmpty)
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                children: [
                  const Icon(Icons.content_cut, color: AppColors.grey, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    barbers.barbersError ?? 'Belum ada barber tersedia',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(color: AppColors.grey, fontSize: 12),
                  ),
                  if (barbers.barbersError != null) ...[
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () {
                        context.read<BarberProvider>().fetchBarbers(force: true);
                      },
                      child: Text('Coba Lagi',
                          style: GoogleFonts.poppins(
                              color: AppColors.secondary, fontSize: 12)),
                    ),
                  ],
                ],
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) {
                  final b = barbers.barbers[i];
                  return GestureDetector(
                    onTap: () => Navigator.pushNamed(context, AppRoutes.booking),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: AppColors.surfaceLight,
                            child: Text(b.name[0],
                                style: GoogleFonts.playfairDisplay(
                                    color: AppColors.secondary,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(b.name,
                                    style: GoogleFonts.poppins(
                                        color: AppColors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15)),
                                Text(b.specialty ?? '',
                                    style: GoogleFonts.poppins(
                                        color: AppColors.grey, fontSize: 12)),
                                Row(children: [
                                  const Icon(Icons.star,
                                      color: AppColors.secondary, size: 13),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(b.rating.toStringAsFixed(1),
                                        style: GoogleFonts.poppins(
                                            color: AppColors.secondary,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(width: 10),
                                  Flexible(
                                    child: Text(
                                        '${b.experienceYears} thn pengalaman',
                                        style: GoogleFonts.poppins(
                                            color: AppColors.grey,
                                            fontSize: 11),
                                        overflow: TextOverflow.ellipsis),
                                  ),
                                ]),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: AppColors.goldGradient,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text('Booking',
                                style: GoogleFonts.poppins(
                                    color: AppColors.primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                childCount: barbers.barbers.length,
              ),
            ),
          ),
      ],
    ));
  }
}

class _PaymentReadyBanner extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _PaymentReadyBanner({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.success.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.success.withOpacity(0.4)),
        ),
        child: Row(children: [
          const Icon(Icons.notifications_active,
              color: AppColors.success, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Booking dikonfirmasi admin!',
                  style: GoogleFonts.poppins(
                    color: AppColors.success,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Text(
                  count > 1
                      ? '$count booking siap dibayar. Tap untuk bayar.'
                      : 'Silakan selesaikan pembayaran sekarang.',
                  style: GoogleFonts.poppins(
                    color: AppColors.lightGrey,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios,
              color: AppColors.success, size: 14),
        ]),
      ),
    );
  }
}
