import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/theme_provider.dart';

class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final tp = context.watch<ThemeProvider>();
    return IconButton(
      tooltip: tp.isDark ? 'Switch to light mode' : 'Switch to dark mode',
      icon: Icon(tp.isDark ? Icons.light_mode : Icons.dark_mode_outlined),
      onPressed: tp.toggle,
    );
  }
}
