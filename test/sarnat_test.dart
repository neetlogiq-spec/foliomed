import 'package:flutter_test/flutter_test.dart';
import 'package:foliomed/tools/sarnat.dart';

SarnatAnswers _all(List<SarnatGrade> perArea) {
  var a = const SarnatAnswers();
  for (var area = 0; area < kSarnatAreas.length; area++) {
    for (var s = 0; s < kSarnatAreas[area].signs.length; s++) {
      a = a.set(area, s, perArea[area]);
    }
  }
  return a;
}

void main() {
  const n = SarnatGrade.normal, mi = SarnatGrade.mild, mo = SarnatGrade.moderate, se = SarnatGrade.severe;

  test('six areas, nine signs, four grades each', () {
    expect(kSarnatAreas.length, 6);
    expect(const SarnatAnswers().signCount, 9);
    for (final a in kSarnatAreas) {
      for (final s in a.signs) {
        expect(s.looks.length, 4, reason: s.name);
      }
    }
  });

  test('area grade is its worst sign', () {
    final a = const SarnatAnswers().set(5, 0, n).set(5, 1, mi).set(5, 2, se);
    expect(a.areaGrade(5), se);
    expect(const SarnatAnswers().set(4, 0, mo).areaGrade(4), isNull); // Moro not graded yet
  });

  test('NICHD criterion needs 3 of 6 areas moderate or severe', () {
    expect(_all([mo, mo, mi, mi, n, n]).meetsNichdCriterion, isFalse);
    expect(_all([mo, se, mo, mi, n, n]).meetsNichdCriterion, isTrue);
  });

  test('stage is the most common grade; ties go to the more severe', () {
    expect(_all([n, n, n, n, mi, n]).stage, n);
    expect(_all([mo, mo, mo, mi, mi, mi]).stage, mo);
    expect(_all([se, se, mo, mo, mi, n]).stage, se);
    expect(_all([mo, mi, n, n, n, n]).stage, n);
  });

  test('incomplete answers give no stage', () {
    final a = const SarnatAnswers().set(0, 0, se);
    expect(a.stage, isNull);
    expect(a.meetsNichdCriterion, isFalse);
  });

  test('summary', () {
    expect(_all([mo, se, mo, mi, n, n]).summary(),
        startsWith('Modified Sarnat: moderate encephalopathy (3 of 6 areas moderate or severe — meets the NICHD criterion'));
  });
}
