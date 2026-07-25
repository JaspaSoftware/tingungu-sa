import 'package:flutter/material.dart';
import 'home_screen.dart';

class PaymentStatusScreen extends StatelessWidget {
  final bool success;
  const PaymentStatusScreen({super.key, required this.success});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.close,
            color: success ? const Color(0xFFFB8B24) : const Color(0xFF3B0D11),
          ),
          onPressed: () => Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
            (route) => false,
          ),
        ),
        title: Text(
          success ? 'Payment Successful' : 'Payment Cancelled',
          style: TextStyle(
            color: success ? const Color(0xFFFB8B24) : const Color(0xFF3B0D11),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: success
                        ? [const Color(0xFFFB8B24), const Color(0xFFFB8B24)]
                        : [const Color(0xFF3B0D11), const Color(0xFF3B0D11)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(60),
                  boxShadow: [
                    BoxShadow(
                      color: success
                          ? const Color(0xFFFB8B24).withValues(alpha: 0.3)
                          : const Color(0xFF3B0D11).withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(
                  success ? Icons.check_rounded : Icons.close_rounded,
                  color: Colors.white,
                  size: 64,
                ),
              ),
              const SizedBox(height: 40),
              Text(
                success ? 'Payment Successful!' : 'Payment Cancelled',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: success
                      ? const Color(0xFFFB8B24)
                      : const Color(0xFF3B0D11),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                success
                    ? 'Your wallet has been topped up successfully. The funds are now available in your account.'
                    : 'Your payment was cancelled. No charges have been made to your account.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const HomeScreen()),
                    (route) => false,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: success
                        ? const Color(0xFFFB8B24)
                        : const Color(0xFF3B0D11),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                    shadowColor: success
                        ? const Color(0xFFFB8B24).withValues(alpha: 0.4)
                        : const Color(0xFF3B0D11).withValues(alpha: 0.4),
                  ),
                  child: const Text(
                    'Back to App',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
