import 'package:flutter_test/flutter_test.dart';
import 'package:tingungu_app/screens/payfast_page_load_state.dart';

void main() {
  group('PayFastPageLoadState', () {
    test('tracks a page from loading to loaded', () {
      final state = PayFastPageLoadState();

      expect(state.isLoading, isTrue);
      state.onPageStarted('https://www.payfast.co.za/checkout');
      expect(state.isLoading, isTrue);

      expect(
        state.onPageFinished('https://www.payfast.co.za/checkout'),
        isTrue,
      );
      expect(state.status, PayFastPageLoadStatus.loaded);
    });

    test('shows an error for a main-frame network failure', () {
      final state = PayFastPageLoadState()
        ..onPageStarted('https://www.payfast.co.za/checkout');

      expect(
        state.onWebResourceError(
          isForMainFrame: true,
          url: 'https://www.payfast.co.za/checkout',
        ),
        isTrue,
      );
      expect(state.hasError, isTrue);
      expect(state.canRetry, isTrue);
      expect(
        state.onPageFinished('https://www.payfast.co.za/checkout'),
        isFalse,
      );
      expect(state.hasError, isTrue);
    });

    test('ignores a subresource network failure', () {
      final state = PayFastPageLoadState()
        ..onPageStarted('https://www.payfast.co.za/checkout');

      expect(
        state.onWebResourceError(
          isForMainFrame: false,
          url: 'https://www.payfast.co.za/logo.png',
        ),
        isFalse,
      );
      expect(state.isLoading, isTrue);
    });

    test('shows an error for a main-frame HTTP response error', () {
      final state = PayFastPageLoadState()
        ..onPageStarted('https://www.payfast.co.za/checkout');

      expect(state.onHttpError('https://www.payfast.co.za/checkout'), isTrue);
      expect(state.hasError, isTrue);
    });

    test('ignores stale page callbacks', () {
      final state = PayFastPageLoadState()
        ..onPageStarted('https://www.payfast.co.za/checkout')
        ..onPageStarted('https://www.payfast.co.za/redirect');

      expect(
        state.onPageFinished('https://www.payfast.co.za/checkout'),
        isFalse,
      );
      expect(state.onHttpError('https://www.payfast.co.za/checkout'), isFalse);
      expect(state.isLoading, isTrue);
    });

    test('retry clears the error and returns to loading', () {
      final state = PayFastPageLoadState()
        ..onPageStarted('https://www.payfast.co.za/checkout')
        ..onWebResourceError(
          isForMainFrame: true,
          url: 'https://www.payfast.co.za/checkout',
        );

      expect(state.beginRetry(), isTrue);
      expect(state.isLoading, isTrue);
      expect(state.hasError, isFalse);
      expect(state.activeUrl, isNull);
      expect(state.beginRetry(), isFalse);
    });

    test('ignores a delayed error callback while retry navigation starts', () {
      const failedUrl = 'https://www.payfast.co.za/checkout';
      final state = PayFastPageLoadState()
        ..onPageStarted(failedUrl)
        ..onWebResourceError(isForMainFrame: true, url: failedUrl);

      expect(state.beginRetry(), isTrue);
      expect(
        state.onWebResourceError(isForMainFrame: true, url: failedUrl),
        isFalse,
      );
      expect(state.onHttpError(failedUrl), isFalse);
      expect(state.isLoading, isTrue);

      state.onPageStarted(failedUrl);
      expect(
        state.onWebResourceError(isForMainFrame: true, url: failedUrl),
        isTrue,
      );
      expect(state.hasError, isTrue);
    });

    test('does not allow retry after checkout submission', () {
      final state = PayFastPageLoadState()
        ..onPageStarted('https://www.payfast.co.za/checkout')
        ..onWebResourceError(
          isForMainFrame: true,
          url: 'https://www.payfast.co.za/checkout',
        )
        ..onNavigationRequest('https://www.payfast.co.za/eng/process');

      expect(state.checkoutSubmitted, isTrue);
      expect(state.canRetry, isFalse);
      expect(state.beginRetry(), isFalse);
    });

    test('redirect load failures cannot retry a submitted checkout', () {
      final state = PayFastPageLoadState()
        ..onNavigationRequest('https://www.payfast.co.za/eng/process')
        ..onPageStarted('https://www.payfast.co.za/checkout')
        ..onWebResourceError(
          isForMainFrame: true,
          url: 'https://www.payfast.co.za/checkout',
        );

      expect(state.hasError, isTrue);
      expect(state.canRetry, isFalse);
      expect(state.beginRetry(), isFalse);
    });

    test('ignores callbacks after disposal', () {
      final state = PayFastPageLoadState()
        ..onPageStarted('https://www.payfast.co.za/checkout')
        ..dispose();

      expect(
        state.onWebResourceError(
          isForMainFrame: true,
          url: 'https://www.payfast.co.za/checkout',
        ),
        isFalse,
      );
      expect(
        state.onPageFinished('https://www.payfast.co.za/checkout'),
        isFalse,
      );
      expect(state.onHttpError('https://www.payfast.co.za/checkout'), isFalse);
      expect(state.beginRetry(), isFalse);
    });
  });
}
