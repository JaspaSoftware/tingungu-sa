import 'package:flutter_test/flutter_test.dart';
import 'package:tingungu_app/services/payment_api.dart';

void main() {
  group('paymentStateFromResponse', () {
    test('parses every status supported by the payment API', () {
      expect(
        paymentStateFromResponse({'status': 'pending'}),
        PaymentState.pending,
      );
      expect(
        paymentStateFromResponse({'status': 'complete'}),
        PaymentState.complete,
      );
      expect(
        paymentStateFromResponse({'status': 'failed'}),
        PaymentState.failed,
      );
      expect(
        paymentStateFromResponse({'status': 'cancelled'}),
        PaymentState.cancelled,
      );
    });

    test('rejects malformed or unknown status responses', () {
      expect(
        () => paymentStateFromResponse(null),
        throwsA(isA<PaymentException>()),
      );
      expect(
        () => paymentStateFromResponse({'status': 200}),
        throwsA(isA<PaymentException>()),
      );
      expect(
        () => paymentStateFromResponse({'status': 'processing'}),
        throwsA(isA<PaymentException>()),
      );
    });
  });
}
