import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'app_typography.dart';

/// FolioMed colour system, modelled on Apple's semantic colours:
/// grouped backgrounds, label / secondary-label text, hairline separators
/// and the iOS system palette for status. The brand blue stays the tint.
class AppColors {
  static bool isDark = false;

  // ── Brand + system tints ────────────────────────────────────────────
  static const Color primary = Color(0xFF0F6D99);
  static const Color darkPrimary = Color(0xFF5AADDB);
  static const Color accent = Color(0xFF00C7BE); // systemMint
  static const Color secondary = accent;
  static const Color danger = Color(0xFFFF3B30); // systemRed
  static const Color warning = Color(0xFFFF9500); // systemOrange
  static const Color doctorColor = Color(0xFF007AFF); // systemBlue
  static const Color nurseColor = Color(0xFF30B0C7); // systemTeal
  static const Color adminColor = Color(0xFFAF52DE); // systemPurple

  // ── Clinical severity ───────────────────────────────────────────────
  static const Color critical = danger;
  static const Color warningColor = warning;
  static const Color stable = Color(0xFF34C759); // systemGreen
  static const Color criticalBg = Color(0xFFFFE9E7);
  static const Color warningBg = Color(0xFFFFF2DE);
  static const Color stableBg = Color(0xFFE5F7E9);
  static const Color darkCriticalBg = Color(0xFF3A1513);
  static const Color darkWarningBg = Color(0xFF3A2A0D);
  static const Color darkStableBg = Color(0xFF11301B);

  // ── Light: systemGroupedBackground / label / separator ──────────────
  static const Color lightSurface = Color(0xFFF2F2F7);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightTextPrimary = Color(0xFF1C1C1E);
  static const Color lightTextSecondary = Color(0xFF636366); // secondaryLabel
  static const Color lightDivider = Color(0xFFD1D1D6);

  // ── Dark: true black base, elevated greys ───────────────────────────
  static const Color darkScaffold = Color(0xFF000000);
  static const Color darkCard = Color(0xFF1C1C1E);
  static const Color darkCardElevated = Color(0xFF2C2C2E);
  static const Color darkAppBar = Color(0xFF000000);
  static const Color darkDivider = Color(0xFF38383A);
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFF8E8E93); // secondaryLabel

  /// Grouped content relies on background contrast, not heavy shadows.
  static List<BoxShadow> get cardShadow => isDark
      ? const []
      : [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ];

  static double get iconChipOpacity => isDark ? 0.20 : 0.12;

  static Color get surface => isDark ? darkScaffold : lightSurface;
  static Color get background => surface;
  static Color get card => isDark ? darkCard : lightCard;
  static Color get appBarBg => isDark ? darkAppBar : lightSurface;
  static Color get textPrimary =>
      isDark ? darkTextPrimary : lightTextPrimary;
  static Color get textSecondary =>
      isDark ? darkTextSecondary : lightTextSecondary;
  static Color get divider => isDark ? darkDivider : lightDivider;
  static Color get criticalBackground => isDark ? darkCriticalBg : criticalBg;
  static Color get warningBackground => isDark ? darkWarningBg : warningBg;
  static Color get stableBackground => isDark ? darkStableBg : stableBg;

  /// iOS tertiaryLabel. Decorative only (icons, grabbers): at 1.7:1 it is
  /// too faint for text — use [textSecondary] for timestamps/metadata.
  static Color get tertiaryLabel =>
      isDark ? const Color(0xFF48484A) : const Color(0xFFC7C7CC);

  /// iOS quaternarySystemFill — inline badges and soft backgrounds.
  static Color get quaternaryFill =>
      isDark ? const Color(0x29747480) : const Color(0x14747480);

  /// Text/icons placed on a [primary]-filled surface. White fails contrast
  /// on the lighter dark-mode tint (2.5:1), so dark mode uses black (8.4:1).
  static Color get onPrimary => isDark ? Colors.black : Colors.white;

  /// iOS "tertiarySystemFill" — input fields and inset controls.
  static Color get fill =>
      isDark ? const Color(0x3D767680) : const Color(0x1F767680);

  /// Translucent chrome (nav bars) — content scrolls underneath.
  static Color get chrome =>
      isDark ? const Color(0xB81C1C1E) : const Color(0xD9F9F9F9);
}

/// Shared radii (continuous-looking rounded rectangles).
class AppRadii {
  AppRadii._();
  static const double control = 12;
  static const double card = 14;
  static const double sheet = 16;
  static const double dialog = 14;
}

/// Motion tokens. Apple defaults: critically damped, ~0.3–0.4s response;
/// momentum interactions only get a little bounce.
class AppMotion {
  AppMotion._();
  static const Duration press = Duration(milliseconds: 100);
  static const Duration quick = Duration(milliseconds: 200);
  static const Duration standard = Duration(milliseconds: 350);
  static const Curve standardCurve = Curves.easeOutCubic;

  /// Honour the OS "Reduce Motion" setting.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}

class AppTheme {
  static ThemeData get light => lightTheme;
  static ThemeData get dark => darkTheme;

