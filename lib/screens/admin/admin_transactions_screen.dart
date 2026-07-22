// ignore_for_file: deprecated_member_use, duplicate_ignore

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/admin_transaction_provider.dart';
import '../../utils/app_colors.dart';
import '../../utils/extensions.dart';
import '../../utils/report_exporter.dart';
import '../../utils/app_routes.dart';
import '../../widgets/shimmer_loading.dart';
import '../shared/transaction_detail_screen.dart';

class AdminTransactionsScreen extends StatefulWidget {
  const AdminTransactionsScreen({super.key});
  @override
  State<AdminTransactionsScreen> createState() =>
      _AdminTransactionsScreenState();
}

class _AdminTransactionsScreenState extends State<AdminTransactionsScreen>
    with AutomaticKeepAliveClientMixin {

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminTransactionProvider>()
        ..fetchTransactions()
        ..markPaymentsSeen();
    });
  }

  Future<void> _fetch() async {
    await context.read<AdminTransactionProvider>().fetchTransactions();
  }

  Future<void> _pickRange() async {
    final provider = context.read<AdminTransactionProvider>();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: provider.range ??
          DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 30)),
            end: DateTime.now(),
          ),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.secondary,
            onSurface: AppColors.white,
            surface: AppColors.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    await provider.fetchRevenueReport(picked);
  }


  /// Ambil tanggal display dari transaksi (paid_at > created_at > booking_date)
  String _trxDateKey(Map t) {
    final paidAt = t['paid_at'] as String?;
    if (paidAt != null && paidAt.length >= 10) return paidAt.substring(0, 10);
    final createdAt = t['created_at'] as String?;
    if (createdAt != null && createdAt.length >= 10) return createdAt.substring(0, 10);
    final booking = t['booking'] as Map?;
    final bookingDate = booking?['booking_date'] as String?;
    if (bookingDate != null && bookingDate.length >= 10) return bookingDate.substring(0, 10);
    return DateTime.now().toIso8601String().substring(0, 10);
  }

  /// Group transaksi berdasarkan tanggal (urut dari terbaru)
  Map<String, List<Map>> _groupedTransactions(List list) {
    final map = <String, List<Map>>{};
    for (final t in list) {
      final key = _trxDateKey(t);
      map.putIfAbsent(key, () => []).add(t);
    }
    // Urutkan descending berdasarkan key tanggal
    final sorted = map.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));
    return {for (final e in sorted) e.key: e.value};
  }

  Future<void> _export(String type) async {
    final provider = context.read<AdminTransactionProvider>();
    try {
      if (type == 'trx_csv') {
        await ReportExporter.exportTransactionsCsv(provider.transactions);
      } else if (type == 'trx_pdf') {
        await ReportExporter.exportTransactionsPdf(provider.transactions);
      } else if (type == 'rev_csv' && provider.range != null) {
        await ReportExporter.exportRevenueCsv(
          report: provider.report,
          totalRevenue: provider.totalRevenue,
          start: provider.range!.start,
          end: provider.range!.end,
        );
      } else if (type == 'rev_pdf' && provider.range != null) {
        await ReportExporter.exportRevenuePdf(
          report: provider.report,
          totalRevenue: provider.totalRevenue,
          start: provider.range!.start,
          end: provider.range!.end,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Laporan siap dibagikan',
            style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: AppColors.success,
      ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Gagal mengekspor laporan',
            style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: AppColors.error,
      ));
    }
  }

  void _showExportMenu() {
    final provider = context.read<AdminTransactionProvider>();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ekspor Laporan',
                  style: GoogleFonts.poppins(
                      color: AppColors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
              const SizedBox(height: 16),
              Text('Semua Transaksi',
                  style: GoogleFonts.poppins(
                      color: AppColors.grey, fontSize: 12)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: provider.transactions.isEmpty
                        ? null
                        : () {
                            Navigator.pop(ctx);
                            _export('trx_csv');
                          },
                    icon: const Icon(Icons.table_chart_outlined, size: 16),
                    label: const Text('CSV'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.secondary,
                      side: const BorderSide(color: AppColors.secondary),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: provider.transactions.isEmpty
                        ? null
                        : () {
                            Navigator.pop(ctx);
                            _export('trx_pdf');
                          },
                    icon: const Icon(Icons.picture_as_pdf_outlined,
                        size: 16, color: Colors.white),
                    label: const Text('PDF'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      foregroundColor: AppColors.primary,
                    ),
                  ),
                ),
              ]),
              if (provider.showReport && provider.range != null) ...[
                const SizedBox(height: 20),
                Text('Laporan Pendapatan',
                    style: GoogleFonts.poppins(
                        color: AppColors.grey, fontSize: 12)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _export('rev_csv');
                      },
                      icon: const Icon(Icons.table_chart_outlined, size: 16),
                      label: const Text('CSV'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.secondary,
                        side: const BorderSide(color: AppColors.secondary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _export('rev_pdf');
                      },
                      icon: const Icon(Icons.picture_as_pdf_outlined,
                          size: 16, color: Colors.white),
                      label: const Text('PDF'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondary,
                        foregroundColor: AppColors.primary,
                      ),
                    ),
                  ),
                ]),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Laporan Transaksi'),
        actions: [
          IconButton(
            onPressed: _showExportMenu,
            icon: const Icon(Icons.download_outlined,
                color: AppColors.secondary),
            tooltip: 'Ekspor',
          ),
          TextButton.icon(
            onPressed: _pickRange,
            icon: const Icon(Icons.date_range,
                color: AppColors.secondary, size: 18),
            label: Text('Laporan',
                style: GoogleFonts.poppins(
                    color: AppColors.secondary, fontSize: 13)),
          ),
        ],
      ),
      body: Consumer<AdminTransactionProvider>(
        builder: (_, provider, __) {
          if (provider.isLoading && provider.transactions.isEmpty) {
            return const ShimmerList(
              itemBuilder: ShimmerAdminCard.new,
              count: 5,
            );
          }
          if (provider.error != null && provider.transactions.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.error, size: 48),
                    const SizedBox(height: 12),
                    Text(provider.error!, textAlign: TextAlign.center,
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
          return RefreshIndicator(
            color: AppColors.secondary,
            onRefresh: _fetch,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (provider.showReport) ...[
                  _buildReportPanel(provider),
                  const SizedBox(height: 20)
                ],
                Text('Semua Transaksi',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 12),
                if (provider.transactions.isEmpty)
                  Center(
                      child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(children: [
                      const Icon(Icons.receipt_long_outlined,
                          size: 56, color: AppColors.grey),
                      const SizedBox(height: 12),
                      Text('Belum ada transaksi',
                          style: GoogleFonts.poppins(color: AppColors.grey)),
                    ]),
                  ))
                else
                  ..._groupedTransactions(provider.transactions).entries
                      .expand((entry) => [
                            _DateHeader(dateStr: entry.key),
                            ...entry.value.map((t) => _TrxCard(
                                  t: t,
                                  onTap: () async {
                                    final refreshed =
                                        await Navigator.pushNamed(
                                      context,
                                      AppRoutes.transactionDetail,
                                      arguments: TransactionDetailArgs(
                                        isAdmin: true,
                                        transaction:
                                            Map<String, dynamic>.from(t),
                                      ),
                                    );
                                    if (refreshed == true) _fetch();
                                  },
                                )),
                          ]),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildReportPanel(AdminTransactionProvider provider) {
    final start = DateFormat('d MMM yyyy').format(provider.range!.start);
    final end = DateFormat('d MMM yyyy').format(provider.range!.end);
    final maxVal = provider.report.isEmpty
        ? 1.0
        : provider.report.fold<double>(0, (max, r) {
            final v = double.parse(r['total'].toString());
            return v > max ? v : max;
          });

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.goldGradient,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: AppColors.secondary.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Laporan Pendapatan',
            style: GoogleFonts.poppins(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 15)),
        Text('$start  —  $end',
            style: GoogleFonts.poppins(
                color: AppColors.primary.withOpacity(0.7), fontSize: 11)),
        const SizedBox(height: 14),
        if (provider.isLoadingReport)
          const CircularProgressIndicator(color: AppColors.primary)
        else ...[
          Text(provider.totalRevenue.toRupiah,
              style: GoogleFonts.playfairDisplay(
                  color: AppColors.primary,
                  fontSize: 26,
                  fontWeight: FontWeight.bold)),
          Text('Total Pendapatan',
              style: GoogleFonts.poppins(
                  color: AppColors.primary.withOpacity(0.7), fontSize: 11)),
          if (provider.report.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(color: Color(0x33000000)),
            const SizedBox(height: 8),
            Text('Per Hari:',
                style: GoogleFonts.poppins(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12)),
            const SizedBox(height: 8),
            ...provider.report.take(7).map((r) {
              final dayTotal = double.parse(r['total'].toString());
              final ratio =
                  maxVal > 0 ? (dayTotal / maxVal).clamp(0.0, 1.0) : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(children: [
                  SizedBox(
                      width: 72,
                      child: Text(r['date'],
                          style: GoogleFonts.poppins(
                              color: AppColors.primary.withOpacity(0.8),
                              fontSize: 10))),
                  Expanded(
                      child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: ratio,
                      backgroundColor: AppColors.primary.withOpacity(0.15),
                      color: AppColors.primary,
                      minHeight: 8,
                    ),
                  )),
                  const SizedBox(width: 8),
                  Text('${(dayTotal / 1000).toStringAsFixed(0)}K',
                      style: GoogleFonts.poppins(
                          color: AppColors.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                ]),
              );
            }),
          ],
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _export('rev_csv'),
                icon: const Icon(Icons.table_chart_outlined, size: 14),
                label: Text('CSV',
                    style: GoogleFonts.poppins(fontSize: 11)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(color: AppColors.primary.withOpacity(0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _export('rev_pdf'),
                icon: const Icon(Icons.picture_as_pdf_outlined,
                    size: 14, color: AppColors.primary),
                label: Text('PDF',
                    style: GoogleFonts.poppins(
                        fontSize: 11, color: AppColors.primary)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary.withOpacity(0.15),
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  elevation: 0,
                ),
              ),
            ),
          ]),
        ],
      ]),
    );
  }
}

