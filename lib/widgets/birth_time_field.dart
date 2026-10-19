import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/patient.dart';
import '../utils/app_theme.dart';
import '../utils/app_typography.dart';
import '../utils/app_utils.dart';
import 'app_sheet.dart';

/// Optional exact date + time of birth (newborns / PNC). Shows the current
/// age in hours so the 48 h / 72 h windows are obvious.
class BirthTimeField extends StatelessWidget {
  const BirthTimeField({super.key, required this.bornAt, required this.onChanged});

  final DateTime? bornAt;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    final value = bornAt;
    return InputDecorator(
      decoration: InputDecoration(
        labelText: 'Date & time of birth (newborns)',
        prefixIcon: const Icon(Icons.child_friendly_outlined),
        suffixIcon: value == null
            ? null
            : IconButton(
                tooltip: 'Clear birth time',
                icon: const Icon(Icons.close),
                onPressed: () => onChanged(null),
              ),
      ),
      isEmpty: value == null,
      child: InkWell(
        onTap: () => _pick(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: value == null
              ? Text('Tap to set',
                  style: AppTypography.body(color: AppColors.textSecondary))
              : Text(
                  '${formatDueTime(value)}  ·  '
                  '${ageSinceBirthLabel(value, DateTime.now())} old',
                  style: AppTypography.body(color: AppColors.textPrimary),
                ),
        ),
      ),
    );
  }

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final initial = bornAt ?? now;
    final first = now.subtract(const Duration(days: 365));
    final platform = Theme.of(context).platform;
    if (platform == TargetPlatform.iOS || platform == TargetPlatform.macOS) {
      var picked = initial;
      final ok = await showAppSheet<bool>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel'),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Done'),
                  ),
                ],
              ),
              SizedBox(
                height: 216,
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.dateAndTime,
                  initialDateTime: initial,
                  minimumDate: first,
                  maximumDate: now,
                  onDateTimeChanged: (d) => picked = d,
                ),
              ),
            ],
          ),
        ),
      );
      if (ok == true) onChanged(picked);
      return;
    }
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: now,
      helpText: 'Date of birth',
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      helpText: 'Time of birth',
    );
    if (time == null) return;
    final chosen =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    onChanged(chosen.isAfter(now) ? now : chosen);
  }
}
