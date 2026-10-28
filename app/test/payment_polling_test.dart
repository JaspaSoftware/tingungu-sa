import 'package:flutter_test/flutter_test.dart';
import 'package:tingungu_app/services/payment_api.dart';

void main() {
  test('waitForCompletion checks only the requested payment ID', () async {
    final lookedUpIds = <String>[];
    final result = await PaymentApi.waitForCompletion(
      'payment-42',
      statusLookup: (paymentId) async {
        lookedUpIds.add(paymentId);
        return lookedUpIds.length == 1
            ? PaymentState.pending
            : PaymentState.complete;
      },
    );

    expect(lookedUpIds, ['payment-42', 'payment-42']);
    expect(result.status, PaymentState.complete);
    expect(result.timedOut, isFalse);
  });

  test('returns a confirmed success immediately', () async {
    final result = await pollPaymentStatus(
      fetchStatus: () async => PaymentState.complete,
    );

    expect(result.status, PaymentState.complete);
    expect(result.timedOut, isFalse);
    expect(result.hadStatusCheckErrors, isFalse);
  });

  test(
    'returns a confirmed failure instead of treating it as a timeout',
    () async {
      final result = await pollPaymentStatus(
        fetchStatus: () async => PaymentState.failed,
      );

      expect(result.status, PaymentState.failed);
      expect(result.timedOut, isFalse);
    },
  );

  test('returns a trusted cancellation as a final state', () async {
    final result = await pollPaymentStatus(
      fetchStatus: () async => PaymentState.cancelled,
    );

    expect(result.status, PaymentState.cancelled);
    expect(result.timedOut, isFalse);
  });

  test(
    'keeps a payment pending when the full polling window expires',
    () async {
      var now = DateTime(2026, 10, 28);
      var calls = 0;
      final result = await pollPaymentStatus(
        fetchStatus: () async {
          calls++;
          return PaymentState.pending;
        },
        now: () => now,
        delay: (duration) async => now = now.add(duration),
      );

      expect(result.status, PaymentState.pending);
      expect(result.timedOut, isTrue);
      expect(calls, 15);
    },
  );

  test('returns a final state received just before the timeout', () async {
    var now = DateTime(2026, 10, 28);
    var calls = 0;
    final result = await pollPaymentStatus(
      fetchStatus: () async {
        calls++;
        return calls == 15 ? PaymentState.complete : PaymentState.pending;
      },
      now: () => now,
      delay: (duration) async => now = now.add(duration),
    );

    expect(result.status, PaymentState.complete);
    expect(result.timedOut, isFalse);
    expect(calls, 15);
  });

  test(
    'stops at the first final result using the configured interval',
    () async {
      var now = DateTime(2026, 10, 28);
      var calls = 0;
      final delays = <Duration>[];
      final result = await pollPaymentStatus(
        fetchStatus: () async {
          calls++;
          return calls == 1 ? PaymentState.pending : PaymentState.complete;
        },
        timeout: const Duration(seconds: 10),
        interval: const Duration(seconds: 3),
        now: () => now,
        delay: (duration) async {
          delays.add(duration);
          now = now.add(duration);
        },
      );

      expect(result.status, PaymentState.complete);
      expect(result.timedOut, isFalse);
      expect(calls, 2);
      expect(delays, [const Duration(seconds: 3)]);
    },
  );

  test('keeps malformed status responses unresolved until timeout', () async {
    var now = DateTime(2026, 10, 28);
    final result = await pollPaymentStatus(
      fetchStatus: () async =>
          paymentStateFromResponse({'status': 'unrecognized'}),
      timeout: const Duration(seconds: 4),
      interval: const Duration(seconds: 2),
      now: () => now,
      delay: (duration) async => now = now.add(duration),
    );

    expect(result.status, PaymentState.pending);
    expect(result.timedOut, isTrue);
    expect(result.hadStatusCheckErrors, isTrue);
  });

  test('keeps network errors unresolved through the polling timeout', () async {
    var now = DateTime(2026, 10, 28);
    final result = await pollPaymentStatus(
      fetchStatus: () async => throw Exception('network unavailable'),
      now: () => now,
      delay: (duration) async => now = now.add(duration),
    );

    expect(result.status, PaymentState.pending);
    expect(result.timedOut, isTrue);
    expect(result.hadStatusCheckErrors, isTrue);
  });

  test(
    'does not convert an intermittent lookup error into payment failure',
    () async {
      var now = DateTime(2026, 10, 28);
      var calls = 0;
      final result = await pollPaymentStatus(
        fetchStatus: () async {
          calls++;
          if (calls == 1) throw Exception('temporary server error');
          return PaymentState.pending;
        },
        timeout: const Duration(seconds: 4),
        interval: const Duration(seconds: 2),
        now: () => now,
        delay: (duration) async => now = now.add(duration),
      );

      expect(result.status, PaymentState.pending);
      expect(result.timedOut, isTrue);
      expect(result.hadStatusCheckErrors, isTrue);
    },
  );
}
