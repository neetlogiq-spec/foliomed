import '../models/newborn_screen.dart';
import '../models/newborn_tracking.dart';
import 'bilirubin.dart';

/// How one checklist line stands.
enum CheckState {
  /// Done / fine.
  ok,

  /// Recorded, but needs a decision before discharge (e.g. OAE refer,
  /// bilirubin near the line).
  attention,

  /// Not done or not recorded.
  missing,
}

class CheckLine {
  const CheckLine({
    required this.key,
    required this.title,
    required this.state,
    this.detail,
    this.manual = false,
  });

  final String key;
  final String title;
  final CheckState state;
  final String? detail;

  /// Ticked by staff (stored in `discharge_checks`) rather than worked out.
  final bool manual;
}

/// An item staff tick by hand. [askDetail] asks for a short note
/// (e.g. where and when follow-up is).
class ManualItem {
  const ManualItem(this.key, this.title, {this.askDetail});
  final String key;
  final String title;
  final String? askDetail;
}

/// Birth doses follow India's Universal Immunisation Programme (BCG, OPV-0,
/// Hepatitis B birth dose); Vitamin K is given at birth.
const List<ManualItem> kManualDischargeItems = [
  ManualItem('vitamin_k', 'Vitamin K given'),
  ManualItem('bcg', 'BCG'),
  ManualItem('opv0', 'OPV-0'),
  ManualItem('hep_b', 'Hepatitis B (birth dose)'),
  ManualItem('feeding', 'Feeding well'),
  ManualItem('urine_stool', 'Passed urine and meconium'),
  ManualItem('counselling', 'Parents counselled', askDetail: 'Danger signs, jaundice, cord care…'),
  ManualItem('follow_up', 'Follow-up arranged', askDetail: 'Where and when?'),
];

/// A ticked manual item.
class TickedCheck {
  const TickedCheck({required this.doneAt, this.doneByName, this.detail});
  final DateTime doneAt;
  final String? doneByName;
  final String? detail;
}

/// Everything the checklist reads. [bilirubinAssessment] is the guideline
/// result for [latestBilirubin] (null if none could be applied).
class DischargeInputs {
  const DischargeInputs({
    required this.now,
    this.screens = const [],
    this.latestBilirubin,
    this.bilirubinAssessment,
    this.phototherapyRunning = false,
    this.birthWeightGrams,
    this.latestWeight,
    this.ticked = const {},
  });

  final DateTime now;
  final List<NewbornScreen> screens;
  final BilirubinReading? latestBilirubin;
  final BiliAssessment? bilirubinAssessment;
  final bool phototherapyRunning;
  final int? birthWeightGrams;
  final WeightEntry? latestWeight;
  final Map<String, TickedCheck> ticked;
}

/// How recent a bilirubin or weight must be to count for discharge.
const Duration kDischargeRecency = Duration(hours: 24);

/// The newborn discharge checklist: worked-out lines first, then the
/// lines staff tick. Order is fixed so the list reads the same every time.
List<CheckLine> dischargeChecklist(DischargeInputs i) => [
      ..._investigationLines(i),
      _bilirubinLine(i),
      _phototherapyLine(i),
      _weightLine(i),
      for (final m in kManualDischargeItems) _manualLine(m, i.ticked[m.key]),
    ];

/// Lines that still need something, in checklist order.
List<CheckLine> outstanding(List<CheckLine> lines) =>
    [for (final l in lines) if (l.state != CheckState.ok) l];

// ── worked-out lines ─────────────────────────────────────────────────────

/// The resulted screen if any, else the latest one.
NewbornScreen? _bestScreen(List<NewbornScreen> screens) {
  if (screens.isEmpty) return null;
  final resulted = screens.where((s) => s.status == ScreenStatus.resulted).toList()
    ..sort((a, b) => (b.resultedAt ?? b.dueAt).compareTo(a.resultedAt ?? a.dueAt));
  if (resulted.isNotEmpty) return resulted.first;
  return ([...screens]..sort((a, b) => b.dueAt.compareTo(a.dueAt))).first;
}

