import 'package:flutter/foundation.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import 'supabase_service.dart';

/// Razorpay checkout. Unused while FolioMed is free (see
/// SubscriptionProvider.freeForEveryone) — kept for a future paid tier.
///
/// TODO(payments): activation must be verified server-side (Razorpay
/// webhook → Supabase Edge Function) before granting anything. The client
/// success callback alone is spoofable.

class PaymentService {
  /// Public key ID (`rzp_test_…` / `rzp_live_…`), injected at build time
  /// via `RAZORPAY_KEY_ID` in env.json. Never ship the key secret.
  static const String _keyId = String.fromEnvironment('RAZORPAY_KEY_ID');
  static bool get isConfigured => _keyId.isNotEmpty;

  static const int amountInPaise = 299900; // ₹2,999.00
  static const String currency = 'INR';
  static const String planName = 'FolioMed Pro — Monthly';

  late final Razorpay _razorpay;
  VoidCallback? onSuccess;
  VoidCallback? onFailure;

  PaymentService() {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handleSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handleError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleWallet);
  }

  void openCheckout({
    required String userName,
    required String userEmail,
    required String userPhone,
    VoidCallback? onPaymentSuccess,
    VoidCallback? onPaymentFailure,
  }) {
    onSuccess = onPaymentSuccess;
    onFailure = onPaymentFailure;

    final options = {
      'key': _keyId,
      'amount': amountInPaise,
      'currency': currency,
      'name': 'FolioMed',
      'description': planName,
      'prefill': {
        'contact': userPhone,
        'email': userEmail,
        'name': userName,
      },
      'theme': {
        'color': '#0A5C8A',
      },
      'notes': {
        'plan': 'foliomed_pro_monthly',
        'uid': supabase.auth.currentUser?.id ?? '',
      },
    };

    _razorpay.open(options);
  }

  void _handleSuccess(PaymentSuccessResponse response) {
    debugPrint('Payment success: ${response.paymentId}');
    onSuccess?.call();
  }

  void _handleError(PaymentFailureResponse response) {
    debugPrint('Payment failed: ${response.code} - ${response.message}');
    onFailure?.call();
  }

  void _handleWallet(ExternalWalletResponse response) {
    debugPrint('External wallet: ${response.walletName}');
  }

  void dispose() {
    _razorpay.clear();
  }
}
