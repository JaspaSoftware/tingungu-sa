import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../services/payment_api.dart';
import 'payfast_page_load_state.dart';
import 'payfast_page_overlay.dart';
import 'payment_status_screen.dart';

class PayFastWebView extends StatefulWidget {
  final PayFastSession session;
  final bool isWalletTopUp;

  const PayFastWebView({
    super.key,
    required this.session,
    this.isWalletTopUp = true,
  });

  static const id = 'payFastWebView';

  @override
  State<PayFastWebView> createState() => _PayFastWebViewState();
}

class _PayFastWebViewState extends State<PayFastWebView> {
  final _loadState = PayFastPageLoadState();
  bool _isCheckingStatus = false;
  late final WebViewController _controller;

  @override
  void dispose() {
    _loadState.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            if (!mounted) return;
            setState(() => _loadState.onPageStarted(url));
          },
          onPageFinished: (url) {
            if (!mounted) return;
            setState(() => _loadState.onPageFinished(url));
          },
          onWebResourceError: (error) {
            if (!mounted) return;
            setState(
              () => _loadState.onWebResourceError(
                isForMainFrame: error.isForMainFrame,
                url: error.url,
              ),
            );
          },
          onHttpError: (error) {
            if (!mounted) return;
            final url = error.request?.uri.toString();
            if (url == null) return;
            setState(() => _loadState.onHttpError(url));
          },
          onNavigationRequest: (request) {
            _loadState.onNavigationRequest(request.url);
            final uri = Uri.tryParse(request.url);
            if (uri?.host == 'www.tingungu.co.za' &&
                (uri?.path == '/success' || uri?.path == '/cancel')) {
              _checkPaymentStatus();
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      );
    _loadPayFastForm();
  }

  Future<void> _checkPaymentStatus() async {
    if (!mounted || _isCheckingStatus) return;
    setState(() {
      _isCheckingStatus = true;
    });

    final result = await PaymentApi.waitForCompletion(widget.session.paymentId);
    if (!mounted) return;

    if (widget.isWalletTopUp) {
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentStatusScreen(
            paymentId: widget.session.paymentId,
            purpose: 'topup',
            initialResult: result,
          ),
        ),
      );
    } else {
      Navigator.pop(context, result);
    }
  }

  void _retryCheckoutLoad() {
    if (!_loadState.beginRetry()) return;
    setState(() {});
    _loadPayFastForm();
  }

  void _loadPayFastForm() {
    final buffer = StringBuffer()
      ..writeln("<html><body onload='document.forms[0].submit()'>")
      ..writeln(
        "<form id='payfastForm' action='${widget.session.processUrl}' method='post'>",
      );

    widget.session.formData.forEach((key, value) {
      final safe = value
          .replaceAll('&', '&amp;')
          .replaceAll("'", '&#39;')
          .replaceAll('<', '&lt;');
      buffer.writeln("<input type='hidden' name='$key' value='$safe' />");
    });

    buffer.writeln('</form></body></html>');
    _controller.loadRequest(
      Uri.dataFromString(
        buffer.toString(),
        mimeType: 'text/html',
        encoding: Encoding.getByName('utf-8'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Process Payment',
          style: TextStyle(fontSize: 16, color: Colors.white),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          PayFastPageOverlay(
            isLoading: _loadState.isLoading || _isCheckingStatus,
            hasError: _loadState.hasError,
            canRetry: _loadState.canRetry,
            onRetry: _retryCheckoutLoad,
            onCheckStatus: _checkPaymentStatus,
          ),
        ],
      ),
    );
  }
}
