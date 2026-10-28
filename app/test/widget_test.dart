// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tingungu_app/config/app_config.dart';
import 'package:tingungu_app/screens/payment_status_screen.dart';
import 'package:tingungu_app/services/payment_api.dart';

void main() {
  test('Application config exposes the app and legacy backend endpoints', () {
    expect(AppConfig.apiBaseUrl, contains('api'));
    expect(AppConfig.legacyBackendUrl, contains('backend'));
    expect(AppConfig.communityApiBaseUrl, isEmpty);
  });

  testWidgets('pending payment messaging does not claim cancellation', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PaymentStatusScreen(
          paymentId: 'payment-1',
          purpose: 'topup',
          initialResult: PaymentPollResult(
            status: PaymentState.pending,
            timedOut: true,
          ),
        ),
      ),
    );

    expect(find.text('Payment Processing'), findsNWidgets(2));
    expect(find.text('Check status'), findsOneWidget);
    expect(
      find.textContaining('Your payment status is still being verified'),
      findsOneWidget,
    );
    expect(find.text('Payment Cancelled'), findsNothing);
    expect(find.textContaining('No charges have been made'), findsNothing);
  });
}
