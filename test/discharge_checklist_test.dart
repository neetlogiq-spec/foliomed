import 'package:flutter_test/flutter_test.dart';
import 'package:foliomed/clinical/bilirubin.dart';
import 'package:foliomed/clinical/discharge_checklist.dart';
import 'package:foliomed/models/newborn_screen.dart';
import 'package:foliomed/models/newborn_tracking.dart';

final _now = DateTime(2026, 10, 22, 10);

NewbornScreen _screen(ScreenStatus status, {NewbornResults results = const NewbornResults()}) => NewbornScreen(
      id: 's1',
      patientId: 'p1',
      wardId: 'w',
      plannedHours: 48,
      leadHours: 12,
      dueAt: _now.subtract(const Duration(hours: 10)),
      status: status,
      results: results,
      resultedAt: status == ScreenStatus.resulted ? _now.subtract(const Duration(hours: 2)) : null,
    );

const _fullResults = NewbornResults(
  tsh: 3.2,
  babyBloodGroup: 'O+',
  oaeRight: OaeResult.pass,
  oaeLeft: OaeResult.pass,
);

BilirubinReading _bili(Duration ago) => BilirubinReading(
      id: 'b1',
      patientId: 'p1',
      measuredAt: _now.subtract(ago),
      value: 10,
      isUmol: false,
      transcutaneous: false,
    );

WeightEntry _weight(int grams, Duration ago) =>
    WeightEntry(id: 'w1', patientId: 'p1', measuredAt: _now.subtract(ago), grams: grams);

BiliAssessment _assess(BiliAction action) => BiliAssessment(
      guideline: 'AAP 2022',
      hoursOfAge: 60,
      tsbUmol: 171,
      thresholds: const BiliThresholds(phototherapy: 250, exchange: 400),
      action: action,
    );

CheckLine _line(List<CheckLine> lines, String key) => lines.firstWhere((l) => l.key == key);

Map<String, TickedCheck> _allTicked() => {
      for (final m in kManualDischargeItems) m.key: TickedCheck(doneAt: _now, doneByName: 'Nurse B'),
    };

void main() {
  test('a fully recorded, well baby is ready', () {
    final lines = dischargeChecklist(DischargeInputs(
      now: _now,
      screens: [_screen(ScreenStatus.resulted, results: _fullResults)],
      latestBilirubin: _bili(const Duration(hours: 3)),
      bilirubinAssessment: _assess(BiliAction.none),
      birthWeightGrams: 3000,
      latestWeight: _weight(2850, const Duration(hours: 4)),
      ticked: _allTicked(),
    ));
    expect(outstanding(lines), isEmpty);
    expect(lines.where((l) => l.manual).length, kManualDischargeItems.length);
  });

  test('nothing recorded: every line is missing', () {
    final lines = dischargeChecklist(DischargeInputs(now: _now));
    final todo = outstanding(lines);
    // Phototherapy "stopped" is fine when there was none.
    expect(todo.length, lines.length - 1);
    expect(_line(lines, 'phototherapy').state, CheckState.ok);
    expect(_line(lines, 'investigations').detail, 'Not planned');
  });

  test('investigations: planned, sent, resulted', () {
    expect(_line(dischargeChecklist(DischargeInputs(now: _now, screens: [_screen(ScreenStatus.planned)])), 'investigations').detail,
        'Not sent yet');
    expect(_line(dischargeChecklist(DischargeInputs(now: _now, screens: [_screen(ScreenStatus.sent)])), 'investigations').detail,
        'Sent, results awaited');
    final done = dischargeChecklist(DischargeInputs(now: _now, screens: [_screen(ScreenStatus.resulted, results: _fullResults)]));
    expect(_line(done, 'investigations').state, CheckState.ok);
    expect(_line(done, 'tsh').state, CheckState.ok);
    expect(_line(done, 'blood_group').state, CheckState.ok);
  });

  test('OAE refer needs a decision and names the ear', () {
    final lines = dischargeChecklist(DischargeInputs(
      now: _now,
      screens: [
        _screen(ScreenStatus.resulted,
            results: const NewbornResults(oaeRight: OaeResult.pass, oaeLeft: OaeResult.refer)),
      ],
    ));
    expect(_line(lines, 'oae').state, CheckState.attention);
    expect(_line(lines, 'oae').detail, contains('left'));
  });

  test('bilirubin: stale reading is missing; near the line needs a decision; above is missing', () {
    CheckLine bili({required Duration ago, BiliAction? action}) => _line(
        dischargeChecklist(DischargeInputs(
          now: _now,
          latestBilirubin: _bili(ago),
          bilirubinAssessment: action == null ? null : _assess(action),
        )),
        'bilirubin');
    expect(bili(ago: const Duration(hours: 30), action: BiliAction.none).state, CheckState.missing);
    expect(bili(ago: const Duration(hours: 2), action: BiliAction.none).state, CheckState.ok);
    expect(bili(ago: const Duration(hours: 2), action: BiliAction.approaching).state, CheckState.attention);
    expect(bili(ago: const Duration(hours: 2), action: BiliAction.phototherapy).state, CheckState.missing);
    expect(bili(ago: const Duration(hours: 2)).state, CheckState.attention);
  });

  test('running phototherapy blocks; weight loss over 10% needs a decision', () {
    final lines = dischargeChecklist(DischargeInputs(
      now: _now,
      phototherapyRunning: true,
      birthWeightGrams: 3000,
      latestWeight: _weight(2650, const Duration(hours: 1)),
    ));
    expect(_line(lines, 'phototherapy').state, CheckState.missing);
    expect(_line(lines, 'weight').state, CheckState.attention);
    expect(_line(lines, 'weight').detail, contains('−11.7%'));
  });

  test('ticked items show who ticked them and any detail', () {
    final lines = dischargeChecklist(DischargeInputs(now: _now, ticked: {
      'follow_up': TickedCheck(doneAt: _now, doneByName: 'Dr A', detail: 'Paeds OPD 24 Oct'),
    }));
    final f = _line(lines, 'follow_up');
    expect(f.state, CheckState.ok);
    expect(f.detail, 'Paeds OPD 24 Oct · Dr A');
    expect(_line(lines, 'bcg').state, CheckState.missing);
  });
}
