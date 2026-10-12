import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class PayFastSession {
  final String paymentId;
  final String processUrl;
  final Map<String, String> formData;
  const PayFastSession(this.paymentId, this.processUrl, this.formData);
}

class PaymentException implements Exception {
  final String message;
  const PaymentException(this.message);
  @override
  String toString() => message;
}

/// Talks to the Tingungu API for every operation that moves money. The server
/// owns balances; the app never writes them.
class PaymentApi {
  PaymentApi._();

  static const String _base =
      'https://tingungu-api.azurewebsites.net/api/payments';

  static Future<Map<String, String>> _headers() async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (token == null) throw const PaymentException('Please log in first');
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static Map<String, dynamic> _decode(http.Response res) {
    Map<String, dynamic> body = {};
    try {
      body = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {}
    if (res.statusCode >= 400) {
      throw PaymentException(
        body['error']?.toString() ?? 'Payment service unavailable',
      );
    }
    return body;
  }

  /// Buys airtime from the wallet. Returns true when delivered, false when the
  /// server could not confirm yet (it will reconcile and refund if needed).
  static Future<bool> buyAirtime({
    required int amount,
    required int productCode,
    required String mobileNumber,
  }) async {
    final res = await http.post(
      Uri.parse(_base.replaceFirst('/payments', '/airtime/purchase')),
      headers: await _headers(),
      body: jsonEncode({
        'amount': amount,
        'productCode': productCode,
        'mobileNumber': mobileNumber,
      }),
    );
    if (res.statusCode == 202) return false;
    _decode(res);
    return true;
  }
  static Future<void> payWithWallet({
    required double amount,
    required String purpose,
    String? givingOptionId,
    String note = '',
  }) async {
    final res = await http.post(
      Uri.parse('$_base/wallet-pay'),
      headers: await _headers(),
      body: jsonEncode({
        'amount': amount,
        'purpose': purpose,
        'givingOptionId': givingOptionId,
        'note': note,
      }),
    );
    _decode(res);
  }

  static Future<PayFastSession> startPayFast({
    required double amount,
    required String purpose,
    String? givingOptionId,
    String note = '',
  }) async {
    final res = await http.post(
      Uri.parse('$_base/payfast/create'),
      headers: await _headers(),
      body: jsonEncode({
        'amount': amount,
        'purpose': purpose,
        'givingOptionId': givingOptionId,
        'note': note,
      }),
    );
    final body = _decode(res);
    return PayFastSession(
      body['paymentId'] as String,
      body['processUrl'] as String,
      (body['formData'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, v.toString()),
      ),
    );
  }

  /// PayFast confirms to the server asynchronously, so poll briefly.
  static Future<bool> waitForCompletion(String paymentId) async {
    for (var i = 0; i < 15; i++) {
      try {
        final res = await http.get(
          Uri.parse('$_base/$paymentId'),
          headers: await _headers(),
        );
        final status = _decode(res)['status'];
        if (status == 'complete') return true;
        if (status == 'failed') return false;
      } catch (_) {}
      await Future.delayed(const Duration(seconds: 2));
    }
    return false;
  }
}
