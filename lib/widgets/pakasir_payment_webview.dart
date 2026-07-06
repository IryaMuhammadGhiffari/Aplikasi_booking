// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../providers/booking_provider.dart';
import '../utils/app_colors.dart';

/// WebView pembayaran Pakasir — polling silent, auto-redirect saat lunas.
class PakasirPaymentWebView extends StatefulWidget {
  final int bookingId;
  final String initialSnapUrl;
  final VoidCallback onClose;
  final void Function(bool success) onPaymentFinished;

  const PakasirPaymentWebView({
    super.key,
    required this.bookingId,
    required this.initialSnapUrl,
    required this.onClose,
    required this.onPaymentFinished,
  });

  @override
  State<PakasirPaymentWebView> createState() => _PakasirPaymentWebViewState();
}

class _PakasirPaymentWebViewState extends State<PakasirPaymentWebView> {
  late WebViewController _ctrl;
  static const _maxPollDuration = Duration(minutes: 5);
  DateTime? _pollStartTime;
  int _pollAttempts = 0;
  bool _completed = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _pollStartTime = DateTime.now();
    _ctrl = _buildController(widget.initialSnapUrl);
    _scheduleNextPoll();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _verifyPaid() async {
    if (_completed || !mounted) return;
    try {
      final paid = await context
          .read<BookingProvider>()
          .verifyBookingPaid(widget.bookingId)
          .timeout(const Duration(seconds: 15));
      if (paid && mounted) {
        _completed = true;
        widget.onPaymentFinished(true);
      }
    } catch (_) {
      // silent — lanjut poll berikutnya
    }
  }

  void _scheduleNextPoll() {
    if (_completed || !mounted) return;
    final elapsed = DateTime.now().difference(_pollStartTime!);
    if (elapsed >= _maxPollDuration) {
      _pollTimer?.cancel();
      if (mounted) widget.onClose();
      return;
    }

    final delay = _pollAttempts == 0 ? 3 : (_pollAttempts >= 5 ? 60 : 3 * (1 << _pollAttempts));
    _pollTimer = Timer(Duration(seconds: delay > 60 ? 60 : delay), () {
      _pollAttempts++;
      if (!_completed && mounted) {
        _verifyPaid();
        if (!_completed) _scheduleNextPoll();
      }
    });
  }

  WebViewController _buildController(String url) {
    return WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) => _verifyPaid(),
      ))
      ..loadRequest(Uri.parse(url));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        widget.onClose();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => widget.onClose(),
          ),
          title: const Text('Pembayaran Online'),
          centerTitle: true,
        ),
        body: WebViewWidget(controller: _ctrl),
      ),
    );
  }
}
