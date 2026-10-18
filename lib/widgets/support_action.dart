import 'package:flutter/material.dart';

import 'support_sheet.dart';

/// AppBar action button that opens the Support FolioMed sheet.
///
/// Use it in any `AppBar(actions: [...])` slot on the main screens —
/// keeps the entry-point one tap away without an interruptive daily
/// popup. Icon is the chai emoji rendered as a coloured icon glyph
/// so it matches the rest of the AppBar's monochrome action set.
class SupportAppBarAction extends StatelessWidget {
  const SupportAppBarAction({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Support the developer',
      icon: const Icon(
        Icons.local_cafe_outlined,
        color: Color(0xFFE57F00),
      ),
      onPressed: () => showSupportSheet(context),
    );
  }
}
