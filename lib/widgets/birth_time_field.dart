import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/patient.dart';
import '../utils/app_theme.dart';
import '../utils/app_typography.dart';
import '../utils/app_utils.dart';
import 'app_sheet.dart';

/// Optional exact date + time of birth (newborns / PNC). A read-only
/// field (so the floating label never collides with the value) that opens
/// a picker; the current hours of life show as helper text.
class BirthTimeField extends StatefulWidget {
  const BirthTimeField({super.key, required this.bornAt, required this.onChanged});

  final DateTime? bornAt;
  final ValueChanged<DateTime?> onChanged;

  @override
  State<BirthTimeField> createState() => _BirthTimeFieldState();
}

class _BirthTimeFieldState extends State<BirthTimeField> {
  late final _controller = TextEditingController(text: _format(widget.bornAt));

  static String _format(DateTime? d) => d == null ? '' : formatDueTime(d);

  @override
  void didUpdateWidget(BirthTimeField old) {
    super.didUpdateWidget(old);
    if (old.bornAt != widget.bornAt) _controller.text = _format(widget.bornAt);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.bornAt;
    return TextField(
      controller: _controller,
      readOnly: true,
      onTap: () => _pick(context),
      style: AppTypography.body(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: 'Birth date & time',
        // Label stays above the field so it never sits on the hint/value.
        floatingLabelBehavior: FloatingLabelBehavior.always,
        hintText: 'Tap to set',
        helperText: value == null
            ? 'Newborns (optional): shows hours of life and sets 48 h / 72 h reminders.'
            : '${ageSinceBirthLabel(value, DateTime.now())} old',
        helperMaxLines: 2,
        prefixIcon: const Icon(Icons.child_friendly_outlined),
        suffixIcon: value == null
            ? const Icon(Icons.edit_calendar_outlined)
            : IconButton(
                tooltip: 'Clear birth time',
                icon: const Icon(Icons.close),
                onPressed: () => widget.onChanged(null),
              ),
      ),
    );
  }

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final initial = widget.bornAt ?? now;
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
      if (ok == true) widget.onChanged(picked);
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
    widget.onChanged(chosen.isAfter(now) ? now : chosen);
  }
}
