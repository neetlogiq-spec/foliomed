import 'package:flutter_test/flutter_test.dart';
import 'package:foliomed/tools/newborn_scores.dart';

void main() {
  test('maximum totals match the published scores', () {
    expect(apgar.maxTotal, 10);
    expect(downes.maxTotal, 10);
    expect(silvermanAnderson.maxTotal, 10);
    expect(thompson.maxTotal, 22);
    expect(latch.maxTotal, 10);
  });

  test('bands cover every possible total exactly once', () {
    for (final d in kNewbornScores) {
      for (var t = 0; t <= d.maxTotal; t++) {
        final hits = d.bands.where((b) => t >= b.min && t <= b.max).length;
        expect(hits, 1, reason: '${d.name} total $t');
      }
    }
  });

  test('every option list starts at 0 and counts up by one', () {
    for (final d in kNewbornScores) {
      for (final i in d.items) {
        expect([for (final o in i.options) o.points], List.generate(i.options.length, (n) => n),
            reason: '${d.name}: ${i.name}');
      }
    }
  });

  test('Downes 4 is moderate, 8 is impending failure', () {
    expect(downes.bandFor(4)!.label, 'moderate respiratory distress');
    expect(downes.bandFor(7)!.label, 'moderate respiratory distress');
    expect(downes.bandFor(8)!.label, 'impending respiratory failure');
  });

  test('Thompson bands: 10 mild, 11 moderate, 15 severe', () {
    expect(thompson.bandFor(10)!.label, 'mild HIE');
    expect(thompson.bandFor(11)!.label, 'moderate HIE');
    expect(thompson.bandFor(15)!.label, 'severe HIE');
  });

  test('answers total up, band only when complete, summary reads well', () {
    var a = const ScoreAnswers(downes);
    a = a.choose(0, 1).choose(1, 1).choose(2, 0).choose(3, 1);
    expect(a.complete, isFalse);
    expect(a.band, isNull);
    a = a.choose(4, 1);
    expect(a.total, 4);
    expect(a.band!.label, 'moderate respiratory distress');
    expect(a.summary(), startsWith('Downes 4/10 — moderate respiratory distress.\nRespiratory rate: 60–80/min (1); '));
    // Changing an answer replaces it rather than adding.
    expect(a.choose(4, 0).total, 3);
  });
}
