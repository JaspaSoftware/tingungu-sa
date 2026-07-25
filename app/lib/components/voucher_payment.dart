import 'package:flutter/material.dart';

import '../services/purchase_airtime_service.dart';

void processVoucherPayment(
  BuildContext context,
  String voucherCode,
  int productCode,
  int amount,
) async {
  final airtimeService = PurchaseAirtimeService();

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF8B7355).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(40),
            ),
            child: const Icon(
              Icons.local_offer,
              color: Color(0xFF8B7355),
              size: 40,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Processing Purchase',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            voucherCode,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: 50,
            height: 50,
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                const Color(0xFF8B7355).withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  try {
    final result = await airtimeService.purchaseAirtime(
      productCode: productCode,
      amount: amount,
      mobileNumber: voucherCode,
    );

    if (!context.mounted) return;
    Navigator.pop(context);

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✓ ${result['responseMessage'] ?? 'Purchase successful!'}',
          ),
          backgroundColor: const Color(0xFF8B7355),
          duration: const Duration(seconds: 3),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✗ ${result['message'] ?? 'Purchase failed'}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  } catch (e) {
    if (!context.mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✗ Error: ${e.toString()}'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
