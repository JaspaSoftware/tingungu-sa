import 'package:flutter/material.dart';
import 'package:pay/pay.dart';
import '../screens/payfast_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentMethodSelector extends StatefulWidget {
  final double amount;
  final String title;
  final String description;
  final Function(String method) onPaymentSuccess;
  final VoidCallback onPaymentFailed;

  const PaymentMethodSelector({
    super.key,
    required this.amount,
    required this.title,
    required this.description,
    required this.onPaymentSuccess,
    required this.onPaymentFailed,
  });

  @override
  State<PaymentMethodSelector> createState() => _PaymentMethodSelectorState();
}

class _PaymentMethodSelectorState extends State<PaymentMethodSelector> {
  bool _isProcessing = false;

  final Future<PaymentConfiguration> _googlePayConfigFuture =
      PaymentConfiguration.fromAsset('pay/default_google_pay_config.json');

  void _onGooglePayResult(dynamic result) {
    debugPrint('Google Pay result: $result');
    widget.onPaymentSuccess('Google Pay');
  }

  Future<void> _processWalletPayment() async {
    setState(() => _isProcessing = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("Not logged in");

      final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) throw Exception("User not found");

        final balance = (snapshot.data()?['wallet_balance'] ?? 0.0).toDouble();
        if (balance < widget.amount) {
          throw Exception("Insufficient wallet balance");
        }

        // Deduct balance
        transaction.update(docRef, {'wallet_balance': balance - widget.amount});
      });

      widget.onPaymentSuccess('Wallet');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll("Exception: ", "")), backgroundColor: Colors.red),
      );
      widget.onPaymentFailed();
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _processPayFastPayment() {
    final user = FirebaseAuth.instance.currentUser;
    final Map<String, String> formData = {
      'receiver': '14362369', // Replace with actual PayFast merchant ID
      'item_name': widget.title,
      'item_description': widget.description,
      'amount': widget.amount.toStringAsFixed(2),
      'return_url': 'https://www.tingungu.co.za/success',
      'cancel_url': 'https://www.tingungu.co.za/cancel',
      'notify_url': 'https://www.tingungu.co.za/notify',
      'name_first': user?.displayName?.split(' ').first ?? 'Guest',
      'email_address': user?.email ?? 'conferencendlovu@gmail.com',
    };

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PayFastWebView(formData: formData),
      ),
    ).then((result) {
      // If result is true, payment was successful
      if (result == true) {
        widget.onPaymentSuccess('PayFast');
      }
    });
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
              const Text(
                'Other Options',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              FutureBuilder<PaymentConfiguration>(
                future: _googlePayConfigFuture,
                builder: (context, snapshot) => snapshot.hasData
                    ? GooglePayButton(
                        paymentConfiguration: snapshot.data!,
                        paymentItems: [
                          PaymentItem(
                            label: widget.title,
                            amount: widget.amount.toStringAsFixed(2),
                            status: PaymentItemStatus.final_price,
                          )
                        ],
                        type: GooglePayButtonType.buy,
                        margin: const EdgeInsets.only(top: 15.0),
                        onPaymentResult: _onGooglePayResult,
                        loadingIndicator: const Center(child: CircularProgressIndicator()),
                        width: double.infinity,
                      )
                    : const SizedBox.shrink(),
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
              color: Colors.black.withOpacity(0.02),
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
                color: const Color(0xFF3B0D11).withOpacity(0.05),
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
