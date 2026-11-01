import 'package:flutter/material.dart';

import '../utils/haptics.dart';

/// One choice from a short list, as chips. Tapping the selected chip again
/// clears it when [optional].
class ChipChoice extends StatelessWidget {
  const ChipChoice({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.optional = true,
  });
  final List<String> options;
  final String? value;
  final ValueChanged<String?> onChanged;
  final bool optional;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 6,
    runSpacing: 6,
    children: [
      for (final o in options)
        ChoiceChip(
          label: Text(o),
          selected: value == o,
          onSelected: (on) {
            Haptics.selection();
            onChanged(on ? o : (optional ? null : o));
          },
        ),
    ],
  );
}
