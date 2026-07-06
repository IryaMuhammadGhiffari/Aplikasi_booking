import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/admin_booking_provider.dart';
import '../../providers/admin_transaction_provider.dart';
import '../../providers/admin_refund_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_routes.dart';
import '../../utils/extensions.dart';
import 'admin_bookings_screen.dart';
import 'admin_services_screen.dart';
import 'admin_transactions_screen.dart';
import 'admin_refund_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});
  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: _buildDrawer(),
      body: IndexedStack(
        index: _tab,
        children: [
          _HomeTab(onNavigateToRefund: () => setState(() => _tab = 4)),
          const AdminBookingsScreen(),
          const AdminServicesScreen(),
          const AdminTransactionsScreen(),
          const AdminRefundScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
            border:
                Border(top: BorderSide(color: AppColors.divider, width: 0.5))),
        child: BottomNavigationBar(
          currentIndex: _tab,
          onTap: (i) {
            setState(() => _tab = i);
            if (i == 3) {
              context.read<AdminTransactionProvider>().markPaymentsSeen();
            }
          },
          items: [
            const BottomNavigationBarItem(
                icon: Icon(Icons.dashboard_outlined),
                activeIcon: Icon(Icons.dashboard),
                label: 'Dashboard'),
            BottomNavigationBarItem(
                icon: _BookingTabIcon(
                    count: context
                        .watch<AdminBookingProvider>()
                        .bookings
                        .where((b) => b['status'] == 'pending')
                        .length),
                activeIcon: _BookingTabIcon(
                    count: context
                        .watch<AdminBookingProvider>()
                        .bookings
                        .where((b) => b['status'] == 'pending')
                        .length,
                    active: true),
                label: 'Booking'),
            const BottomNavigationBarItem(
                icon: Icon(Icons.design_services_outlined),
                activeIcon: Icon(Icons.design_services),
                label: 'Layanan'),
            BottomNavigationBarItem(
                icon: _RefundTabIcon(
                    count: context
                        .watch<AdminRefundProvider>()
                        .pendingCount),
                activeIcon: _RefundTabIcon(
                    count: context
                        .watch<AdminRefundProvider>()
                        .pendingCount,
                    active: true),
                label: 'Refund'),
            BottomNavigationBarItem(
                icon: _TransaksiTabIcon(
                    count: context
                        .watch<AdminTransactionProvider>()
                        .todayPaymentCount,
                    hasNew: context
                        .watch<AdminTransactionProvider>()
                        .hasNewPayments),
                activeIcon: _TransaksiTabIcon(
                    count: context
                        .watch<AdminTransactionProvider>()
                        .todayPaymentCount,
                    hasNew: context
                        .watch<AdminTransactionProvider>()
                        .hasNewPayments,
                    active: true),
                label: 'Transaksi'),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    final user = context.read<AuthProvider>().user;
    return Drawer(
      backgroundColor: AppColors.surface,
      child: SafeArea(
          child: Column(children: [
        // Header drawer
        Container(
          padding: const EdgeInsets.all(20),
          child: Row(children: [
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                  gradient: AppColors.goldGradient, shape: BoxShape.circle),
              child: Center(
                  child: Text(
                user?.name[0].toUpperCase() ?? 'A',
                style: GoogleFonts.playfairDisplay(
                    color: AppColors.primary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold),
              )),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(user?.name ?? 'Admin',
                      style: GoogleFonts.poppins(
                          color: AppColors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                  Text('Administrator',
                      style: GoogleFonts.poppins(
                          color: AppColors.secondary, fontSize: 11)),
                ])),
          ]),
        ),
        const Divider(color: AppColors.divider),

        // Menu drawer
        _drawerItem(Icons.content_cut, 'Kelola Barber',
            () => Navigator.pushNamed(context, AppRoutes.adminBarbers)),
        Consumer<AdminRefundProvider>(
          builder: (_, refProvider, __) {
            final count = refProvider.pendingCount;
            return _drawerItem(
              Icons.replay,
              count > 0 ? 'Pengajuan Refund ($count)' : 'Pengajuan Refund',
              () {
                Navigator.pop(context);
                setState(() => _tab = 4);
              },
              trailing: count > 0
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('$count',
                          style: GoogleFonts.poppins(
                              color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    )
                  : null,
            );
          },
        ),
        _drawerItem(Icons.bar_chart, 'Laporan Pendapatan',
            () => Navigator.pushNamed(context, AppRoutes.adminTrx)),

        const Spacer(),
        _drawerItem(Icons.logout, 'Keluar', _logout, color: AppColors.error),
        const SizedBox(height: 16),
      ])),
    );
  }

  Widget _drawerItem(IconData icon, String label, VoidCallback onTap,
      {Color? color, Widget? trailing}) {
    return ListTile(
      leading: Icon(icon, color: color ?? AppColors.lightGrey),
      title: Text(label,
          style: GoogleFonts.poppins(
              color: color ?? AppColors.white, fontSize: 14)),
      trailing: trailing,
      onTap: onTap,
    );
  }

  Future<void> _logout() async {
    await context.read<AuthProvider>().logout();
    if (mounted) Navigator.pushReplacementNamed(context, AppRoutes.login);
  }
}

