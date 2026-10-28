import 'package:flutter/material.dart';

class PayFastPageOverlay extends StatelessWidget {
  const PayFastPageOverlay({
    super.key,
    required this.isLoading,
    required this.hasError,
    required this.canRetry,
    required this.onRetry,
    required this.onCheckStatus,
  });

  final bool isLoading;
  final bool hasError;
  final bool canRetry;
  final VoidCallback onRetry;
  final VoidCallback onCheckStatus;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!hasError) return const SizedBox.shrink();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Unable to load PayFast',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              "We couldn't load the payment page. Please check your internet connection and try again.",
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (canRetry)
              ElevatedButton(onPressed: onRetry, child: const Text('Retry'))
            else
              ElevatedButton(
                onPressed: onCheckStatus,
                child: const Text('Check payment status'),
              ),
          ],
        ),
      ),
    );
  }
}