List<CheckLine> _investigationLines(DischargeInputs i) {
  final s = _bestScreen(i.screens);
  final plan = switch (s?.status) {
    null => const CheckLine(
        key: 'investigations', title: 'Newborn investigations', state: CheckState.missing, detail: 'Not planned'),
    ScreenStatus.planned => CheckLine(
        key: 'investigations',
        title: '${s!.plannedHours}-hour investigations',
        state: CheckState.missing,
        detail: 'Not sent yet'),
    ScreenStatus.sent => CheckLine(
        key: 'investigations',
        title: '${s!.plannedHours}-hour investigations',
        state: CheckState.missing,
        detail: 'Sent, results awaited'),
    ScreenStatus.resulted => CheckLine(
        key: 'investigations',
        title: '${s!.plannedHours}-hour investigations',
        state: CheckState.ok,
        detail: 'Results in'),
  };
  final r = s?.results ?? const NewbornResults();
  CheckLine has(String key, String title, bool present) => CheckLine(
        key: key,
        title: title,
        state: present ? CheckState.ok : CheckState.missing,
        detail: present ? null : 'No result',
      );
  return [
    plan,
    has('tsh', 'TSH', r.tsh != null),
    has('blood_group', 'Blood grouping', (r.babyBloodGroup ?? '').isNotEmpty),
    _oaeLine(r.oaeRight, r.oaeLeft),
  ];
}

CheckLine _oaeLine(OaeResult? right, OaeResult? left) {
  const key = 'oae', title = 'OAE hearing screen';
  if (right == null || left == null || right == OaeResult.notDone || left == OaeResult.notDone) {
    return const CheckLine(key: key, title: title, state: CheckState.missing, detail: 'Not done in both ears');
  }
  if (right == OaeResult.refer || left == OaeResult.refer) {
    final ears = [if (right == OaeResult.refer) 'right', if (left == OaeResult.refer) 'left'].join(' and ');
    return CheckLine(key: key, title: title, state: CheckState.attention, detail: 'Refer ($ears): arrange a repeat');
  }
  return const CheckLine(key: key, title: title, state: CheckState.ok, detail: 'Pass both ears');
}

CheckLine _bilirubinLine(DischargeInputs i) {
  const key = 'bilirubin', title = 'Bilirubin before discharge';
  final b = i.latestBilirubin;
  if (b == null || i.now.difference(b.measuredAt) > kDischargeRecency) {
    return const CheckLine(key: key, title: title, state: CheckState.missing, detail: 'None in the last 24 hours');
  }
  final a = i.bilirubinAssessment;
  if (a == null) {
    return const CheckLine(
        key: key, title: title, state: CheckState.attention, detail: 'Measured; no guideline could be applied');
  }
  final state = switch (a.action) {
    BiliAction.none => CheckState.ok,
    BiliAction.repeat || BiliAction.approaching => CheckState.attention,
    _ => CheckState.missing,
  };
  return CheckLine(key: key, title: title, state: state, detail: '${a.action.label} (${a.guideline})');
}

CheckLine _phototherapyLine(DischargeInputs i) => i.phototherapyRunning
    ? const CheckLine(key: 'phototherapy', title: 'Phototherapy stopped', state: CheckState.missing, detail: 'Still running')
    : const CheckLine(key: 'phototherapy', title: 'Phototherapy stopped', state: CheckState.ok);

CheckLine _weightLine(DischargeInputs i) {
  const key = 'weight', title = 'Weight today';
  final w = i.latestWeight;
  if (w == null || i.now.difference(w.measuredAt) > kDischargeRecency) {
    return const CheckLine(key: key, title: title, state: CheckState.missing, detail: 'Not weighed in the last 24 hours');
  }
  final birth = i.birthWeightGrams;
  if (birth == null || birth <= 0) {
    return CheckLine(key: key, title: title, state: CheckState.ok, detail: '${w.grams} g');
  }
  final change = WeightChange(birth, w.grams);
  return CheckLine(
    key: key,
    title: title,
    state: change.flag == WeightFlag.alert ? CheckState.attention : CheckState.ok,
    detail: '${w.grams} g (${change.label} from birth)',
  );
}

CheckLine _manualLine(ManualItem m, TickedCheck? t) => CheckLine(
      key: m.key,
      title: m.title,
      manual: true,
      state: t == null ? CheckState.missing : CheckState.ok,
      detail: t == null ? null : [if (t.detail != null) t.detail!, if (t.doneByName != null) t.doneByName!].join(' · '),
    );
