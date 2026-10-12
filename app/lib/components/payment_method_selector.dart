import 'package:flutter/material.dart';
import '../screens/payfast_page.dart';
import '../services/payment_api.dart';

class PaymentMethodSelector extends StatefulWidget {
  final double amount;
  final String title;
  final String description;
  final String purpose;
  final String? givingOptionId;
  final Function(String method) onPaymentSuccess;
  final VoidCallback onPaymentFailed;

  const PaymentMethodSelector({
    super.key,
    required this.amount,
    required this.title,
    required this.description,
    required this.purpose,
    this.givingOptionId,
    required this.onPaymentSuccess,
    required this.onPaymentFailed,
  });

  @override
  State<PaymentMethodSelector> createState() => _PaymentMethodSelectorState();
}

class _PaymentMethodSelectorState extends State<PaymentMethodSelector> {
  bool _isProcessing = false;

  Future<void> _processWalletPayment() async {
    setState(() => _isProcessing = true);
    try {
      await PaymentApi.payWithWallet(
        amount: widget.amount,
        purpose: widget.purpose,
        givingOptionId: widget.givingOptionId,
        note: widget.description,
      );
      widget.onPaymentSuccess('Wallet');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
      widget.onPaymentFailed();
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _processPayFastPayment() async {
    setState(() => _isProcessing = true);
    try {
      final session = await PaymentApi.startPayFast(
        amount: widget.amount,
        purpose: widget.purpose,
        givingOptionId: widget.givingOptionId,
        note: widget.description,
      );
      if (!mounted) return;
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PayFastWebView(session: session, isWalletTopUp: false),
        ),
      );
      if (result == true) {
        widget.onPaymentSuccess('PayFast');
      } else {
        widget.onPaymentFailed();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
      widget.onPaymentFailed();
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: bottomInset + 24,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFFFAF9F6),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Choose Payment Method',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF3B0D11)),
                  ),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Total Amount: R ${widget.amount.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFFFB8B24)),
              ),
              const SizedBox(height: 24),
              _buildPaymentOption(
                title: 'Tingungu Wallet',
                subtitle: 'Pay using your wallet balance',
                icon: Icons.account_balance_wallet_outlined,
                onTap: _isProcessing ? null : _processWalletPayment,
                isLoading: _isProcessing,
              ),
              const SizedBox(height: 12),
              _buildPaymentOption(
                title: 'PayFast',
                subtitle: 'Credit Card, Instant EFT, and more',
                icon: Icons.payment_outlined,
                onTap: _isProcessing ? null : _processPayFastPayment,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback? onTap,
    bool isLoading = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 5,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF3B0D11).withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: const Color(0xFF3B0D11)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                ],
              ),
            ),
            if (isLoading)
              const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            else
              const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
