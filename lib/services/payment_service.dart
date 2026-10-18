import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

class PaymentService {
  // ⚠️ PLACEHOLDER — replace with the real Razorpay key from
  // https://dashboard.razorpay.com before shipping. Until this is a real
  // key, openCheckout() will fail at the Razorpay end with an unauthorized
  // key error. Test keys start with `rzp_test_`, live with `rzp_live_`.
  static const String _keyId = 'rzp_test_XXXXXXXXXX';
  static bool get isConfigured =>
      _keyId != 'rzp_test_XXXXXXXXXX' && _keyId.isNotEmpty;

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
        'uid': FirebaseAuth.instance.currentUser?.uid ?? '',
      },
    };

    _razorpay.open(options);
  }

  void _handleSuccess(PaymentSuccessResponse response) async {
    debugPrint('Payment success: ${response.paymentId}');

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final expires = DateTime.now().add(const Duration(days: 30));
      await FirebaseFirestore.instance
          .collection('subscriptions')
          .doc(uid)
          .set({
        'isPro': true,
        'plan': 'monthly',
        'paymentId': response.paymentId,
        'orderId': response.orderId,
        'signature': response.signature,
        'activatedAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(expires),
        'amountPaise': amountInPaise,
        'currency': currency,
      });
    }

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
