import 'package:flutter/material.dart';
import '../../utils/app_typography.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../services/payment_service.dart';
import '../../utils/app_theme.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  late final PaymentService _payment;

  @override
  void initState() {
    super.initState();
    _payment = PaymentService();
  }

  @override
  void dispose() {
    _payment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sub = context.watch<SubscriptionProvider>();

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text('FolioMed Pro', style: appText(fontWeight: FontWeight.w800)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Icon
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0A5C8A), Color(0xFF0E7C5F)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.monitor_heart, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 24),
            Text(
              'Upgrade to FolioMed Pro',
              style: appText(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Real-time patient monitoring, right from your phone.',
              textAlign: TextAlign.center,
              style: appText(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 32),

            // Features
            _featureRow(Icons.monitor_heart, 'Live Vitals Monitoring',
                'HR, SpO₂, RR, BP with real-time alerts'),
            _featureRow(Icons.notifications_active, 'Smart Alerts',
                'Threshold-based critical & warning alerts pushed to your team'),
            _featureRow(Icons.videocam, 'Bedside Camera',
                'Watch your patients remotely via live camera feed'),
            _featureRow(Icons.tune, 'Custom Thresholds',
                'Set patient-specific alert thresholds per vital sign'),
            _featureRow(Icons.groups, 'Team Monitoring',
                'Your entire ward team sees vitals & alerts in real time'),
            _featureRow(Icons.history, 'Vital Trends',
                'Historical charts & trends for clinical decision support'),

            const SizedBox(height: 32),

            // Pricing card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0A5C8A), Color(0xFF0E7C5F)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Text('FolioMed Pro',
                    style: appText(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('₹', style: appText(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
                      Text('2,999', style: appText(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w800)),
                    ],
                  ),
                  Text('per month',
                    style: appText(color: Colors.white60, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text('per ward · unlimited team members',
                    style: appText(color: Colors.white54, fontSize: 11)),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: sub.isLoading ? null : () => _handleSubscribe(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF0A5C8A),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        textStyle: appText(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      child: sub.isLoading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator.adaptive(strokeWidth: 2))
                          : const Text('Subscribe Now'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton(
                      onPressed: sub.isLoading ? null : () => _handleTrial(context, sub),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white30),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        textStyle: appText(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      child: const Text('Start 7-day free trial'),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            Text(
              'Cancel anytime. No hidden fees.',
              style: appText(color: AppColors.textSecondary, fontSize: 11),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _featureRow(IconData icon, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: appText(
                  color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
                Text(desc, style: appText(
                  color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handleSubscribe(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final sub = context.read<SubscriptionProvider>();
    final user = auth.currentUser;

    _payment.openCheckout(
      userName: user?.name ?? 'Doctor',
      userEmail: user?.email ?? '',
      userPhone: '',
      onPaymentSuccess: () {
        sub.checkSubscription();
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('FolioMed Pro activated! Thank you.',
                style: appText()),
              backgroundColor: AppColors.accent,
            ),
          );
        }
      },
      onPaymentFailure: () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Payment failed. Please try again.',
                style: appText()),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      },
    );
  }

  void _handleTrial(BuildContext context, SubscriptionProvider sub) async {
    await sub.activateTrial();
    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('FolioMed Pro activated! 7-day free trial started.',
            style: appText()),
          backgroundColor: AppColors.accent,
        ),
      );
    }
  }
}
