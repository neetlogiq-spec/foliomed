import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foliomed/utils/app_typography.dart';
import 'package:foliomed/widgets/pressable.dart';

void main() {
  group('AppTypography on Apple platforms', () {
    setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.iOS);
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('uses SF Text below 20pt and SF Display from 20pt', () {
      expect(AppTypography.familyFor(17), 'CupertinoSystemText');
      expect(AppTypography.familyFor(20), 'CupertinoSystemDisplay');
    });

    test('follows the HIG tracking table', () {
      expect(AppTypography.trackingFor(17), -0.43);
      expect(AppTypography.trackingFor(12), 0.0);
      expect(AppTypography.trackingFor(34), 0.40);
    });
  });

  group('AppTypography elsewhere', () {
    setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.android);
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('uses the platform system font', () {
      expect(AppTypography.familyFor(17), isNull);
    });

    test('tracking is size-specific: open small, neutral body, tight large', () {
      expect(AppTypography.trackingFor(10), greaterThan(0));
      expect(AppTypography.trackingFor(15), 0);
      expect(AppTypography.trackingFor(32), lessThan(0));
    });
  });

  group('appText', () {
    test('explicit letterSpacing and height win over defaults', () {
      final style = appText(fontSize: 34, letterSpacing: 8, height: 2);
      expect(style.letterSpacing, 8);
      expect(style.height, 2);
    });

    test('large text gets tight leading, body keeps the default', () {
      expect(appText(fontSize: 34).height, 1.1);
      expect(appText(fontSize: 15).height, isNull);
    });

    test('textTheme drops Material letterSpacing', () {
      final theme = AppTypography.textTheme(ThemeData.light().textTheme);
      expect(theme.bodyMedium!.letterSpacing,
          AppTypography.trackingFor(theme.bodyMedium!.fontSize!));
    });
  });

  group('Pressable', () {
    Widget host({required VoidCallback onTap, bool reduceMotion = false}) {
      return MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: Center(
            child: Pressable(
              onTap: onTap,
              child: const SizedBox(width: 100, height: 100),
            ),
          ),
        ),
      );
    }

    double scaleOf(WidgetTester tester) {
      final transform = tester.widget<Transform>(
        find.descendant(
            of: find.byType(Pressable), matching: find.byType(Transform)),
      );
      return transform.transform.storage[0]; // x-axis scale
    }

    testWidgets('shrinks on touch-down and fires onTap on release',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(host(onTap: () => taps++));
      final gesture =
          await tester.startGesture(tester.getCenter(find.byType(Pressable)));
      await tester.pump(const Duration(milliseconds: 150));
      expect(scaleOf(tester), closeTo(0.97, 0.001));
      expect(taps, 0, reason: 'commit happens on release, not on press');

      await gesture.up();
      await tester.pumpAndSettle();
      expect(taps, 1);
      expect(scaleOf(tester), closeTo(1.0, 0.001));
    });

    testWidgets('Reduce Motion keeps scale at 1', (tester) async {
      await tester.pumpWidget(host(onTap: () {}, reduceMotion: true));
      await tester.startGesture(tester.getCenter(find.byType(Pressable)));
      await tester.pump(const Duration(milliseconds: 150));
      expect(scaleOf(tester), 1.0);
    });
  });
}
