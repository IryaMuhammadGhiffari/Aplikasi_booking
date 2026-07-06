// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/admin_booking_provider.dart';
import '../../utils/app_colors.dart';
import '../../utils/extensions.dart';
import '../../widgets/shimmer_loading.dart';

class AdminBookingsScreen extends StatefulWidget {
  const AdminBookingsScreen({super.key});
  @override
  State<AdminBookingsScreen> createState() => _AdminBookingsScreenState();
}

class _AdminBookingsScreenState extends State<AdminBookingsScreen>
    with AutomaticKeepAliveClientMixin {
  final _filters = [
    'all',
    'pending',
    'confirmed',
    'in_progress',
    'completed',
    'cancelled'
  ];
  final _filterLabels = {
    'all': 'Semua',
    'pending': 'Menunggu',
    'confirmed': 'Dikonfirmasi',
    'in_progress': 'Proses',
    'completed': 'Selesai',
    'cancelled': 'Batal',
  };

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminBookingProvider>().fetch();
    });
  }

  Future<void> _fetch() async {
    await context.read<AdminBookingProvider>().fetch();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Kelola Booking')),
      body: Column(children: [
        // Alur status
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _stepChip('Menunggu', AppColors.warning),
            _arrow(),
            _stepChip('Proses', AppColors.secondary),
            _arrow(),
            _stepChip('Selesai', AppColors.success),
          ]),
        ),
        const SizedBox(height: 8),

        // Filter tabs - read filter from provider
        Consumer<AdminBookingProvider>(
          builder: (_, p, __) => SizedBox(
            height: 46,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              itemCount: _filters.length,
              itemBuilder: (_, i) {
                final f = _filters[i];
                final active = p.filter == f;
                return GestureDetector(
                  onTap: () => p.setFilter(f),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      gradient: active ? AppColors.goldGradient : null,
                      color: active ? null : AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color:
                              active ? AppColors.secondary : AppColors.divider),
                    ),
                    child: Center(
                        child: Text(
                      _filterLabels[f]!,
                      style: GoogleFonts.poppins(
                        color: active ? AppColors.primary : AppColors.lightGrey,
                        fontSize: 12,
                        fontWeight: active ? FontWeight.bold : FontWeight.normal,
                      ),
                    )),
                  ),
                );
              },
            ),
          ),
        ),

        Expanded(
          child: Consumer<AdminBookingProvider>(
            builder: (_, p, __) {
              if (p.isLoading && p.bookings.isEmpty) {
                return const ShimmerList(
                  itemBuilder: ShimmerAdminCard.new,
                  count: 5,
                );
              }
              if (p.error != null && p.bookings.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.error, size: 48),
                        const SizedBox(height: 12),
                        Text(p.error!, textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(color: AppColors.grey, fontSize: 14)),
                        const SizedBox(height: 16),
                        TextButton.icon(
                          onPressed: _fetch,
                          icon: const Icon(Icons.refresh, color: AppColors.secondary),
                          label: Text('Coba Lagi',
                            style: GoogleFonts.poppins(color: AppColors.secondary)),
                        ),
                      ],
                    ),
                  ),
                );
              }
              final bookings = p.bookings;
              return RefreshIndicator(
                color: AppColors.secondary,
                onRefresh: _fetch,
                child: bookings.isEmpty
                    ? ListView(
                        children: [
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.3,
                          ),
                          Center(
                            child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.calendar_today_outlined,
                                  size: 56, color: AppColors.grey),
                              const SizedBox(height: 12),
                              Text('Tidak ada booking',
                                  style: GoogleFonts.poppins(color: AppColors.grey)),
                              const SizedBox(height: 4),
                              Text('Booking akan muncul di sini',
                                  style: GoogleFonts.poppins(color: AppColors.grey, fontSize: 12)),
                            ],
                          )),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: bookings.length,
                        itemBuilder: (_, i) => _BookingAdminCard(
                          booking: bookings[i],
                        ),
                      ),
              );
            },
          ),
        ),
      ]),
    );
  }

  Widget _stepChip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Text(label,
            style: GoogleFonts.poppins(
                color: color, fontSize: 10, fontWeight: FontWeight.bold)),
      );

  Widget _arrow() => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 6),
        child: Icon(Icons.arrow_forward_ios, size: 10, color: AppColors.grey),
      );
}

class _BookingAdminCard extends StatelessWidget {
  final Map booking;
  const _BookingAdminCard({
    required this.booking,
  });

