import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tingungu_app/screens/payfast_page_overlay.dart';

void main() {
  testWidgets('shows a spinner only while the page is loading', (tester) async {
    Widget buildOverlay({
      required bool isLoading,
      required bool hasError,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: PayFastPageOverlay(
            isLoading: isLoading,
            hasError: hasError,
            canRetry: true,
            onRetry: () {},
            onCheckStatus: () {},
          ),
        ),
      );
    }

    await tester.pumpWidget(buildOverlay(isLoading: true, hasError: false));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Unable to load PayFast'), findsNothing);

    await tester.pumpWidget(buildOverlay(isLoading: false, hasError: false));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Unable to load PayFast'), findsNothing);
  });

  testWidgets('offers retry with safe, non-outcome error copy', (tester) async {
    var retryCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PayFastPageOverlay(
            isLoading: false,
            hasError: true,
            canRetry: true,
            onRetry: () => retryCount++,
            onCheckStatus: () {},
          ),
        ),
      ),
    );

    expect(find.text('Unable to load PayFast'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Payment Failed'), findsNothing);
    expect(find.text('Payment Cancelled'), findsNothing);
    expect(find.textContaining('no charges'), findsNothing);

    await tester.tap(find.text('Retry'));
    expect(retryCount, 1);
  });

  testWidgets('offers status verification when checkout cannot be retried', (
    tester,
  ) async {
    var statusCheckCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PayFastPageOverlay(
            isLoading: false,
            hasError: true,
            canRetry: false,
            onRetry: () {},
            onCheckStatus: () => statusCheckCount++,
          ),
        ),
      ),
    );

    expect(find.text('Retry'), findsNothing);
    expect(find.text('Check payment status'), findsOneWidget);
    await tester.tap(find.text('Check payment status'));
    expect(statusCheckCount, 1);
  });
}
