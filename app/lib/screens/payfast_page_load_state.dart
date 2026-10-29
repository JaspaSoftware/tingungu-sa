enum PayFastPageLoadStatus { loading, loaded, error }

class PayFastPageLoadState {
  PayFastPageLoadStatus status = PayFastPageLoadStatus.loading;
  String? activeUrl;
  bool checkoutSubmitted = false;
  bool _isDisposed = false;
  bool _awaitingRetryNavigation = false;

  bool get isLoading => status == PayFastPageLoadStatus.loading;
  bool get hasError => status == PayFastPageLoadStatus.error;
  bool get canRetry => hasError && !checkoutSubmitted && !_isDisposed;

  void onPageStarted(String url) {
    if (_isDisposed) return;
    activeUrl = url;
    status = PayFastPageLoadStatus.loading;
    _awaitingRetryNavigation = false;
  }

  void onNavigationRequest(String url) {
    if (_isDisposed) return;
    final uri = Uri.tryParse(url);
    if (uri?.host.endsWith('payfast.co.za') == true &&
        uri?.path == '/eng/process') {
      checkoutSubmitted = true;
    }
  }

  bool onPageFinished(String url) {
    if (_isDisposed ||
        activeUrl != url ||
        status != PayFastPageLoadStatus.loading) {
      return false;
    }
    status = PayFastPageLoadStatus.loaded;
    return true;
  }

  bool onHttpError(String url) {
    if (_isDisposed || _awaitingRetryNavigation || activeUrl != url) {
      return false;
    }
    status = PayFastPageLoadStatus.error;
    return true;
  }

  bool onWebResourceError({
    required bool? isForMainFrame,
    required String? url,
  }) {
    if (_isDisposed ||
        _awaitingRetryNavigation ||
        isForMainFrame == false ||
        (url != null && activeUrl != null && url != activeUrl)) {
      return false;
    }
    status = PayFastPageLoadStatus.error;
    return true;
  }

  bool beginRetry() {
    if (!canRetry || isLoading) return false;
    activeUrl = null;
    status = PayFastPageLoadStatus.loading;
    _awaitingRetryNavigation = true;
    return true;
  }

  void dispose() {
    _isDisposed = true;
  }
}
