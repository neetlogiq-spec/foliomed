import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foliomed/clinical/handover.dart';
import 'package:foliomed/forms/builtin_forms.dart';
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
    await tester.tap(find.text('All Normal'));
    await tester.pumpAndSettle();
    expect(find.text('Details'), findsNothing);
  });
}