// ════════════════════════════════════════════════════════════════
// Tab Dashboard Utama
// ════════════════════════════════════════════════════════════════
class _HomeTab extends StatefulWidget {
  final VoidCallback? onNavigateToRefund;
  const _HomeTab({this.onNavigateToRefund});

  @override
  State<_HomeTab> createState() => _HomeTabState();
}
class _HomeTabState extends State<_HomeTab> {
  Timer? _pollTimer;
  int _prevPaymentCount = 0;
  int _prevRefundCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialFetch();
    });
  }

  Future<void> _initialFetch() async {
    await Future.wait([
      context.read<AdminBookingProvider>().fetch(),
      context.read<AdminTransactionProvider>().fetchTransactions(),
      context.read<AdminRefundProvider>().fetchRefunds(),
    ]);
    if (!mounted) return;
    _prevPaymentCount =
        context.read<AdminTransactionProvider>().todayPaymentCount;
    _prevRefundCount =
        context.read<AdminRefundProvider>().pendingCount;
    _startPolling();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer(const Duration(seconds: 15), _pollTick);
  }

  Future<void> _pollTick() async {
    if (!mounted) return;
    await Future.wait([
      context.read<AdminBookingProvider>().fetch(),
      context.read<AdminTransactionProvider>().fetchTransactions(),
      context.read<AdminRefundProvider>().fetchRefunds(),
    ]);
    if (!mounted) return;

    // Deteksi pembayaran baru
    final currentPay = context.read<AdminTransactionProvider>().todayPaymentCount;
    if (currentPay > _prevPaymentCount && _prevPaymentCount > 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Pembayaran baru masuk! (+${currentPay - _prevPaymentCount})',
              style: GoogleFonts.poppins(color: Colors.white)),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ));
      }
    }
    _prevPaymentCount = currentPay;

    // Deteksi refund baru
    final currentRef = context.read<AdminRefundProvider>().pendingCount;
    if (currentRef > _prevRefundCount && _prevRefundCount > 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Pembatalan dengan refund masuk! (+${currentRef - _prevRefundCount})',
              style: GoogleFonts.poppins(color: Colors.white)),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ));
      }
    }
    _prevRefundCount = currentRef;

    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    await Future.wait([
      context.read<AdminBookingProvider>().fetch(),
      context.read<AdminTransactionProvider>().fetchTransactions(),
      context.read<AdminRefundProvider>().fetchRefunds(),
    ]);
    if (!mounted) return;
    _prevPaymentCount =
        context.read<AdminTransactionProvider>().todayPaymentCount;
    _prevRefundCount =
        context.read<AdminRefundProvider>().pendingCount;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
        color: AppColors.secondary,
        edgeOffset: 50,
        displacement: 30,
        onRefresh: _onRefresh,
        child: CustomScrollView(slivers: [
          // App bar
          SliverAppBar(
            backgroundColor: AppColors.background,
            floating: true,
            leading: Builder(
                builder: (ctx) => IconButton(
                      icon: const Icon(Icons.menu, color: AppColors.white),
                      onPressed: () => Scaffold.of(ctx).openDrawer(),
                    )),
            title:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Admin Panel',
                  style: GoogleFonts.playfairDisplay(
                      color: AppColors.secondary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              Text('Arfan Barbershop',
                  style:
                      GoogleFonts.poppins(color: AppColors.grey, fontSize: 10)),
            ]),
          ),

          // Pending refund strip notification
          Consumer<AdminRefundProvider>(
            builder: (_, refProvider, __) {
              final pendingCount = refProvider.pendingCount;
              if (pendingCount <= 0) return const SliverToBoxAdapter();

              return SliverToBoxAdapter(
                child: GestureDetector(
                  onTap: widget.onNavigateToRefund,
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.error.withOpacity(0.3)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.replay, color: AppColors.error, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: GoogleFonts.poppins(fontSize: 12),
                            children: [
                              TextSpan(
                                text: '$pendingCount pengajuan refund',
                                style: const TextStyle(
                                  color: AppColors.error,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const TextSpan(
                                text: '  —  Ketuk untuk lihat',
                                style: TextStyle(color: AppColors.grey),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: AppColors.grey, size: 18),
                    ]),
                  ),
                ),
              );
            },
          ),

          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
                delegate: SliverChildListDelegate([
              Consumer2<AdminBookingProvider, AdminTransactionProvider>(
                builder: (_, bp, tp, __) {
                  // Error state: both failed AND no data
                  final bothFailed = bp.error != null && tp.error != null;
                  final noData = bp.bookings.isEmpty && tp.transactions.isEmpty;

                  if (bothFailed && noData) {
                    return Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Column(children: [
                        const Icon(Icons.error_outline,
                            color: AppColors.error, size: 40),
                        const SizedBox(height: 8),
                        Text(
                            'Gagal memuat data. Tarik ke bawah untuk coba lagi.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                                color: AppColors.grey, fontSize: 13)),
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: _onRefresh,
                          icon: const Icon(Icons.refresh,
                              color: AppColors.secondary),
                          label: Text('Coba Lagi',
                              style: GoogleFonts.poppins(
                                  color: AppColors.secondary)),
                        ),
                      ]),
                    );
                  }

                  final totalBookings = bp.bookings.length;
                  final pendingBookings =
                      bp.bookings.where((b) => b['status'] == 'pending').length;
                  final confirmed = bp.bookings
                      .where((b) => b['status'] == 'confirmed')
                      .length;

                  return Column(children: [
                    Text('Ringkasan',
                        style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 14),

                    // Stats grid 3 kolom
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 3,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 1.3,
                      children: [
                        _StatCard(
                            icon: Icons.calendar_today,
                            label: 'Total Booking',
                            value: totalBookings,
                            color: AppColors.secondary),
                        _StatCard(
                            icon: Icons.pending_actions,
                            label: 'Menunggu',
                            value: pendingBookings,
                            color: AppColors.warning),
                        _StatCard(
                            icon: Icons.check_circle_outline,
                            label: 'Dikonfirmasi',
                            value: confirmed,
                            color: AppColors.success),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: AppColors.divider, height: 1),
                    const SizedBox(height: 20),
                    Text('Aksi Cepat',
                        style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(
                          child: _QuickBtn(
                              icon: Icons.add_circle_outline,
                              label: 'Tambah\nLayanan',
                              onTap: () => Navigator.pushNamed(
                                  context, AppRoutes.adminServices))),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _QuickBtn(
                              icon: Icons.person_add_outlined,
                              label: 'Tambah\nBarber',
                              onTap: () => Navigator.pushNamed(
                                  context, AppRoutes.adminBarbers))),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _QuickBtn(
                              icon: Icons.bar_chart,
                              label: 'Laporan\nPendapatan',
                              onTap: () => Navigator.pushNamed(
                                  context, AppRoutes.adminTrx))),
                    ]),
                    const SizedBox(height: 20),

                    // ── Pembayaran baru hari ini ──
                    if (tp.todayPaymentCount > 0) const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () {
                        context
                            .read<AdminTransactionProvider>()
                            .markPaymentsSeen();
                        Navigator.pushNamed(context, AppRoutes.adminTrx);
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.payments,
                                color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${tp.todayPaymentCount} Pembayaran Baru',
                                    style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14)),
                                Text(tp.todayPaymentTotal.toRupiah,
                                    style: GoogleFonts.poppins(
                                        color: Colors.white70, fontSize: 11)),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios,
                              color: Colors.white38, size: 14),
                        ]),
                      ),
                    ),
                  ]);
                },
              ),
            ])),
          ),
        ]));
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final num value;
  final Color color;
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
              // ignore: deprecated_member_use
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 16),
        ),
        const Spacer(),
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: value.toDouble()),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          builder: (_, val, __) {
            return Text(val.toInt().toString(),
                style: GoogleFonts.poppins(
                    color: color,
                    fontSize: 22,
                    fontWeight: FontWeight.bold));
          },
        ),
        Text(label,
            style: GoogleFonts.poppins(color: AppColors.grey, fontSize: 10)),
      ]),
    );
  }
}

