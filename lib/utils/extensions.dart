// lib/utils/extensions.dart
// Extension methods to eliminate duplicate formatting code across the app

// ─────────────────────────────────────────────────────────────
// PRICE / RUPIAH FORMAT
// ─────────────────────────────────────────────────────────────

extension PriceFormat on double {
  /// Format ke Rupiah: 35000 → "Rp 35.000"
  String get toRupiah {
    final formatted = toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
    return 'Rp $formatted';
  }
}

extension IntPriceFormat on int {
  String get toRupiah {
    final formatted = toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
    return 'Rp $formatted';
  }
}

extension NumPriceFormat on num {
  String get toRupiah {
    final formatted = toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
    return 'Rp $formatted';
  }
}

// ─────────────────────────────────────────────────────────────
// DATE FORMATTING
// ─────────────────────────────────────────────────────────────

const _monthsIndo = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
];

const _monthsIndoFull = [
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
];

const _daysIndo = [
  'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu',
];

extension DateFormatExt on String {
  /// "2024-03-15" → "15 Mar 2024"
  String get formattedDate {
    try {
      final d = DateTime.parse(this);
      return '${d.day} ${_monthsIndo[d.month - 1]} ${d.year}';
    } catch (_) {
      return this;
    }
  }

  /// "2024-03-15" → "Jumat, 15 Maret 2024"
  String get formattedDateFull {
    try {
      final d = DateTime.parse(this);
      final dayName = _daysIndo[d.weekday - 1];
      return '$dayName, ${d.day} ${_monthsIndoFull[d.month - 1]} ${d.year}';
    } catch (_) {
      return this;
    }
  }

  /// "2026-07-22T11:19:58.000000Z" → "22 Jul 2026, 11:19"
  /// NOTE: Server clock Render off ~1 jam, waktu mungkin kurang akurat.
  String get formattedDateTime {
    try {
      // Hapus timezone (Z, +07:00) biar DateTime.parse pake local time
      final clean = replaceAll(RegExp(r'[Zz](.*)?$|\.\d+'), '');
      final d = DateTime.parse(clean);
      final hour = d.hour.toString().padLeft(2, '0');
      final minute = d.minute.toString().padLeft(2, '0');
      return '${d.day} ${_monthsIndo[d.month - 1]} ${d.year}, $hour:$minute';
    } catch (_) {
      return this;
    }
  }

  /// "2026-07-22T11:19:58.000000Z" → "22 Jul 2026"
  /// Hanya tanggal, tanpa jam — dipakai kalau server clock tidak akurat.
  String get formattedDateOnly {
    try {
      if (length >= 10) {
        final dateStr = substring(0, 10);
        final parts = dateStr.split('-');
        if (parts.length == 3) {
          final d = int.parse(parts[2]);
          final m = int.parse(parts[1]);
          final y = parts[0];
          return '$d ${_monthsIndo[m - 1]} $y';
        }
      }
      return this;
    } catch (_) {
      return this;
    }
  }

  /// "2024-03-15" → "2024-03-15" (normalized, up to first 10 chars)
  String get normalizeDate {
    if (length < 10) return this;
    try {
      return DateTime.parse(substring(0, 10)).toIso8601String().substring(0, 10);
    } catch (_) {
      return substring(0, 10);
    }
  }

  /// "10:00:00" → "10:00"
  String get shortTime {
    return length >= 5 ? substring(0, 5) : this;
  }
}

// ─────────────────────────────────────────────────────────────
// PAYMENT METHOD LABELS
// ─────────────────────────────────────────────────────────────

const Map<String, String> paymentMethodLabels = {
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

extension PaymentMethodLabel on String? {
  String get paymentLabel => paymentMethodLabels[this] ?? (this ?? '-').replaceAll('_', ' ');
}
