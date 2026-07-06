// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/admin_refund_provider.dart';
import '../../utils/app_colors.dart';
import '../../utils/extensions.dart';
import '../../widgets/shimmer_loading.dart';

class AdminRefundScreen extends StatefulWidget {
  const AdminRefundScreen({super.key});
  @override
  State<AdminRefundScreen> createState() => _AdminRefundScreenState();
}

class _AdminRefundScreenState extends State<AdminRefundScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminRefundProvider>().fetchRefunds();
    });
  }

  Future<void> _refresh() async {
    await context.read<AdminRefundProvider>().fetchRefunds();
  }

  Future<void> _approve(int id) async {
    final noteController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Konfirmasi Refund',
            style: GoogleFonts.poppins(
                color: AppColors.white, fontWeight: FontWeight.bold)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            'Pastikan kamu sudah melakukan refund manual di dashboard Pakasir.',
            style: GoogleFonts.poppins(color: AppColors.grey, fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: noteController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Catatan admin (opsional)',
              hintStyle: GoogleFonts.poppins(color: AppColors.grey, fontSize: 13),
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.secondary, width: 1.5)),
            ),
            style: GoogleFonts.poppins(color: AppColors.white, fontSize: 13),
            textCapitalization: TextCapitalization.sentences,
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Batal',
                style: GoogleFonts.poppins(color: AppColors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, noteController.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Sudah Direfund'),
          ),
        ],
      ),
    );
    if (result == null || !mounted) return;
    await context.read<AdminRefundProvider>().approveRefund(id, adminNote: result);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Refund berhasil dikonfirmasi',
          style: GoogleFonts.poppins(color: Colors.white)),
      backgroundColor: AppColors.success,
    ));
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Refund'),
      ),
      body: Consumer<AdminRefundProvider>(
        builder: (_, provider, __) {
          if (provider.isLoading && provider.refunds.isEmpty) {
            return const ShimmerList(
              itemBuilder: ShimmerAdminCard.new,
              count: 3,
            );
          }
          if (provider.error != null && provider.refunds.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_outline,
                        color: AppColors.grey, size: 56),
                    const SizedBox(height: 12),
                    Text('Tidak ada refund pending',
                        style: GoogleFonts.poppins(
                            color: AppColors.grey, fontSize: 14)),
                  ],
                ),
              ),
            );
          }
          if (provider.refunds.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_outline,
                      color: AppColors.grey, size: 56),
                  const SizedBox(height: 12),
                  Text('Semua refund sudah selesai',
                      style: GoogleFonts.poppins(
                          color: AppColors.grey, fontSize: 14)),
                ],
              ),
            );
          }
          return RefreshIndicator(
            color: AppColors.secondary,
            onRefresh: _refresh,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: provider.refunds.length,
              itemBuilder: (_, i) {
                final r = provider.refunds[i];
                final booking = r['booking'] as Map?;
                final user = booking?['user'] as Map?;
                final userName = user?['name'] ?? '-';
                final amount = double.parse(r['amount'].toString());
                final orderId = r['order_id'] ?? '-';
                final date = (r['created_at'] as String?)?.formattedDate ?? '-';
                final services = booking?['services'] as List?;
                final service = (services != null && services.isNotEmpty)
                    ? services.map((s) => s['name']).join(', ')
                    : '-';

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: AppColors.error.withOpacity(0.3)),
                  ),
                  child: Column(children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.08),
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16)),
                      ),
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: AppColors.error.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                    Icons.replay_outlined,
                                    color: AppColors.error,
                                    size: 18),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(userName,
                                        style: GoogleFonts.poppins(
                                            color: AppColors.white,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13)),
                                    Text(orderId,
                                        style: GoogleFonts.poppins(
                                            color: AppColors.grey,
                                            fontSize: 10)),
                                  ]),
                            ]),
                            Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(amount.toRupiah,
                                      style: GoogleFonts.poppins(
                                          color: AppColors.error,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13)),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.error.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text('Refund',
                                        style: GoogleFonts.poppins(
                                            color: AppColors.error,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                ]),
                          ]),
                    ),
                    // Body
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                      child: Column(children: [
                        Row(children: [
                          Expanded(
                            child: _infoItem(
                                Icons.content_cut, 'Layanan', service),
                          ),
                          const SizedBox(width: 8),
                        ]),
                        const SizedBox(height: 6),
                        Row(children: [
                          Expanded(
                            child: _infoItem(
                                Icons.calendar_today, 'Tanggal', date),
                          ),
                        ]),
                        if (r['paid_at'] != null) ...[
                          const SizedBox(height: 6),
                          _infoItem(Icons.payments_outlined, 'Dibayar pada',
                              (r['paid_at'] as String).formattedDate),
                        ],
                        if (r['cancel_reason'] != null &&
                            (r['cancel_reason'] as String).isNotEmpty) ...[
                          const SizedBox(height: 6),
                          _infoItem(Icons.info_outline, 'Alasan pembatalan',
                              r['cancel_reason']),
                        ],
                        if (r['admin_note'] != null &&
                            (r['admin_note'] as String).isNotEmpty) ...[
                          const SizedBox(height: 6),
                          _infoItem(Icons.notes, 'Catatan admin',
                              r['admin_note']),
                        ],
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _approve(r['id']),
                            icon: const Icon(Icons.check_circle_outline,
                                size: 16, color: Colors.white),
                            label: Text('Sudah Direfund',
                                style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.error,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ]),
                    ),
                  ]),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _infoItem(IconData icon, String label, String value) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.grey, size: 12),
          const SizedBox(width: 4),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: GoogleFonts.poppins(
                      color: AppColors.grey, fontSize: 10)),
              Text(value,
                  style: GoogleFonts.poppins(
                      color: AppColors.lightGrey,
                      fontSize: 11,
                      fontWeight: FontWeight.w500)),
            ]),
          ),
        ],
      );
}
