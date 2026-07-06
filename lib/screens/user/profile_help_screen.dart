import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/app_colors.dart';

class ProfileHelpScreen extends StatelessWidget {
  const ProfileHelpScreen({super.key});

  static const _faqs = [
    (
      'Bagaimana cara booking?',
      'Pilih layanan dan barber di menu Home, tentukan tanggal & jam, lalu kirim permintaan booking.',
    ),
    (
      'Kapan bisa bayar?',
      'Setelah admin mengonfirmasi booking, tombol bayar muncul di Riwayat atau notifikasi.',
    ),
    (
      'Metode pembayaran apa saja?',
      'Kamu bisa bayar online (QRIS / Virtual Account) atau tunai langsung di tempat saat kedatangan.',
    ),
    (
      'Bisa ubah jadwal?',
      'Ya, selama booking belum dibayar dan masih dalam status yang diizinkan, gunakan tombol Ubah Jadwal.',
    ),
    (
      'Cara batalkan booking?',
      'Buka Riwayat Booking, pilih booking yang ingin dibatalkan, lalu tap Batalkan.',
    ),
    (
      'Butuh bantuan lebih lanjut?',
      'Hubungi admin Arfan Barbershop melalui nomor yang tertera di halaman Tentang App.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Bantuan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: AppColors.goldGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.support_agent,
                      color: AppColors.primary, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pusat Bantuan',
                        style: GoogleFonts.playfairDisplay(
                          color: AppColors.primary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Jawaban singkat untuk pertanyaan umum',
                        style: GoogleFonts.poppins(
                          color: AppColors.primary.withValues(alpha: 0.75),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Pertanyaan Umum',
            style: GoogleFonts.poppins(
              color: AppColors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          ..._faqs.map(
            (f) => _FaqTile(question: f.$1, answer: f.$2),
          ),
        ],
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  final String question;
  final String answer;

  const _FaqTile({required this.question, required this.answer});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          iconColor: AppColors.secondary,
          collapsedIconColor: AppColors.grey,
          title: Text(
            question,
            style: GoogleFonts.poppins(
              color: AppColors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  answer,
                  style: GoogleFonts.poppins(
                    color: AppColors.lightGrey,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
