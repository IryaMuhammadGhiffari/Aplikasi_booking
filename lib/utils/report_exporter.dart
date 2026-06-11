import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

class ReportExporter {
  static String _csvEscape(String? value) {
    final v = (value ?? '').replaceAll('"', '""');
    return '"$v"';
  }

  static String _servicesFromBooking(Map? booking) {
    if (booking == null) return '-';
    final services = booking['services'] as List?;
    if (services != null && services.isNotEmpty) {
      return services.map((s) => s['name']).join(', ');
    }
    return booking['service']?['name']?.toString() ?? '-';
  }

  static String _formatPaymentMethod(String? method) {
    if (method == null || method.isEmpty) return '-';
    const labels = {
      'credit_card': 'Kartu Kredit',
      'bank_transfer': 'Transfer Bank',
      'echannel': 'Mandiri Bill',
      'bca_va': 'BCA Virtual Account',
      'bni_va': 'BNI Virtual Account',
      'bri_va': 'BRI Virtual Account',
      'permata_va': 'Permata Virtual Account',
      'other_va': 'Virtual Account',
      'gopay': 'GoPay',
      'shopeepay': 'ShopeePay',
      'qris': 'QRIS',
      'cstore': 'Alfamart/Indomaret',
      'cashless': 'Bayar di Tempat (Tunai)',
    };
    return labels[method] ?? method.replaceAll('_', ' ');
  }

  static String _statusLabel(String status, String? method) {
    switch (status) {
      case 'paid':
        return 'Dibayar';
      case 'pending':
        return 'Menunggu';
      case 'expired':
        return 'Kadaluarsa';
      case 'failed':
        return 'Gagal';
      default:
        return status;
    }
  }

  static String _rp(num v) =>
      'Rp ${v.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';

