import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// FolioMed type system — Apple-style.
///
/// * Uses the platform's system font (San Francisco on iOS/macOS, Roboto
///   on Android, system-ui elsewhere) instead of a downloaded custom face:
///   the system font already ships optical sizing and legibility tuning,
///   and nothing is fetched from the network at runtime.
/// * Tracking is size-specific, never one value for every size. On Apple
///   platforms it follows the SF Pro tracking table from Apple's HIG; on
///   other platforms large text is tightened (-0.02em) and small text
///   opened up slightly.
/// * Large text gets tight leading; body text keeps the platform default.
///
/// An explicit `letterSpacing` / `height` always wins — use that for
/// deliberately letter-spaced wordmarks like "FOLIOMED".
TextStyle appText({
  TextStyle? textStyle,
  Color? color,
  Color? backgroundColor,
  double? fontSize,
  FontWeight? fontWeight,
  FontStyle? fontStyle,
  double? letterSpacing,
  double? wordSpacing,
  TextBaseline? textBaseline,
  double? height,
  Locale? locale,
  Paint? foreground,
  Paint? background,
  List<Shadow>? shadows,
  List<FontFeature>? fontFeatures,
  TextDecoration? decoration,
  Color? decorationColor,
  TextDecorationStyle? decorationStyle,
  double? decorationThickness,
}) {
  final size = fontSize ?? textStyle?.fontSize ?? AppTypography.bodySize;
  return (textStyle ?? const TextStyle()).copyWith(
    fontFamily: AppTypography.familyFor(size),
    color: color,
    backgroundColor: backgroundColor,
    fontSize: fontSize,
    fontWeight: fontWeight,
    fontStyle: fontStyle,
    letterSpacing:
        letterSpacing ?? textStyle?.letterSpacing ?? AppTypography.trackingFor(size),
    wordSpacing: wordSpacing,
    textBaseline: textBaseline,
    height: height ?? textStyle?.height ?? AppTypography.leadingFor(size),
    locale: locale,
    foreground: foreground,
    background: background,
    shadows: shadows,
    fontFeatures: fontFeatures,
    decoration: decoration,
    decorationColor: decorationColor,
    decorationStyle: decorationStyle,
    decorationThickness: decorationThickness,
  );
}

/// Monospaced digits/code (replaces the old Roboto Mono usages).
TextStyle appMonoText({
  Color? color,
  double? fontSize,
  FontWeight? fontWeight,
  double? letterSpacing,
  double? height,
}) {
  return TextStyle(
    fontFamily: AppTypography.isApple ? 'Menlo' : 'monospace',
    fontFamilyFallback: const ['Menlo', 'Roboto Mono', 'monospace'],
    color: color,
    fontSize: fontSize,
    fontWeight: fontWeight,
    letterSpacing: letterSpacing,
    height: height,
  );
}

class AppTypography {
  AppTypography._();

  static const double bodySize = 14;

  /// Size at which SF switches from the Text to the Display optical cut.
  static const double _displayThreshold = 20;

  static bool get isApple =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  /// Flutter's names for San Francisco's two optical cuts; `null` lets
  /// every other platform use its own system font.
  static String? familyFor(double size) {
    if (!isApple) return null;
    return size >= _displayThreshold
        ? 'CupertinoSystemDisplay'
        : 'CupertinoSystemText';
  }

  /// SF Pro tracking (points) from Apple's Human Interface Guidelines.
  static const Map<int, double> _sfTracking = {
    6: 0.24, 7: 0.23, 8: 0.21, 9: 0.17, 10: 0.12, 11: 0.07, 12: 0.0,
    13: -0.08, 14: -0.15, 15: -0.23, 16: -0.31, 17: -0.43, 18: -0.44,
    19: -0.45, 20: -0.45, 21: -0.36, 22: -0.26, 23: -0.10, 24: 0.07,
    25: 0.15, 26: 0.22, 27: 0.29, 28: 0.38, 29: 0.40, 30: 0.40, 31: 0.39,
    32: 0.41, 33: 0.40, 34: 0.40, 35: 0.38, 36: 0.37, 37: 0.36, 38: 0.37,
    39: 0.38, 40: 0.37, 41: 0.36, 42: 0.37, 43: 0.38, 44: 0.37, 45: 0.35,
    46: 0.36, 47: 0.37, 48: 0.35, 49: 0.33, 50: 0.34, 51: 0.35, 52: 0.33,
    53: 0.31, 54: 0.32, 56: 0.30, 58: 0.28, 60: 0.26, 62: 0.24, 64: 0.22,
    66: 0.19, 68: 0.17, 70: 0.14, 72: 0.14, 76: 0.07, 80: 0.0,
  };

  static double trackingFor(double size) {
    if (isApple) {
      final rounded = size.round().clamp(6, 80);
      for (var s = rounded; s >= 6; s--) {
        final t = _sfTracking[s];
        if (t != null) return t;
      }
      return 0;
    }
    if (size <= 11) return size * 0.01;
    if (size < 17) return 0;
    if (size < 24) return size * -0.01;
    return size * -0.02;
  }

  /// Applies the system font + size-specific tracking to every style of a
  /// Material [TextTheme].
  static TextTheme textTheme(TextTheme input) {
    // ThemeData's base text themes carry colours but no sizes (those live
    // in Typography's geometry), so merge the 2021 geometry first.
    final base = Typography.englishLike2021.merge(input);
    // Rebuild each style from size/weight/colour only, so Material's own
    // fixed letterSpacing and height never leak through.
    TextStyle? apply(TextStyle? style) => style == null
        ? null
        : appText(
            textStyle: TextStyle(
              inherit: style.inherit,
              fontSize: style.fontSize,
              fontWeight: style.fontWeight,
              color: style.color,
              textBaseline: style.textBaseline,
            ),
          );
    return base.copyWith(
      displayLarge: apply(base.displayLarge),
      displayMedium: apply(base.displayMedium),
      displaySmall: apply(base.displaySmall),
      headlineLarge: apply(base.headlineLarge),
      headlineMedium: apply(base.headlineMedium),
      headlineSmall: apply(base.headlineSmall),
      titleLarge: apply(base.titleLarge),
      titleMedium: apply(base.titleMedium),
      titleSmall: apply(base.titleSmall),
      bodyLarge: apply(base.bodyLarge),
      bodyMedium: apply(base.bodyMedium),
      bodySmall: apply(base.bodySmall),
      labelLarge: apply(base.labelLarge),
      labelMedium: apply(base.labelMedium),
      labelSmall: apply(base.labelSmall),
    );
  }

  /// Tight leading on large text; `null` (platform default) for body.
  static double? leadingFor(double size) {
    if (size >= 34) return 1.1;
    if (size >= 24) return 1.15;
    return null;
  }
}
