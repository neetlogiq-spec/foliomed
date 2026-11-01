import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foliomed/clinical/handover.dart';
import 'package:foliomed/forms/builtin_forms.dart';
import 'package:foliomed/forms/form_due.dart';
import 'package:foliomed/forms/form_model.dart';
import 'package:foliomed/forms/form_summary.dart';
import 'package:foliomed/models/patient.dart';
import 'package:foliomed/models/patient_form.dart';
import 'package:foliomed/providers/appearance_provider.dart';
import 'package:foliomed/screens/forms/form_editor_screen.dart';
import 'package:foliomed/screens/forms/form_fill_screen.dart';
import 'package:provider/provider.dart';

FormTemplate _builtIn(String key) => kBuiltInForms.firstWhere((f) => f.key == key);

void main() {
  group('starter forms', () {
    test('ids are unique per form; expected answers are valid', () {
      expect(kBuiltInForms.map((f) => f.key).toSet().length, kBuiltInForms.length);
      for (final t in kBuiltInForms) {
        final ids = t.definition.fields.map((f) => f.id).toList();
        expect(ids.toSet().length, ids.length, reason: t.key);
        for (final f in t.definition.fields) {
          if (f.type == FieldType.choice) {
            expect(f.options.length, greaterThanOrEqualTo(2), reason: '${t.key}.${f.id}');
            if (f.normal != null) expect(f.options, contains(f.normal), reason: '${t.key}.${f.id}');
          }
          if (f.type == FieldType.yesNo && f.normal != null) expect([kYes, kNo], contains(f.normal));
        }
      }
    });

    test('a ward copy with the same key replaces the built-in; hidden ones drop out', () {
      final copy = FormTemplate(
        id: 'x',
        key: 'ward_round',
        name: 'Our round',
        description: '',
        definition: _builtIn('ward_round').definition,
      );
      final names = formsForWard([copy]).map((f) => f.name).toList();
      expect(names, contains('Our round'));
      expect(names, isNot(contains('Ward round')));
      final hidden = FormTemplate(
        id: 'y',
        key: 'mine',
        name: 'Hidden',
        description: '',
        definition: const FormDefinition(sections: []),
        archived: true,
      );
      expect(formsForWard([hidden]).map((f) => f.name), isNot(contains('Hidden')));
    });

    test('definitions survive JSON', () {
      for (final t in kBuiltInForms) {
        final back = FormDefinition.fromJson(t.definition.toJson());
        expect(back.toJson(), t.definition.toJson(), reason: t.key);
      }
    });
  });

  group('filling', () {
    final round = _builtIn('ward_round').definition;
    final today = round.sections.firstWhere((s) => s.id == 'today');

    test('All Normal fills expected answers and drops stale details', () {
      final a = markSectionNormal({'pain': kNo, 'pain.detail': 'crying'}, today);
      expect(a['pain'], kYes);
      expect(a.containsKey('pain.detail'), isFalse);
      expect(today.fields.every((f) => a[f.id] == kYes), isTrue);
    });

    test('abnormal answers need a description', () {
      final pain = round.fields.firstWhere((f) => f.id == 'pain');
      expect(pain.isAbnormal(kNo), isTrue);
      expect(pain.isAbnormal(kNa), isFalse);
      expect(missingDetails(round, {'pain': kNo}).map((f) => f.id), ['pain']);
      expect(missingDetails(round, {'pain': kNo, 'pain.detail': ' on PRN only '}), isEmpty);
    });

    test('copy from last time keeps answers, not vitals or dates', () {
      final carried = carryForward({
        'pain': kYes,
        'vitals': {'hr': 120},
        'plan': 'Continue',
      }, round);
      expect(carried, {'pain': kYes, 'plan': 'Continue'});
    });
  });

  group('summary', () {
    test('ward round: vitals, normal ticks, abnormal flagged, then plan', () {
      final s = summariseForm(
        formName: 'Ward round',
        author: 'Dr A',
        definition: _builtIn('ward_round').definition,
        answers: {
          'vitals': {'hr': 140, 'temp': 37.2, 'sbp': 90, 'dbp': 60, 'weight': 12.5},
          'afebrile': kYes,
          'feeding': kYes,
          'pain': kNo,
          'pain.detail': 'needs regular paracetamol',
          'wound': kNa,
          'plan': 'Continue IV antibiotics',
        },
      );
      expect(
        s.text,
        'Ward round — Dr A: HR 140, T 37.2 °C, BP 90/60, Wt 12.5 kg; afebrile, tolerating feeds / oral intake; '
        '⚠ not pain controlled — needs regular paracetamol. Plan: Continue IV antibiotics.',
      );
      expect(s.abnormal, ['not pain controlled — needs regular paracetamol']);
      expect(s.vitals['hr'], 140);
    });

    test('admission: history positives, normal systems grouped, abnormal systems flagged', () {
      final s = summariseForm(
        formName: 'Admission evaluation',
        definition: _builtIn('admission').definition,
        answers: {
          'recent_illness': kYes,
          'recent_illness.detail': 'cough for 3 days',
          'allergies': kNo,
          'cvs': 'Normal',
          'resp': 'Abnormal',
          'resp.detail': 'crackles right base',
          'abdomen': 'Normal',
          'fit': 'Pending tests',
          'fit.detail': 'awaiting Hb',
        },
      );
      expect(
        s.text,
        'Admission evaluation: normal: Heart and circulation, Abdomen; '
        '⚠ Fever, cough or cold in the last 2 weeks — cough for 3 days; ⚠ Chest: abnormal — crackles right base; '
        '⚠ Fit for planned treatment: pending tests — awaiting Hb.',
      );
      expect(s.abnormal, hasLength(3));
    });

    test('nothing answered still names the form', () {
      expect(
        summariseForm(formName: 'Nursing vitals', definition: _builtIn('nursing_vitals').definition, answers: {}).text,
        'Nursing vitals.',
      );
    });

    test('handover lists the abnormal answers of a recent form', () {
      final p = Patient(
        id: 'p',
        name: 'Child',
        age: 4,
        gender: 'Male',
        wardId: 'w',
        bedNumber: '2',
        diagnosis: '',
        admittedAt: DateTime(2026, 11, 3),
      );
      final form = PatientForm(
        id: 'f',
        patientId: 'p',
        templateKey: 'ward_round',
        templateName: 'Ward round',
        templateVersion: 1,
        definition: _builtIn('ward_round').definition,
        answers: const {'pain': kNo, 'pain.detail': 'on PRN only', 'afebrile': kYes},
        summary: '',
        abnormalCount: 1,
        createdAt: DateTime(2026, 11, 3, 9, 10),
      );
      final text = HandoverItem(
        patient: p,
        unitName: null,
        openReminders: const [],
        abnormalForm: form,
      ).toText(DateTime(2026, 11, 3, 20));
      expect(text, contains('⚠ Ward round 9:10 am: not pain controlled — on PRN only'));
    });
  });

  group('editor helpers', () {
    test('keys from names', () {
      expect(formKeyFrom('Daily NICU check!'), 'daily_nicu_check');
      expect(formKeyFrom('   '), 'form');
      expect(formKeyFrom('x' * 50).length, 30);
    });
  });

  testWidgets('fill screen: an abnormal tick asks for details; All Normal clears it', (tester) async {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(390 * 3, 6000 * 3);
    view.devicePixelRatio = 3;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);
    final p = Patient(
      id: 'p',
      name: 'Child',
      age: 4,
      gender: 'Male',
      wardId: 'w',
      bedNumber: '2',
      diagnosis: '',
      admittedAt: DateTime(2026, 11, 3),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppearanceProvider(),
        child: MaterialApp(
          home: FormFillScreen(patient: p, template: _builtIn('ward_round')),
        ),
      ),
    );
    expect(find.text('Details'), findsNothing);
    final painRow = find.ancestor(of: find.text('Pain controlled'), matching: find.byType(Column)).first;
    await tester.tap(find.descendant(of: painRow, matching: find.text('No')));
    await tester.pumpAndSettle();
    expect(find.text('Details'), findsOneWidget);
    await tester.tap(find.text('All Normal').first);
    await tester.pumpAndSettle();
    expect(find.text('Details'), findsNothing);
  });

  group('scores', () {
    FormSectionDef sec(String form, String id) => _builtIn(form).definition.sections.firstWhere((s) => s.id == id);

    test('every scored item has a point per option, bands ascend, totals match the published maxima', () {
      for (final t in kBuiltInForms) {
        for (final s in t.definition.sections) {
          for (final f in s.fields.where((f) => f.type == FieldType.score)) {
            expect(f.points.length, f.options.length, reason: '${t.key}.${f.id}');
            if (f.normal != null) expect(f.options, contains(f.normal));
          }
          final spec = s.score;
          if (spec == null) continue;
          final mins = spec.bands.map((b) => b.min).toList();
          expect(mins, [...mins]..sort(), reason: '${t.key}.${s.id}');
          expect(mins.first, 0);
        }
      }
      int max(FormSectionDef s) => s.fields.fold(0, (a, f) => a + f.maxPoints);
      expect(max(sec('nursing_admission', 'flacc')), 10);
      expect(max(sec('post_op', 'aldrete')), 10);
      expect(max(sec('nursing_admission', 'nutrition')), 5);
    });

    test('FLACC: totals and bands', () {
      final s = sec('post_op', 'flacc');
      Map<String, Object?> pick(List<int> idx) => {for (final (i, f) in s.fields.indexed) f.id: f.options[idx[i]]};
      expect(s.scoreFor({}), isNull);
      final partial = s.scoreFor({s.fields.first.id: s.fields.first.options[2]})!;
      expect((partial.total, partial.complete), (2, false));
      final mild = s.scoreFor(pick([1, 1, 0, 1, 0]))!;
      expect((mild.total, mild.band!.label, mild.band!.abnormal), (3, 'mild discomfort', false));
      final moderate = s.scoreFor(pick([2, 1, 1, 1, 1]))!;
      expect((moderate.line, moderate.band!.abnormal), ('FLACC 6/10 — moderate pain', true));
      expect(s.scoreFor(pick([2, 2, 2, 2, 2]))!.band!.label, 'severe pain');
    });

    test('All Normal on a score section gives the best answer (FLACC 0, Aldrete 10)', () {
      final flacc = sec('post_op', 'flacc');
      expect(flacc.scoreFor(markSectionNormal({}, flacc))!.total, 0);
      final aldrete = sec('post_op', 'aldrete');
      final a = aldrete.scoreFor(markSectionNormal({}, aldrete))!;
      expect((a.total, a.band!.label), (10, 'ready to leave recovery'));
    });

    test('Aldrete 8 is not ready; the summary flags it and skips the items themselves', () {
      final def = _builtIn('post_op').definition;
      final aldrete = sec('post_op', 'aldrete');
      final answers = markSectionNormal({}, aldrete)
        ..[aldrete.fields[1].id] = aldrete.fields[1].options[1]
        ..[aldrete.fields[4].id] = aldrete.fields[4].options[1];
      final s = summariseForm(formName: 'Post-op', definition: def, answers: answers);
      expect(s.abnormal, ['Aldrete 8/10 — not ready to leave recovery']);
      expect(s.text, 'Post-op: ⚠ Aldrete 8/10 — not ready to leave recovery.');
    });

    test('scores are not copied from last time', () {
      final def = _builtIn('nursing_admission').definition;
      final flacc = sec('nursing_admission', 'flacc');
      final prev = markSectionNormal({'id_band': kYes}, flacc);
      expect(carryForward(prev, def), {'id_band': kYes});
    });

    test('STRONGkids: 4 or more is high risk', () {
      final s = sec('nursing_admission', 'nutrition');
      final a = {for (final f in s.fields) f.id: 'Yes'};
      expect(s.scoreFor(a)!.line, 'STRONGkids 5/5 — high risk — dietitian review');
      expect(s.scoreFor({for (final f in s.fields) f.id: 'No'})!.band!.label, 'low risk');
    });
  });

  group('new and extended forms', () {
    test('surgical safety checklist has the three WHO phases', () {
      expect(_builtIn('surgical_safety').definition.sections.map((s) => s.id), ['sign_in', 'time_out', 'sign_out']);
    });

    test('admission links allergies and medicines to the record', () {
      final f = _builtIn('admission').definition.fields;
      expect(f.firstWhere((x) => x.id == 'allergies').link, kLinkAllergy);
      expect(f.firstWhere((x) => x.id == 'medicines').link, kLinkDrugHistory);
      expect(FormFieldDef.fromJson(f.firstWhere((x) => x.id == 'allergies').toJson()).link, kLinkAllergy);
    });

    test('ward round asks the review questions', () {
      final ids = _builtIn('ward_round').definition.fields.map((f) => f.id);
      expect(ids, containsAll(['lines_needed', 'antibiotics', 'antibiotic_day', 'family', 'chase', 'discharge_date']));
    });
  });

  group('admission forms within 24 h', () {
    final admitted = DateTime(2026, 11, 3, 8);
    Patient p() => Patient(
      id: 'p',
      name: 'Child',
      age: 4,
      gender: 'Male',
      wardId: 'w',
      bedNumber: '2',
      diagnosis: '',
      admittedAt: admitted,
    );

    test('due until 24 h, then overdue; filled or discharged means nothing due', () {
      final due = admissionFormsDue(p(), {'admission'});
      expect(due.map((d) => d.name), ['Nursing admission']);
      expect(due.single.isOverdueAt(admitted.add(const Duration(hours: 23))), isFalse);
      expect(due.single.isOverdueAt(admitted.add(const Duration(hours: 25))), isTrue);
      expect(admissionFormsDue(p(), {'admission', 'nursing_admission'}), isEmpty);
    });

    test('handover lists overdue admission forms first, only when loaded', () {
      final now = admitted.add(const Duration(hours: 30));
      final item = HandoverItem(patient: p(), unitName: null, openReminders: const [], filledFormKeys: const {});
      expect(item.actions(now).take(2), [
        'OVERDUE: Admission evaluation not done',
        'OVERDUE: Nursing admission not done',
      ]);
      expect(HandoverItem(patient: p(), unitName: null, openReminders: const []).actions(now), isEmpty);
    });
  });
}