  static Future<void> _shareFile(File file, {String? subject}) async {
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: subject,
      text: subject,
    );
  }

  static Future<void> exportTransactionsCsv(List transactions) async {
    final header = [
      'Order ID',
      'Nama Pelanggan',
      'Layanan',
      'Barber',
      'Tanggal Booking',
      'Waktu',
      'Jumlah',
      'Status',
      'Metode Pembayaran',
      'Dibayar Pada',
      'Catatan',
    ];

    final rows = transactions.map((t) {
      final booking = t['booking'] as Map?;
      final time = (booking?['booking_time'] as String? ?? '');
      final timeShort = time.length >= 5 ? time.substring(0, 5) : time;
      return [
        t['order_id']?.toString() ?? '-',
        booking?['user']?['name']?.toString() ?? '-',
        _servicesFromBooking(booking),
        booking?['barber']?['name']?.toString() ?? '-',
        booking?['booking_date']?.toString() ?? '-',
        timeShort,
        t['amount']?.toString() ?? '0',
        _statusLabel(
          t['status']?.toString() ?? '',
          t['payment_method']?.toString(),
        ),
        _formatPaymentMethod(t['payment_method']?.toString()),
        t['paid_at']?.toString() ?? '-',
        booking?['notes']?.toString() ?? '-',
      ].map(_csvEscape).join(',');
    });

    final csv = '${header.map(_csvEscape).join(',')}\n${rows.join('\n')}';
    final dir = await getTemporaryDirectory();
    final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final file = File('${dir.path}/laporan_transaksi_$stamp.csv');
    await file.writeAsString(csv);
    await _shareFile(file, subject: 'Laporan Transaksi Arfan Barbershop');
  }

  static Future<void> exportRevenueCsv({
    required List report,
    required double totalRevenue,
    required DateTime start,
    required DateTime end,
  }) async {
    final startStr = DateFormat('d MMM yyyy').format(start);
    final endStr = DateFormat('d MMM yyyy').format(end);

    final header = ['Tanggal', 'Jumlah Transaksi', 'Total Pendapatan'];
    final rows = report.map((r) {
      return [
        r['date']?.toString() ?? '-',
        r['count']?.toString() ?? '0',
        r['total']?.toString() ?? '0',
      ].map(_csvEscape).join(',');
    }).toList();

    rows.add(
      [
        'TOTAL',
        report
            .fold<int>(
              0,
              (sum, r) =>
                  sum + (int.tryParse(r['count']?.toString() ?? '0') ?? 0),
            )
            .toString(),
        totalRevenue.toStringAsFixed(0),
      ].map(_csvEscape).join(','),
    );

    final meta = [
      _csvEscape('Periode'),
      _csvEscape('$startStr - $endStr'),
    ].join(',');

    final csv =
        '$meta\n${header.map(_csvEscape).join(',')}\n${rows.join('\n')}';
    final dir = await getTemporaryDirectory();
    final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final file = File('${dir.path}/laporan_pendapatan_$stamp.csv');
    await file.writeAsString(csv);
    await _shareFile(file, subject: 'Laporan Pendapatan $startStr - $endStr');
  }

  static Future<void> exportTransactionsPdf(List transactions) async {
    final pdf = pw.Document();
    final stamp = DateFormat('d MMMM yyyy, HH:mm').format(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Text(
            'Laporan Transaksi',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Arfan Barbershop — $stamp',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 16),
          if (transactions.isEmpty)
            pw.Text('Tidak ada data transaksi.')
          else
            pw.Table.fromTextArray(
              headers: ['Order ID', 'Pelanggan', 'Layanan', 'Jumlah', 'Status'],
              data: transactions.map((t) {
                final booking = t['booking'] as Map?;
                return [
                  t['order_id']?.toString() ?? '-',
                  booking?['user']?['name']?.toString() ?? '-',
                  _servicesFromBooking(booking),
                  _rp(double.tryParse(t['amount']?.toString() ?? '0') ?? 0),
                  _statusLabel(
                    t['status']?.toString() ?? '',
                    t['payment_method']?.toString(),
                  ),
                ];
              }).toList(),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 9,
              ),
              cellStyle: const pw.TextStyle(fontSize: 8),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
              cellAlignment: pw.Alignment.centerLeft,
              columnWidths: {
                0: const pw.FlexColumnWidth(2),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(2.5),
                3: const pw.FlexColumnWidth(1.5),
                4: const pw.FlexColumnWidth(1.5),
              },
            ),
        ],
      ),
    );

    final dir = await getTemporaryDirectory();
    final fileStamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final file = File('${dir.path}/laporan_transaksi_$fileStamp.pdf');
    await file.writeAsBytes(await pdf.save());
    await _shareFile(file, subject: 'Laporan Transaksi Arfan Barbershop');
  }

  static Future<void> exportRevenuePdf({
    required List report,
    required double totalRevenue,
    required DateTime start,
    required DateTime end,
  }) async {
    final pdf = pw.Document();
    final startStr = DateFormat('d MMM yyyy').format(start);
    final endStr = DateFormat('d MMM yyyy').format(end);
    final stamp = DateFormat('d MMMM yyyy, HH:mm').format(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Text(
            'Laporan Pendapatan',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Arfan Barbershop',
            style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Periodo: $startStr — $endStr',
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.Text(
            'Diekspor: $stamp',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 12),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.amber100,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Text(
              'Total Pendapatan: ${_rp(totalRevenue)}',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.SizedBox(height: 16),
          if (report.isEmpty)
            pw.Text('Tidak ada pendapatan pada periode ini.')
          else
            pw.Table.fromTextArray(
              headers: ['Tanggal', 'Transaksi', 'Pendapatan'],
              data: report
                  .map(
                    (r) => [
                      r['date']?.toString() ?? '-',
                      r['count']?.toString() ?? '0',
                      _rp(double.tryParse(r['total']?.toString() ?? '0') ?? 0),
                    ],
                  )
                  .toList(),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 10,
              ),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
            ),
        ],
      ),
    );

    final dir = await getTemporaryDirectory();
    final fileStamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final file = File('${dir.path}/laporan_pendapatan_$fileStamp.pdf');
    await file.writeAsBytes(await pdf.save());
    await _shareFile(file, subject: 'Laporan Pendapatan $startStr - $endStr');
  }
}
