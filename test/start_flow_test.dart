import 'package:flutter_test/flutter_test.dart';
import 'package:foliomed/screens/help/help_topics.dart';
import 'package:foliomed/screens/start/launch_decision.dart';
import 'package:foliomed/services/device_power_settings.dart';
import 'package:foliomed/services/review_request.dart';

void main() {
  group('launch routing', () {
    LaunchStep go({
      bool signedIn = true,
      bool hasProfile = true,
      bool welcomeSeen = true,
      bool roleConfirmed = true,
      bool alertSetupNeeded = false,
    }) =>
        decideLaunch(
          signedIn: signedIn,
          hasProfile: hasProfile,
          welcomeSeen: welcomeSeen,
          roleConfirmed: roleConfirmed,
          alertSetupNeeded: alertSetupNeeded,
        );

    test('first open shows Welcome, later opens go to Sign in', () {
      expect(go(signedIn: false, welcomeSeen: false), LaunchStep.welcome);
      expect(go(signedIn: false), LaunchStep.signIn);
    });
    test('signed in without a profile goes back to Sign in', () {
      expect(go(hasProfile: false), LaunchStep.signIn);
    });
    test('role, then alert setup, then home — in that order', () {
      expect(go(roleConfirmed: false, alertSetupNeeded: true), LaunchStep.chooseRole);
      expect(go(alertSetupNeeded: true), LaunchStep.alertSetup);
      expect(go(), LaunchStep.home);
    });
  });

  group('review requests are rare', () {
    final first = DateTime(2026, 1, 1);
    test('needs two weeks and ten sessions', () {
      expect(ReviewRequest.shouldAsk(now: first.add(const Duration(days: 13)), firstSeen: first, sessions: 50), isFalse);
      expect(ReviewRequest.shouldAsk(now: first.add(const Duration(days: 30)), firstSeen: first, sessions: 9), isFalse);
      expect(ReviewRequest.shouldAsk(now: first.add(const Duration(days: 14)), firstSeen: first, sessions: 10), isTrue);
    });
    test('at most once every 120 days', () {
      final now = first.add(const Duration(days: 200));
      expect(ReviewRequest.shouldAsk(now: now, firstSeen: first, sessions: 40, lastAsked: now.subtract(const Duration(days: 119))), isFalse);
      expect(ReviewRequest.shouldAsk(now: now, firstSeen: first, sessions: 40, lastAsked: now.subtract(const Duration(days: 120))), isTrue);
    });
  });

  group('help', () {
    test('every section has topics and every answer is substantive', () {
      expect(kHelpSections, isNotEmpty);
      for (final s in kHelpSections) {
        expect(s.topics, isNotEmpty, reason: s.title);
        for (final t in s.topics) {
          expect(t.answer.length, greaterThan(40), reason: t.question);
        }
      }
    });
    test('search matches all words, case-insensitive', () {
      expect(searchHelp('MOTHER name').map((r) => r.$2.question), contains('Can I find a baby by the mother’s name?'));
      expect(searchHelp('bilirubin aap'), isNotEmpty);
      expect(searchHelp('zebra quantum'), isEmpty);
    });
  });

  group('manufacturer power settings', () {
    test('known brands, including sub-brands', () {
      expect(powerGuideFor('Xiaomi')!.brand, 'Xiaomi');
      expect(powerGuideFor('Redmi')!.brand, 'Xiaomi');
      expect(powerGuideFor('POCO')!.brand, 'Xiaomi');
      expect(powerGuideFor('samsung')!.brand, 'Samsung');
      expect(powerGuideFor('OnePlus')!.screens, isNotEmpty);
    });
    test('brands that need no extra step get no guide', () {
      expect(powerGuideFor('Google'), isNull);
      expect(powerGuideFor('motorola'), isNull);
    });
  });
}
