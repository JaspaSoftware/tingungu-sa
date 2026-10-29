import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tingungu_app/screens/payment_status_screen.dart';
import 'package:tingungu_app/services/payment_api.dart';

void main() {
  testWidgets('a later status check updates pending to confirmed success', (
    tester,
  ) async {
    final lookedUpIds = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: PaymentStatusScreen(
          paymentId: 'payment-late-success',
          purpose: 'topup',
          initialResult: const PaymentPollResult(
            status: PaymentState.pending,
            timedOut: true,
          ),
          statusLookup: (paymentId) async {
            lookedUpIds.add(paymentId);
            return PaymentState.complete;
          },
        ),
      ),
    );

    expect(find.text('Payment Processing'), findsNWidgets(2));
    await tester.tap(find.text('Check status'));
    await tester.pumpAndSettle();

    expect(lookedUpIds, ['payment-late-success']);
    expect(find.text('Payment Successful'), findsNWidgets(2));
    expect(find.text('Check status'), findsNothing);
    expect(
      find.textContaining('Your wallet top-up has been confirmed'),
      findsOneWidget,
    );
  });

  testWidgets('status lookup errors preserve pending and show uncertainty', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PaymentStatusScreen(
          paymentId: 'payment-pending',
          purpose: 'topup',
          initialResult: const PaymentPollResult(
            status: PaymentState.pending,
            timedOut: true,
          ),
          statusLookup: (_) async => throw Exception('private provider detail'),
        ),
      ),
    );

    await tester.tap(find.text('Check status'));
    await tester.pumpAndSettle();

    expect(find.text('Payment Processing'), findsNWidgets(2));
    expect(find.textContaining('outcome is not confirmed'), findsOneWidget);
    expect(find.textContaining('private provider detail'), findsNothing);
    expect(find.text('Payment Failed'), findsNothing);
    expect(find.text('Payment Cancelled'), findsNothing);
  });

  testWidgets('disables overlapping status refreshes and queries once', (
    tester,
  ) async {
    final response = Completer<PaymentState>();
    var lookupCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: PaymentStatusScreen(
          paymentId: 'payment-one-lookup',
          purpose: 'topup',
          initialResult: const PaymentPollResult(
            status: PaymentState.pending,
            timedOut: true,
          ),
          statusLookup: (_) {
            lookupCount++;
            return response.future;
          },
        ),
      ),
    );

    await tester.tap(find.text('Check status'));
    await tester.pump();
    expect(find.text('Checking status...'), findsOneWidget);
    expect(tester.widget<OutlinedButton>(
      find.ancestor(
        of: find.text('Checking status...'),
        matching: find.byType(OutlinedButton),
      ),
    ).onPressed, isNull);

    response.complete(PaymentState.pending);
    await tester.pumpAndSettle();

    expect(lookupCount, 1);
    expect(find.text('Payment Processing'), findsNWidgets(2));
  });

  testWidgets('ignores a status lookup that completes after screen disposal', (
    tester,
  ) async {
    final response = Completer<PaymentState>();
    await tester.pumpWidget(
      MaterialApp(
        home: PaymentStatusScreen(
          paymentId: 'payment-disposed',
          purpose: 'topup',
          initialResult: const PaymentPollResult(
            status: PaymentState.pending,
            timedOut: true,
          ),
          statusLookup: (_) => response.future,
        ),
      ),
    );

    await tester.tap(find.text('Check status'));
    await tester.pump();
    Navigator.of(
      tester.element(find.byType(PaymentStatusScreen)),
    ).pop();
    await tester.pump();
    response.complete(PaymentState.complete);
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  for (final (state, title) in [
    (PaymentState.complete, 'Payment Successful'),
    (PaymentState.failed, 'Payment Failed'),
    (PaymentState.cancelled, 'Payment Cancelled'),
    (PaymentState.pending, 'Payment Processing'),
  ]) {
    testWidgets('shows the correct initial UI for $state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PaymentStatusScreen(
            paymentId: 'payment-${state.name}',
            purpose: 'topup',
            initialResult: PaymentPollResult(status: state, timedOut: false),
          ),
        ),
      );

      expect(find.text(title), findsNWidgets(2));
    });
  }
}
