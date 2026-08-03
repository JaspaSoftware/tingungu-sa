import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'payment_status_screen.dart';

class PayFastWebView extends StatefulWidget {
  final Map<String, String> formData;
  // When true (the default, used by the standalone wallet top-up flow), a
  // successful payment credits wallet_balance and shows PaymentStatusScreen.
  // When false (used via PaymentMethodSelector for Giving/Airtime/etc.),
  // this instead pops back to the caller with true/false so it can complete
  // its own success/failure handling.
  final bool isWalletTopUp;
  const PayFastWebView({
    super.key,
    required this.formData,
    this.isWalletTopUp = true,
  });
  static const id = 'payFastWebView';

  @override
  State<PayFastWebView> createState() => _PayFastWebViewState();
}

class _PayFastWebViewState extends State<PayFastWebView> {

  bool isLoading = true;
  String pageStatusMessage = 'please wait...';
  late final WebViewController _controller;

  // final  _controller =WebViewController()
  //   ..setJavaScriptMode(JavaScriptMode.unrestricted)
  //   ..setNavigationDelegate(
  //     NavigationDelegate(
  //       onProgress: (int progress) {
  //         // Update loading bar.
  //       },
  //       onPageStarted: (String url) {},
  //       onPageFinished: (String url) {},
  //       onHttpError: (HttpResponseError error) {},
  //       onWebResourceError: (WebResourceError error) {},
  //       onNavigationRequest: (NavigationRequest request) {
  //         if (request.url.startsWith('https://www.youtube.com/')) {
  //           return NavigationDecision.prevent;
  //         }
  //         return NavigationDecision.navigate;
  //       },
  //     ),
  //   )
  //   ..loadRequest(Uri.parse('https://flutter.dev'));

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (String url) {},
        onPageFinished: (String url) {
          setState(() => isLoading = false);
        },
        onWebResourceError: (WebResourceError error) {
          setState(() => pageStatusMessage = 'Error loading page');
        },
        onNavigationRequest: (NavigationRequest request) {

          if (request.url.contains('success')) {
            _handleSuccessPayment();
            return NavigationDecision.prevent;
          } else if (request.url.contains('cancel')) {
            _handleCancelledPayment();
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ));

    _loadPayFastForm();
  }


  Future<void> _handleSuccessPayment() async {
    setState(() => isLoading = true);
    try {
      if (widget.isWalletTopUp) {
        final amountStr = widget.formData['amount'];
        final amount = double.tryParse(amountStr ?? '0') ?? 0.0;

        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
          await FirebaseFirestore.instance.runTransaction((transaction) async {
            final snapshot = await transaction.get(docRef);
            if (!snapshot.exists) {
              throw Exception("User does not exist!");
            }
            final double currentBalance = (snapshot.data()?['wallet_balance'] ?? 0.0).toDouble();
            transaction.update(docRef, {'wallet_balance': currentBalance + amount});
          });
        }
      }

      if (!mounted) return;
      if (widget.isWalletTopUp) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const PaymentStatusScreen(success: true)),
        );
      } else {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (!mounted) return;
      if (widget.isWalletTopUp) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const PaymentStatusScreen(success: false)),
        );
      } else {
        Navigator.pop(context, false);
      }
    }
  }

  void _handleCancelledPayment() {
    if (widget.isWalletTopUp) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const PaymentStatusScreen(success: false)),
      );
    } else {
      Navigator.pop(context, false);
    }
  }

  void _loadPayFastForm() {
    final buffer = StringBuffer();
    buffer.writeln("<html><body onload='document.forms[0].submit()'>");
    buffer.writeln("<form id='payfastForm' action='https://sandbox.payfast.co.za/eng/process' method='post'>");

    widget.formData.forEach((key, value) {
      buffer.writeln("<input type='hidden' name='$key' value='$value' />");
    });

    buffer.writeln("</form></body></html>");

    final htmlContent = buffer.toString();
    final encodedHtml = base64Encode(const Utf8Encoder().convert(htmlContent));

    _controller.loadRequest(
      Uri.dataFromString(
        htmlContent,
        mimeType: 'text/html',
        encoding: Encoding.getByName('utf-8'),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Process Payment', style: TextStyle(fontSize: 16, color: Colors.white)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (isLoading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}