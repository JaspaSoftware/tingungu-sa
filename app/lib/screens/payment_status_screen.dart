import 'package:flutter/material.dart';

import '../services/payment_api.dart';
import 'home_screen.dart';

class PaymentStatusScreen extends StatefulWidget {
  final String paymentId;
  final String purpose;
  final PaymentPollResult initialResult;
  final Future<PaymentState> Function(String paymentId)? statusLookup;

  const PaymentStatusScreen({
    super.key,
    required this.paymentId,
    required this.purpose,
    required this.initialResult,
    this.statusLookup,
  });

  @override
  State<PaymentStatusScreen> createState() => _PaymentStatusScreenState();
}

class _PaymentStatusScreenState extends State<PaymentStatusScreen> {
  late PaymentState _status;
  bool _isRefreshing = false;
  bool _refreshFailed = false;

  @override
  void initState() {
    super.initState();
    _status = widget.initialResult.status;
    _refreshFailed = widget.initialResult.hadStatusCheckErrors;
  }

  Future<void> _refreshStatus() async {
    setState(() {
      _isRefreshing = true;
      _refreshFailed = false;
    });
    try {
      final status = await (widget.statusLookup ?? PaymentApi.getPaymentStatus)(
        widget.paymentId,
      );
      if (mounted) setState(() => _status = status);
    } catch (_) {
      if (mounted) setState(() => _refreshFailed = true);
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  String get _title => switch (_status) {
    PaymentState.complete => 'Payment Successful',
    PaymentState.failed => 'Payment Failed',
    PaymentState.cancelled => 'Payment Cancelled',
    PaymentState.pending => 'Payment Processing',
  };

  String get _message => switch (_status) {
    PaymentState.complete =>
      widget.purpose == 'topup'
          ? 'Your wallet top-up has been confirmed and the funds are available in your account.'
          : 'Your giving payment has been confirmed. Thank you for your generosity.',
    PaymentState.failed =>
      'PayFast reported that the payment was not completed. If you believe your account was charged, please contact support.',
    PaymentState.cancelled =>
      'PayFast confirmed that this payment was cancelled. Check your account activity if you have questions.',
    PaymentState.pending =>
      'We have not received final confirmation yet. Your payment status is still being verified. Please check again shortly and avoid making another payment until the status is confirmed.',
  };

  Color get _statusColor => switch (_status) {
    PaymentState.complete => const Color(0xFFFB8B24),
    PaymentState.failed || PaymentState.cancelled => const Color(0xFF3B0D11),
    PaymentState.pending => Colors.blueGrey,
  };

  IconData get _statusIcon => switch (_status) {
    PaymentState.complete => Icons.check_rounded,
    PaymentState.failed || PaymentState.cancelled => Icons.close_rounded,
    PaymentState.pending => Icons.hourglass_top_rounded,
  };

  void _returnHome() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPending = _status == PaymentState.pending;
    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: _statusColor),
          onPressed: _returnHome,
        ),
        title: Text(
          _title,
          style: TextStyle(
            color: _statusColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (constraints.maxHeight - 40).clamp(
                  0.0,
                  double.infinity,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: _statusColor,
                        borderRadius: BorderRadius.circular(60),
                        boxShadow: [
                          BoxShadow(
                            color: _statusColor.withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Icon(_statusIcon, color: Colors.white, size: 64),
                    ),
                    const SizedBox(height: 40),
                    Text(
                      _title,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: _statusColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _message,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (_refreshFailed) ...[
                      const SizedBox(height: 12),
                      Text(
                        'We could not check the latest status. Your payment outcome is not confirmed.',
                        style: TextStyle(color: Colors.grey[700]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 32),
                    if (isPending)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _isRefreshing ? null : _refreshStatus,
                          icon: _isRefreshing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.refresh),
                          label: Text(
                            _isRefreshing
                                ? 'Checking status...'
                                : 'Check status',
                          ),
                        ),
                      ),
                    if (!isPending) const SizedBox(height: 16),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _returnHome,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _statusColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Back to App',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