class _BookingTabIcon extends StatelessWidget {
  final int count;
  final bool active;
  const _BookingTabIcon({required this.count, this.active = false});

  @override
  Widget build(BuildContext context) {
    return Badge(
      isLabelVisible: count > 0,
      label: Text('$count', style: const TextStyle(fontSize: 10)),
      child:
          Icon(active ? Icons.calendar_month : Icons.calendar_month_outlined),
    );
  }
}

class _RefundTabIcon extends StatelessWidget {
  final int count;
  final bool active;
  const _RefundTabIcon({required this.count, this.active = false});

  @override
  Widget build(BuildContext context) {
    return Badge(
      isLabelVisible: count > 0,
      label: Text('$count', style: const TextStyle(fontSize: 10)),
      child: Icon(active
          ? Icons.replay
          : Icons.replay_outlined),
    );
  }
}

class _TransaksiTabIcon extends StatelessWidget {
  final int count;
  final bool active;
  final bool hasNew;
  const _TransaksiTabIcon(
      {required this.count, this.active = false, this.hasNew = false});

  @override
  Widget build(BuildContext context) {
    return Badge(
      isLabelVisible: hasNew,
      label: Text('$count', style: const TextStyle(fontSize: 10)),
      child: Icon(active ? Icons.receipt_long : Icons.receipt_long_outlined),
    );
  }
}

class _QuickBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickBtn(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(children: [
          Icon(icon, color: AppColors.secondary, size: 24),
          const SizedBox(height: 8),
          Text(label,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  color: AppColors.lightGrey, fontSize: 10)),
        ]),
      ),
    );
  }
}