  @override
  Widget build(BuildContext context) {
    final status = booking['status'] as String;
    final dateStr = booking['booking_date'] as String? ?? '';
    final timeStr = (booking['booking_time'] as String? ?? '').shortTime;
    final price =
        double.tryParse(booking['total_price']?.toString() ?? '0') ?? 0;
    final statusInfo = _statusInfo(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusInfo['color'].withOpacity(0.3)),
      ),
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: statusInfo['color'].withOpacity(0.08),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child:
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(booking['booking_code'] ?? '',
                style: GoogleFonts.poppins(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.bold,
                    fontSize: 11)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: statusInfo['color'].withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(statusInfo['icon'], color: statusInfo['color'], size: 11),
                const SizedBox(width: 4),
                Text(statusInfo['label'],
                    style: GoogleFonts.poppins(
                        color: statusInfo['color'],
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              ]),
            ),
          ]),
        ),

        Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.person, color: AppColors.secondary, size: 16),
              const SizedBox(width: 6),
              Text(booking['user']?['name'] ?? '-',
                  style: GoogleFonts.poppins(
                      color: AppColors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                  child: _infoItem(
                      Icons.content_cut, 'Layanan',
                      (booking['services'] as List?)?.map((s) => s['name']).join(', ') ?? booking['service']?['name'] ?? '-')),
              Expanded(
                  child: _infoItem(Icons.person_outline, 'Barber',
                      booking['barber']?['name'] ?? '-')),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                  child: _infoItem(
                      Icons.calendar_today, 'Tanggal', dateStr.formattedDate)),
              Expanded(child: _infoItem(Icons.access_time, 'Pukul', timeStr)),
            ]),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Total',
                  style:
                      GoogleFonts.poppins(color: AppColors.grey, fontSize: 12)),
              Text(price.toRupiah,
                  style: GoogleFonts.poppins(
                      color: AppColors.secondary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
            ]),
            if (booking['notes'] != null &&
                booking['notes'].toString().trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: AppColors.secondary.withOpacity(0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.notes_outlined,
                        color: AppColors.secondary, size: 14),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Catatan Pelanggan',
                              style: GoogleFonts.poppins(
                                  color: AppColors.secondary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text(booking['notes'].toString(),
                              style: GoogleFonts.poppins(
                                  color: AppColors.lightGrey, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (status == 'pending' ||
                status == 'confirmed' ||
                status == 'in_progress') ...[
              const SizedBox(height: 14),
              const Divider(color: AppColors.divider, height: 1),
              const SizedBox(height: 12),
              _buildActions(context, status),
            ],
          ]),
        ),
      ]),
    );
  }

  Widget _buildActions(BuildContext context, String status) {
    final isLoading =
        context.watch<AdminBookingProvider>().isUpdating;

    if (status == 'pending') {
      return Row(children: [
        Expanded(
            child: OutlinedButton.icon(
          onPressed: isLoading ? null : () => _update(context, 'cancelled'),
          icon: const Icon(Icons.close, size: 14),
          label: const Text('Tolak'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.error,
            side: const BorderSide(color: AppColors.error),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        )),
        const SizedBox(width: 10),
        Expanded(
            child: ElevatedButton.icon(
          onPressed: isLoading ? null : () => _update(context, 'confirmed'),
          icon: const Icon(Icons.check, size: 14, color: Colors.white),
          label: isLoading
              ? const Text('Memproses...')
              : const Text('Konfirmasi'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        )),
      ]);
    }

    if (status == 'confirmed') {
      return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: isLoading ? null : () => _update(context, 'in_progress'),
            icon: const Icon(Icons.play_arrow, size: 16, color: Colors.black),
            label: isLoading
                ? const Text('Memproses...',
                    style: TextStyle(color: Colors.black))
                : const Text('Mulai Layanan',
                    style: TextStyle(color: Colors.black)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ));
    }

    if (status == 'in_progress') {
      return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: isLoading ? null : () => _update(context, 'completed'),
            icon: const Icon(Icons.done_all, size: 16, color: Colors.white),
            label: isLoading
                ? const Text('Memproses...',
                    style: TextStyle(color: Colors.white))
                : const Text('Selesaikan',
                    style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ));
    }

    return const SizedBox();
  }

  Widget _infoItem(IconData icon, String label, String value) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.grey, size: 13),
          const SizedBox(width: 4),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label,
                    style: GoogleFonts.poppins(
                        color: AppColors.grey, fontSize: 10)),
                Text(value,
                    style: GoogleFonts.poppins(
                        color: AppColors.lightGrey, fontSize: 12)),
              ])),
        ],
      );

  Map<String, dynamic> _statusInfo(String status) {
    switch (status) {
      case 'pending':
        return {
          'label': 'Menunggu',
          'color': AppColors.warning,
          'icon': Icons.hourglass_empty
        };
      case 'confirmed':
        return {
          'label': 'Dikonfirmasi',
          'color': AppColors.success,
          'icon': Icons.check_circle_outline
        };
      case 'in_progress':
        return {
          'label': 'Sedang Proses',
          'color': AppColors.secondary,
          'icon': Icons.content_cut
        };
      case 'completed':
        return {
          'label': 'Selesai',
          'color': AppColors.success,
          'icon': Icons.done_all
        };
      case 'cancelled':
        return {
          'label': 'Dibatalkan',
          'color': AppColors.error,
          'icon': Icons.cancel_outlined
        };
      default:
        return {
          'label': status,
          'color': AppColors.grey,
          'icon': Icons.help_outline
        };
    }
  }

  Future<void> _update(BuildContext ctx, String newStatus) async {
    final labels = {
      'confirmed': 'dikonfirmasi',
      'in_progress': 'dimulai',
      'completed': 'diselesaikan',
      'cancelled': 'dibatalkan',
    };
    final ok = await ctx.read<AdminBookingProvider>().updateStatus(
        booking['id'], newStatus);
    if (!ctx.mounted) return;
    if (ok) {
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
        content: Text('Booking berhasil ${labels[newStatus]}'),
        backgroundColor:
            newStatus == 'cancelled' ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
      ));
    } else {
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
        content: Text(ctx.read<AdminBookingProvider>().error ?? 'Gagal memperbarui status'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }
}
