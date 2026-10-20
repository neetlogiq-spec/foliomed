import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/app_theme.dart';
import '../utils/app_typography.dart';

/// Remembers which tips have been dismissed. Loaded once at start-up so a
/// dismissed tip never flashes on screen.
class TipStore {
  TipStore._();
  static const _key = 'tips_dismissed_v1';
  static Set<String> _dismissed = {};

  static Future<void> load() async {
    try {
      _dismissed = ((await SharedPreferences.getInstance()).getStringList(_key) ?? const []).toSet();
    } catch (_) {}
  }

  static bool isDismissed(String id) => _dismissed.contains(id);

  static Future<void> dismiss(String id) async {
    _dismissed = {..._dismissed, id};
    try {
      await (await SharedPreferences.getInstance()).setStringList(_key, _dismissed.toList());
    } catch (_) {}
  }

  /// Profile → "Show tips again".
  static Future<void> reset() async {
    _dismissed = {};
    try {
      await (await SharedPreferences.getInstance()).remove(_key);
    } catch (_) {}
  }
}

/// A small, dismissible hint shown in place, once (TipKit-style) — instead
/// of a slide-show tutorial.
class TipCard extends StatefulWidget {
  const TipCard({
    super.key,
    required this.id,
    required this.icon,
    required this.title,
    required this.message,
  });

  final String id;
  final IconData icon;
  final String title;
  final String message;

  @override
  State<TipCard> createState() => _TipCardState();
}

class _TipCardState extends State<TipCard> {
  late bool _visible = !TipStore.isDismissed(widget.id);

  void _dismiss() {
    TipStore.dismiss(widget.id);
    setState(() => _visible = false);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: AppMotion.reduced(context) ? Duration.zero : const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: !_visible
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(AppRadii.card),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(widget.icon, color: AppColors.primary, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.title,
                              style: AppTypography.subheadline(
                                  color: AppColors.textPrimary, weight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(widget.message,
                              style: AppTypography.footnote(color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Dismiss tip',
                      icon: Icon(Icons.close, size: 18, color: AppColors.textSecondary),
                      onPressed: _dismiss,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
