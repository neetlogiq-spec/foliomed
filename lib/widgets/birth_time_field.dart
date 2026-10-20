import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/patient.dart';
import '../utils/app_theme.dart';
import '../utils/app_typography.dart';
import '../utils/formatting.dart';
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
    final picked = await pickBirthDateTime(context, widget.bornAt);
    if (picked != null) widget.onChanged(picked);
  }
}

/// Date + time of birth picker: a wheel in a sheet on iOS/macOS, the
/// platform date then time pickers elsewhere. Never in the future.
Future<DateTime?> pickBirthDateTime(BuildContext context, DateTime? current,
    {String title = 'Date & time of birth'}) async {
  final now = DateTime.now();
  final initial = current ?? now;
  final first = now.subtract(const Duration(days: 365));
  final platform = Theme.of(context).platform;
  if (platform == TargetPlatform.iOS || platform == TargetPlatform.macOS) {
    var picked = initial.isAfter(now) ? now : initial;
    final ok = await showAppSheet<bool>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                CupertinoButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                Expanded(
                  child: Text(title,
                      textAlign: TextAlign.center,
                      style: AppTypography.headline(color: AppColors.textPrimary)),
                ),
                CupertinoButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Done',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            SizedBox(
              height: 216,
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.dateAndTime,
                initialDateTime: picked,
                minimumDate: first,
                maximumDate: now,
                onDateTimeChanged: (d) => picked = d,
              ),
            ),
          ],
        ),
      ),
    );
    return ok == true ? picked : null;
  }
  final date = await showDatePicker(
    context: context,
    initialDate: initial.isAfter(now) ? now : initial,
    firstDate: first,
    lastDate: now,
    helpText: title,
  );
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initial),
    helpText: 'Time of birth',
  );
  if (time == null) return null;
  final chosen = DateTime(date.year, date.month, date.day, time.hour, time.minute);
  return chosen.isAfter(now) ? now : chosen;
}

/// Gestational age picker (completed weeks + days). Returns (weeks, days).
Future<(int, int)?> pickGestation(BuildContext context, int? weeks, int? days) async {
  var w = weeks ?? 39;
  var d = days ?? 0;
  final ok = await showAppSheet<bool>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              CupertinoButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              Expanded(
                child: Text('Gestational age',
                    textAlign: TextAlign.center,
                    style: AppTypography.headline(color: AppColors.textPrimary)),
              ),
              CupertinoButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Done',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          SizedBox(
            height: 200,
            child: Row(
              children: [
                Expanded(
                  child: CupertinoPicker(
                    itemExtent: 36,
                    scrollController:
                        FixedExtentScrollController(initialItem: w - 22),
                    onSelectedItemChanged: (i) => w = 22 + i,
                    children: [
                      for (var i = 22; i <= 44; i++)
                        Center(child: Text('$i weeks')),
                    ],
                  ),
                ),
                Expanded(
                  child: CupertinoPicker(
                    itemExtent: 36,
                    scrollController: FixedExtentScrollController(initialItem: d),
                    onSelectedItemChanged: (i) => d = i,
                    children: [
                      for (var i = 0; i <= 6; i++)
                        Center(child: Text('$i day${i == 1 ? '' : 's'}')),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  return ok == true ? (w, d) : null;
}