/// Date separator header with Indonesian labels.
class _DateHeader extends StatelessWidget {
  final String dateStr; // YYYY-MM-DD
  const _DateHeader({required this.dateStr});

  static const _months = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
  ];

  String _label() {
    final today = DateTime.now();
    final todayStr = today.toIso8601String().substring(0, 10);
    final yesterdayStr = today.subtract(const Duration(days: 1))
        .toIso8601String().substring(0, 10);

    if (dateStr == todayStr) return 'Hari Ini';
    if (dateStr == yesterdayStr) return 'Kemarin';

    // Format: "12 Juni 2026"
    final parts = dateStr.split('-');
    if (parts.length == 3) {
      final day = int.tryParse(parts[2]) ?? 0;
      final month = int.tryParse(parts[1]) ?? 0;
      final year = parts[0];
      if (month >= 1 && month <= 12) {
        return '$day ${_months[month]} $year';
      }
    }
    return dateStr;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.secondary.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(_label(),
              style: GoogleFonts.poppins(
                  color: AppColors.secondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Divider(color: AppColors.divider.withOpacity(0.4))),
      ]),
    );
  }
}

class _TrxCard extends StatelessWidget {
  final Map t;
  final VoidCallback onTap;

  const _TrxCard({
    required this.t,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final status = t['status'] as String;
    final amount = double.parse(t['amount'].toString());
    final booking = t['booking'] as Map?;
    final userName = booking?['user']?['name'] ?? '-';
    final services = booking?['services'] as List?;
    final service = (services != null && services.isNotEmpty)
        ? services.map((s) => s['name']).join(', ')
        : (booking?['service']?['name'] ?? '-');
    final barber = booking?['barber']?['name'] ?? '-';
    final date = (booking?['booking_date'] as String?)?.formattedDate ?? '-';
    final time = (booking?['booking_time'] as String? ?? '').length >= 5
        ? (booking?['booking_time'] as String).substring(0, 5)
        : '';
    final paidAtStr = t['paid_at'] as String?;
    final paidAt = paidAtStr?.formattedDateTime;
    final createdAt = (t['created_at'] as String?)?.formattedDateTime;
    final method = t['payment_method'] as String?;
    final isCashless = method == 'cashless';

    final Color color;
    final String label;
    switch (status) {
      case 'paid':
        color = AppColors.success;
        label = 'Dibayar';
        break;
      case 'pending':
        color = AppColors.warning;
        label = isCashless ? 'Tunggu Tunai' : 'Menunggu';
        break;
      case 'expired':
        color = AppColors.error;
        label = 'Kadaluarsa';
        break;
      default:
        color = AppColors.error;
        label = 'Gagal';
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child:
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                    status == 'paid'
                        ? Icons.check_circle_outline
                        : Icons.receipt_outlined,
                    color: color,
                    size: 18),
              ),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(userName,
                    style: GoogleFonts.poppins(
                        color: AppColors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
                Text(t['order_id'] ?? '',
                    style: GoogleFonts.poppins(
                        color: AppColors.grey, fontSize: 10)),
              ]),
            ]),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(amount.toRupiah,
                  style: GoogleFonts.poppins(
                      color: status == 'paid'
                          ? AppColors.success
                          : AppColors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(label,
                    style: GoogleFonts.poppins(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              ),
            ]),
          ]),
        ),

        // Detail layanan & tanggal
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          child: Column(children: [
            Row(children: [
              Expanded(child: _infoItem(Icons.content_cut, 'Layanan', service)),
              Expanded(
                  child: _infoItem(Icons.person_outline, 'Barber', barber)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _infoItem(Icons.calendar_today, 'Tanggal', date)),
              Expanded(child: _infoItem(Icons.access_time, 'Pukul', time)),
            ]),
            if (createdAt != null) ...[
              const SizedBox(height: 6),
              _infoItem(Icons.schedule, 'Transaksi dibuat', createdAt),
            ],
            if (paidAt != null) ...[
              const SizedBox(height: 6),
              _infoItem(Icons.payments_outlined, 'Dibayar pada', paidAt),
            ],
            if (t['payment_method'] != null) ...[
              const SizedBox(height: 4),
              _infoItem(Icons.credit_card, 'Metode',
                  (t['payment_method'] as String?).paymentLabel),
            ],
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('Lihat detail',
                    style: GoogleFonts.poppins(
                        color: AppColors.secondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w600)),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right,
                    color: AppColors.secondary, size: 14),
              ],
            ),
          ]),
        ),
      ]),
    ),
    );
  }

  Widget _infoItem(IconData icon, String label, String value) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.grey, size: 12),
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
                        color: AppColors.lightGrey,
                        fontSize: 11,
                        fontWeight: FontWeight.w500)),
              ])),
        ],
      );
}
