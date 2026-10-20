import 'package:flutter_test/flutter_test.dart';
import 'package:foliomed/tools/ballard.dart';
import 'package:foliomed/tools/bp_centiles.dart';
import 'package:foliomed/tools/vaccines.dart';

void main() {
  group('New Ballard', () {
    test('maturity rating matches the official table', () {
      final table = {-10: 20, -5: 22, 0: 24, 5: 26, 10: 28, 15: 30, 20: 32, 25: 34, 30: 36, 35: 38, 40: 40, 45: 42, 50: 44};
      table.forEach((score, weeks) => expect(ballardWeeks(score), weeks.toDouble(), reason: 'score $score'));
    });

    test('twelve items, totals span −10 (or lower) to 50', () {
      final items = [...kBallardNeuromuscular, ...ballardPhysical(male: true)];
      expect(items.length, 12);
      final max = items.fold<int>(0, (s, i) => s + i.maxPoints);
      final min = items.fold<int>(0, (s, i) => s + i.options.map((o) => o.points).reduce((a, b) => a < b ? a : b));
      expect(max, 50);
      expect(min, lessThanOrEqualTo(-10));
    });

    test('points within each item count up by one', () {
      for (final i in [...kBallardNeuromuscular, ...ballardPhysical(male: false)]) {
        final pts = [for (final o in i.options) o.points];
        for (var k = 1; k < pts.length; k++) {
          expect(pts[k], pts[k - 1] + 1, reason: i.name);
        }
      }
    });
  });

  group('Dionne BP', () {
    test('table rows (spot checks against the source)', () {
      final r40 = bpRowFor(40)!;
      expect(r40.sbp, (80, 95, 100));
      expect(r40.map, (60, 75, 80));
      expect(r40.dbp, (50, 65, 70));
      final r26 = bpRowFor(26)!;
      expect(r26.sbp, (55, 72, 77));
      expect(r26.dbp, (30, 50, 56));
      expect(bpRowFor(44)!.sbp, (88, 105, 110));
    });

    test('row choice: nearest, lower on ties, null outside 26–44', () {
      expect(bpRowFor(33)!.pmaWeeks, 32);
      expect(bpRowFor(33.6)!.pmaWeeks, 34);
      expect(bpRowFor(44.9)!.pmaWeeks, 44);
      expect(bpRowFor(25.9), isNull);
      expect(bpRowFor(45), isNull);
    });

    test('bands', () {
      expect(bpBand(94, (80, 95, 100)), BpBand.normal);
      expect(bpBand(95, (80, 95, 100)), BpBand.high);
      expect(bpBand(100, (80, 95, 100)), BpBand.veryHigh);
    });
  });

  group('NIS vaccines', () {
    final born = DateTime(2026, 1, 1);

    test('due dates', () {
      final plan = vaccinePlan(born: born, today: born);
      DateTime dueOf(String n) => plan.firstWhere((p) => p.dose.name == n).dueOn;
      expect(dueOf('BCG'), born);
      expect(dueOf('Pentavalent-1'), DateTime(2026, 2, 12));
      expect(dueOf('Pentavalent-3'), DateTime(2026, 4, 9));
    });

    test('windows: Hep B birth dose after 24 h, OPV-0 after 15 days, BCG after 1 year', () {
      final day3 = vaccinePlan(born: born, today: born.add(const Duration(days: 3)));
      DoseStatus st(List<DosePlan> p, String n) => p.firstWhere((x) => x.dose.name == n).status;
      expect(st(day3, 'Hepatitis B birth dose'), DoseStatus.missedWindow);
      expect(st(day3, 'OPV-0'), DoseStatus.overdue);
      expect(st(day3, 'BCG'), DoseStatus.overdue);
      expect(st(day3, 'Pentavalent-1'), DoseStatus.upcoming);
      final day20 = vaccinePlan(born: born, today: born.add(const Duration(days: 20)));
      expect(st(day20, 'OPV-0'), DoseStatus.missedWindow);
      final over1y = vaccinePlan(born: born, today: DateTime(2027, 1, 10));
      expect(st(over1y, 'BCG'), DoseStatus.missedWindow);
      expect(st(over1y, 'Rotavirus-1'), DoseStatus.missedWindow);
      expect(st(over1y, 'OPV-1'), DoseStatus.overdue); // OPV until 5 years
    });

    test('given doses are marked given', () {
      final p = vaccinePlan(born: born, today: born.add(const Duration(days: 3)), given: {'BCG', 'OPV-0'});
      expect(p.firstWhere((x) => x.dose.name == 'BCG').status, DoseStatus.given);
    });
  });
}
