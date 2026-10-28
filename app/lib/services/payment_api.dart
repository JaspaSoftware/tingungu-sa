import '../config/app_config.dart';
import 'api_client.dart';

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

enum PaymentState { pending, complete, failed, cancelled }

class PaymentPollResult {
  final PaymentState status;
  final bool timedOut;
  final bool hadStatusCheckErrors;

  const PaymentPollResult({
    required this.status,
    required this.timedOut,
    this.hadStatusCheckErrors = false,
  });
}

PaymentState paymentStateFromResponse(Object? responseBody) {
  if (responseBody is! Map<String, dynamic>) {
    throw const PaymentException(
      'The payment service returned an invalid response.',
    );
  }

  return switch (responseBody['status']) {
    'pending' => PaymentState.pending,
    'complete' => PaymentState.complete,
    'failed' => PaymentState.failed,
    'cancelled' => PaymentState.cancelled,
    _ => throw const PaymentException(
      'The payment service returned an unknown status.',
    ),
  };
}

Future<PaymentPollResult> pollPaymentStatus({
  required Future<PaymentState> Function() fetchStatus,
  Duration timeout = const Duration(seconds: 30),
  Duration interval = const Duration(seconds: 2),
  DateTime Function()? now,
  Future<void> Function(Duration)? delay,
}) async {
  final clock = now ?? DateTime.now;
  final wait = delay ?? (duration) => Future<void>.delayed(duration);
  final startedAt = clock();
  var status = PaymentState.pending;
  var hadStatusCheckErrors = false;
  var isFirstAttempt = true;

  while (true) {
    if (!isFirstAttempt && clock().difference(startedAt) >= timeout) {
      return PaymentPollResult(
        status: PaymentState.pending,
        timedOut: true,
        hadStatusCheckErrors: hadStatusCheckErrors,
      );
    }
    isFirstAttempt = false;
    try {
      final remaining = timeout - clock().difference(startedAt);
      status = await fetchStatus().timeout(remaining);
      if (status != PaymentState.pending) {
        return PaymentPollResult(status: status, timedOut: false);
      }
    } catch (_) {
      hadStatusCheckErrors = true;
    }

    final remaining = timeout - clock().difference(startedAt);
    if (remaining <= Duration.zero) {
      return PaymentPollResult(
        status: PaymentState.pending,
        timedOut: true,
        hadStatusCheckErrors: hadStatusCheckErrors,
      );
    }
    await wait(interval < remaining ? interval : remaining);
  }
}

/// Talks to the Tingungu API for every operation that moves money. The server
/// owns balances; the app never writes them.
class PaymentApi {
  PaymentApi._();

  static final ApiClient _api = ApiClient.shared;

  static Map<String, dynamic> _requireObject(Object? value) {
    if (value is Map<String, dynamic>) return value;
    throw const PaymentException(
      'The payment service returned an invalid response.',
    );
  }

  /// Buys airtime from the wallet. Returns true when delivered, false when the
  /// server could not confirm yet (it will reconcile and refund if needed).
  static Future<bool> buyAirtime({
    required int amount,
    required int productCode,
    required String mobileNumber,
  }) async {
    try {
      final response = await _api.post(
        'airtime/purchase',
        baseUrl: AppConfig.apiBaseUrl,
        authenticated: true,
        body: {
          'amount': amount,
          'productCode': productCode,
          'mobileNumber': mobileNumber,
        },
      );
      return response.statusCode != 202;
    } on ApiException catch (error) {
      throw PaymentException(error.message);
    }
  }

  static Future<void> payWithWallet({
    required double amount,
    required String purpose,
    String? givingOptionId,
    String note = '',
  }) async {
    try {
      await _api.post(
        'payments/wallet-pay',
        baseUrl: AppConfig.apiBaseUrl,
        authenticated: true,
        body: {
          'amount': amount,
          'purpose': purpose,
          'givingOptionId': givingOptionId,
          'note': note,
        },
      );
    } on ApiException catch (error) {
      throw PaymentException(error.message);
    }
  }

  static Future<PayFastSession> startPayFast({
    required double amount,
    required String purpose,
    String? givingOptionId,
    String note = '',
  }) async {
    try {
      final response = await _api.post(
        'payments/payfast/create',
        baseUrl: AppConfig.apiBaseUrl,
        authenticated: true,
        body: {
          'amount': amount,
          'purpose': purpose,
          'givingOptionId': givingOptionId,
          'note': note,
        },
      );
      final body = _requireObject(response.body);
      final formData = body['formData'];
      if (formData is! Map<String, dynamic>) {
        throw const PaymentException(
          'The payment service returned invalid form data.',
        );
      }
      return PayFastSession(
        body['paymentId'] as String,
        body['processUrl'] as String,
        formData.map((key, value) => MapEntry(key, value.toString())),
      );
    } on ApiException catch (error) {
      throw PaymentException(error.message);
    } on TypeError {
      throw const PaymentException(
        'The payment service returned an invalid response.',
      );
    }
  }

  static Future<PaymentState> getPaymentStatus(String paymentId) async {
    try {
      final response = await _api.get(
        'payments/${Uri.encodeComponent(paymentId)}',
        baseUrl: AppConfig.apiBaseUrl,
        authenticated: true,
      );
      return paymentStateFromResponse(response.body);
    } on ApiException catch (error) {
      throw PaymentException(error.message);
    }
  }

  /// PayFast confirms asynchronously; timeout or lookup errors do not imply
  /// that the payment failed.
  static Future<PaymentPollResult> waitForCompletion(
    String paymentId, {
    Future<PaymentState> Function(String paymentId)? statusLookup,
  }) {
    return pollPaymentStatus(
      fetchStatus: () => (statusLookup ?? getPaymentStatus)(paymentId),
    );
  }
}
