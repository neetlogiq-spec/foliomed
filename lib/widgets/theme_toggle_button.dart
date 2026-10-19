import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/theme_provider.dart';
import 'large_title_app_bar.dart';

class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final tp = context.watch<ThemeProvider>();
    // Same fill-circle bar-button treatment as the other header actions.
    return ChromeIconButton(
      tooltip: tp.isDark ? 'Switch to light mode' : 'Switch to dark mode',
      icon: tp.isDark ? Icons.light_mode : Icons.dark_mode_outlined,
      onPressed: tp.toggle,
    );
  }
}
