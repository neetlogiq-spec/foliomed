import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'app_typography.dart';

/// One appearance's semantic colours, after Apple's system colours:
/// grouped background → grouped secondary background (cards), label and
/// secondary label, separator, fills, translucent chrome.
@immutable
class _Palette {
  const _Palette({
    required this.tint,
    required this.onTint,
    required this.groupedBackground,
    required this.groupedCard,
    required this.raisedCard,
    required this.label,
    required this.secondaryLabel,
    required this.tertiaryLabel,
    required this.separator,
    required this.fill,
    required this.quaternaryFill,
    required this.chrome,
  });

  final Color tint;
  final Color onTint;
  final Color groupedBackground;
  final Color groupedCard;
  final Color raisedCard;
  final Color label;
  final Color secondaryLabel;
  final Color tertiaryLabel;
  final Color separator;
  final Color fill;
  final Color quaternaryFill;
  final Color chrome;

  static const light = _Palette(
    tint: Color(0xFF0F6D99),
    onTint: Colors.white,
    groupedBackground: Color(0xFFF2F2F7),
    groupedCard: Colors.white,
    raisedCard: Colors.white,
    label: Color(0xFF1C1C1E),
    secondaryLabel: Color(0xFF636366),
    tertiaryLabel: Color(0xFFC7C7CC),
    separator: Color(0xFFD1D1D6),
    fill: Color(0x1F767680),
    quaternaryFill: Color(0x14747480),
    chrome: Color(0xD9F9F9F9),
  );

  static const dark = _Palette(
    tint: Color(0xFF5AADDB),
    // White on the lighter dark-mode tint is only 2.5:1; black is 8.4:1.
    onTint: Colors.black,
    groupedBackground: Color(0xFF000000),
    groupedCard: Color(0xFF1C1C1E),
    raisedCard: Color(0xFF2C2C2E),
    label: Colors.white,
    secondaryLabel: Color(0xFF8E8E93),
    tertiaryLabel: Color(0xFF48484A),
    separator: Color(0xFF38383A),
    fill: Color(0x3D767680),
    quaternaryFill: Color(0x29747480),
    chrome: Color(0xB81C1C1E),
  );
}

/// Colour tokens for the current appearance. [isDark] is kept in step by
/// `AppearanceProvider`; status colours are the iOS system colours and
/// read well in both appearances.
abstract final class AppColors {
  static bool isDark = false;
  static _Palette get _p => isDark ? _Palette.dark : _Palette.light;

  // System colours (fixed).
  static const Color primary = Color(0xFF0F6D99); // FolioMed blue (light tint)
  static const Color darkPrimary = Color(0xFF5AADDB);
  static const Color accent = Color(0xFF00C7BE); // mint
  static const Color secondary = accent;
  static const Color danger = Color(0xFFFF3B30); // red
  static const Color critical = danger;
  static const Color warning = Color(0xFFFF9500); // orange
  static const Color stable = Color(0xFF34C759); // green
  static const Color doctorColor = Color(0xFF007AFF); // blue
  static const Color nurseColor = Color(0xFF30B0C7); // teal
  static const Color adminColor = Color(0xFFAF52DE); // purple

  // Fixed light/dark values, for the rare place that needs one explicitly.
  static const Color lightSurface = Color(0xFFF2F2F7);
  static const Color lightCard = Colors.white;
  static const Color lightTextPrimary = Color(0xFF1C1C1E);
  static const Color lightTextSecondary = Color(0xFF636366);
  static const Color lightDivider = Color(0xFFD1D1D6);
  static const Color darkScaffold = Color(0xFF000000);
  static const Color darkAppBar = darkScaffold;
  static const Color darkCard = Color(0xFF1C1C1E);
  static const Color darkCardElevated = Color(0xFF2C2C2E);
  static const Color darkTextPrimary = Colors.white;
  static const Color darkTextSecondary = Color(0xFF8E8E93);
  static const Color darkDivider = Color(0xFF38383A);

  // Semantic (follow the appearance).
  static Color get surface => _p.groupedBackground;
  static Color get card => _p.groupedCard;
  static Color get textPrimary => _p.label;
  static Color get textSecondary => _p.secondaryLabel;

  /// Decorative only (icons, grabbers) — too faint for text.
  static Color get tertiaryLabel => _p.tertiaryLabel;
  static Color get divider => _p.separator;
  static Color get fill => _p.fill;
  static Color get quaternaryFill => _p.quaternaryFill;

  /// Text and icons on a tint-filled surface.
  static Color get onPrimary => _p.onTint;

  /// Translucent bars that content scrolls under.
  static Color get chrome => _p.chrome;
}

/// Corner radii — rounded rectangles sized like iOS controls and cards.
abstract final class AppRadii {
  static const double control = 12;
  static const double card = 14;
  static const double sheet = 16;
  static const double dialog = 14;
}