  static ThemeData get darkTheme => _build(
        brightness: Brightness.dark,
        tint: AppColors.darkPrimary,
        background: AppColors.darkScaffold,
        card: AppColors.darkCard,
        textPrimary: AppColors.darkTextPrimary,
        textSecondary: AppColors.darkTextSecondary,
        divider: AppColors.darkDivider,
        fill: const Color(0x3D767680),
        chrome: AppColors.darkAppBar,
      );

  static ThemeData get lightTheme => _build(
        brightness: Brightness.light,
        tint: AppColors.primary,
        background: AppColors.lightSurface,
        card: AppColors.lightCard,
        textPrimary: AppColors.lightTextPrimary,
        textSecondary: AppColors.lightTextSecondary,
        divider: AppColors.lightDivider,
        fill: const Color(0x1F767680),
        chrome: AppColors.lightSurface,
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color tint,
    required Color background,
    required Color card,
    required Color textPrimary,
    required Color textSecondary,
    required Color divider,
    required Color fill,
    required Color chrome,
  }) {
    final isDark = brightness == Brightness.dark;
    final base = isDark ? ThemeData.dark() : ThemeData.light();
    final textTheme = AppTypography.textTheme(base.textTheme).apply(
      bodyColor: textPrimary,
      displayColor: textPrimary,
    );
    final onTint = isDark ? Colors.black : Colors.white;
    final colorScheme = (isDark ? const ColorScheme.dark() : const ColorScheme.light())
        .copyWith(
      primary: tint,
      onPrimary: onTint,
      secondary: AppColors.accent,
      onSecondary: Colors.white,
      error: AppColors.danger,
      onError: Colors.white,
      surface: card,
      onSurface: textPrimary,
      outline: divider,
      outlineVariant: divider,
    );
    final controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.control),
    );
    final buttonText = appText(fontSize: 17, fontWeight: FontWeight.w600);
    final noBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.control),
      borderSide: BorderSide.none,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      textTheme: textTheme,
      primaryTextTheme: textTheme,

      // Apple feedback: an instant highlight on press, no Material ripple.
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: textPrimary.withOpacity(isDark ? 0.10 : 0.06),
      hoverColor: textPrimary.withOpacity(0.04),

      // Same path in and out, with edge-swipe back, on every platform.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
        },
      ),
      cupertinoOverrideTheme: CupertinoThemeData(
        brightness: brightness,
        primaryColor: tint,
        scaffoldBackgroundColor: background,
      ),

      dividerColor: divider,
      dividerTheme: DividerThemeData(color: divider, thickness: 0.5, space: 1),

      appBarTheme: AppBarTheme(
        backgroundColor: chrome,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: tint),
        actionsIconTheme: IconThemeData(color: tint),
        titleTextStyle: appText(
          color: textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),

      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: tint,
          foregroundColor: onTint,
          elevation: 0,
          minimumSize: const Size(64, 50),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: controlShape,
          textStyle: buttonText,
        ).copyWith(
          overlayColor:
              WidgetStatePropertyAll(Colors.black.withOpacity(0.12)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: tint,
          foregroundColor: onTint,
          minimumSize: const Size(64, 50),
          shape: controlShape,
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: tint,
          shape: controlShape,
          textStyle: appText(fontSize: 17, fontWeight: FontWeight.w500),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: tint,
          backgroundColor: fill,
          minimumSize: const Size(64, 50),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          side: BorderSide.none,
          shape: controlShape,
          textStyle: buttonText,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: tint),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fill,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: appText(color: textSecondary, fontSize: 17),
        labelStyle: appText(color: textSecondary, fontSize: 17),
        floatingLabelStyle: appText(color: tint, fontSize: 15),
        border: noBorder,
        enabledBorder: noBorder,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          borderSide: BorderSide(color: tint, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: fill,
        side: BorderSide.none,
        labelStyle: appText(
          color: textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        shape: const StadiumBorder(),
      ),

      listTileTheme: ListTileThemeData(
        iconColor: tint,
        titleTextStyle: appText(color: textPrimary, fontSize: 17),
        subtitleTextStyle: appText(color: textSecondary, fontSize: 15),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.dialog),
        ),
        titleTextStyle: appText(
          color: textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: appText(color: textPrimary, fontSize: 15),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: card,
        modalBackgroundColor: card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalBarrierColor: Colors.black.withOpacity(0.35),
        showDragHandle: false, // sheets draw their own grabber
        dragHandleColor: isDark ? const Color(0xFF48484A) : const Color(0xFFC7C7CC),
        dragHandleSize: const Size(36, 5),
        shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppRadii.sheet)),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? AppColors.darkCardElevated : textPrimary,
        contentTextStyle: appText(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? AppColors.stable : fill),
        trackOutlineColor:
            const WidgetStatePropertyAll(Colors.transparent),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: tint,
        foregroundColor: onTint,
        elevation: 2,
        highlightElevation: 2,
        shape: const StadiumBorder(),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        elevation: 0,
      ),

      iconTheme: IconThemeData(color: textPrimary),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: tint),
      scrollbarTheme: const ScrollbarThemeData(radius: Radius.circular(8)),
    );
  }
}