/// Motion. Critically damped, quick to settle; honour Reduce Motion.
abstract final class AppMotion {
  static const Duration press = Duration(milliseconds: 100);
  static const Duration quick = Duration(milliseconds: 200);
  static const Duration standard = Duration(milliseconds: 350);
  static const Curve standardCurve = Curves.easeOutCubic;

  static bool reduced(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}

/// Material widgets dressed to behave and look like their iOS counterparts.
abstract final class AppTheme {
  static final ThemeData light = _themeFor(Brightness.light, _Palette.light);
  static final ThemeData dark = _themeFor(Brightness.dark, _Palette.dark);

  static ThemeData _themeFor(Brightness brightness, _Palette p) {
    final dark = brightness == Brightness.dark;
    final text = AppTypography.textTheme((dark ? ThemeData.dark() : ThemeData.light()).textTheme)
        .apply(bodyColor: p.label, displayColor: p.label);
    final rounded = RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.control));
    final buttonLabel = appText(fontSize: 17, fontWeight: FontWeight.w600);
    OutlineInputBorder field([Color? edge, double width = 1.5]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          borderSide: edge == null ? BorderSide.none : BorderSide(color: edge, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: (dark ? const ColorScheme.dark() : const ColorScheme.light()).copyWith(
        primary: p.tint,
        onPrimary: p.onTint,
        secondary: AppColors.accent,
        onSecondary: Colors.white,
        error: AppColors.danger,
        onError: Colors.white,
        surface: p.groupedCard,
        onSurface: p.label,
        outline: p.separator,
        outlineVariant: p.separator,
      ),
      scaffoldBackgroundColor: p.groupedBackground,
      canvasColor: p.groupedBackground,
      textTheme: text,
      primaryTextTheme: text,
      iconTheme: IconThemeData(color: p.label),
      dividerColor: p.separator,
      dividerTheme: DividerThemeData(color: p.separator, thickness: 0.5, space: 1),

      // iOS feedback: a highlight while pressed, no Material ink ripple.
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: p.label.withValues(alpha: dark ? 0.10 : 0.06),
      hoverColor: p.label.withValues(alpha: 0.04),

      // Push/pop slide with edge-swipe back on every platform.
      pageTransitionsTheme: PageTransitionsTheme(builders: {
        for (final platform in TargetPlatform.values) platform: const CupertinoPageTransitionsBuilder(),
      }),
      cupertinoOverrideTheme: CupertinoThemeData(
        brightness: brightness,
        primaryColor: p.tint,
        scaffoldBackgroundColor: p.groupedBackground,
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: dark ? AppColors.darkAppBar : p.groupedBackground,
        foregroundColor: p.label,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: p.tint),
        actionsIconTheme: IconThemeData(color: p.tint),
        titleTextStyle: appText(color: p.label, fontSize: 17, fontWeight: FontWeight.w600),
      ),
      cardTheme: CardThemeData(
        color: p.groupedCard,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.card)),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.tint,
          foregroundColor: p.onTint,
          minimumSize: const Size(64, 50),
          shape: rounded,
          textStyle: buttonLabel,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.tint,
          foregroundColor: p.onTint,
          elevation: 0,
          minimumSize: const Size(64, 50),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: rounded,
          textStyle: buttonLabel,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.tint,
          backgroundColor: p.fill,
          minimumSize: const Size(64, 50),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          side: BorderSide.none,
          shape: rounded,
          textStyle: buttonLabel,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.tint,
          shape: rounded,
          textStyle: appText(fontSize: 17, fontWeight: FontWeight.w500),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(foregroundColor: p.tint)),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.fill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: appText(color: p.secondaryLabel, fontSize: 17),
        labelStyle: appText(color: p.secondaryLabel, fontSize: 17),
        floatingLabelStyle: appText(color: p.tint, fontSize: 15),
        border: field(),
        enabledBorder: field(),
        focusedBorder: field(p.tint),
        errorBorder: field(AppColors.danger, 1),
        focusedErrorBorder: field(AppColors.danger),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.fill,
        side: BorderSide.none,
        shape: const StadiumBorder(),
        labelStyle: appText(color: p.label, fontSize: 13, fontWeight: FontWeight.w500),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: p.tint,
        titleTextStyle: appText(color: p.label, fontSize: 17),
        subtitleTextStyle: appText(color: p.secondaryLabel, fontSize: 15),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? AppColors.stable : p.fill),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: p.groupedCard,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.dialog)),
        titleTextStyle: appText(color: p.label, fontSize: 17, fontWeight: FontWeight.w600),
        contentTextStyle: appText(color: p.label, fontSize: 15),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.groupedCard,
        modalBackgroundColor: p.groupedCard,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalBarrierColor: Colors.black.withValues(alpha: 0.35),
        showDragHandle: false, // sheets draw their own grabber
        dragHandleColor: p.tertiaryLabel,
        dragHandleSize: const Size(36, 5),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.sheet)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: dark ? p.raisedCard : p.label,
        contentTextStyle: appText(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.card)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.tint,
        foregroundColor: p.onTint,
        elevation: 2,
        highlightElevation: 2,
        shape: const StadiumBorder(),
      ),
    );
  }
}
