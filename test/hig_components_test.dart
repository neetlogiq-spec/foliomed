import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foliomed/models/note.dart';
import 'package:foliomed/models/patient.dart';
import 'package:foliomed/providers/theme_provider.dart';
import 'package:foliomed/services/accessibility_settings.dart';
import 'package:foliomed/widgets/large_title_app_bar.dart';
import 'package:foliomed/widgets/note_card.dart';
import 'package:foliomed/widgets/patient_card.dart';
import 'package:provider/provider.dart';

Note _note({bool acknowledged = false, String content = 'BP 120/80'}) => Note(
      id: 'n1',
      patientId: 'p1',
      patientName: 'Asha Rao',
      wardId: '12345',
      authorId: 'u1',
      authorName: 'Dr Kashyap Anand',
      authorRole: 'doctor',
      content: content,
      category: 'Observation',
      priority: 'Urgent',
      isAcknowledged: acknowledged,
      acknowledgedBy: acknowledged ? 'Nurse Priya' : null,
      acknowledgedAt: acknowledged ? DateTime.now() : null,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

Widget _app(Widget child, {double textScale = 1}) =>
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(390, 844),
            textScaler: TextScaler.linear(textScale),
          ),
          child: Scaffold(body: child),
        ),
      ),
    );

Widget _largeTitlePage({int badge = 0}) => CustomScrollView(
      slivers: [
        LargeTitleAppBar(
          eyebrow: 'Good morning',
          title: 'Dr Kashyap',
          actions: [
            ChromeIconButton(
              icon: Icons.notifications_outlined,
              tooltip: 'Notifications',
              badgeCount: badge,
              onPressed: () {},
            ),
          ],
        ),
        SliverList.list(children: [
          for (var i = 0; i < 40; i++) SizedBox(height: 50, child: Text('row $i')),
        ]),
      ],
    );

double _opacityOf(WidgetTester tester, Finder text) =>
    tester.widget<Opacity>(find.ancestor(of: text, matching: find.byType(Opacity)).first).opacity;

void main() {
  tearDown(() => AccessibilitySettings.reduceTransparency.value = false);

  group('LargeTitleAppBar', () {
    testWidgets('shows the large title expanded, folds it on scroll',
        (tester) async {
      await tester.pumpWidget(_app(_largeTitlePage()));
      // Two "Dr Kashyap" texts: large (visible) and small (hidden).
      final titles = find.text('Dr Kashyap');
      expect(titles, findsNWidgets(2));
      expect(_opacityOf(tester, titles.first), 0, reason: 'small title hidden');
      expect(_opacityOf(tester, titles.last), 1, reason: 'large title shown');

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(_opacityOf(tester, find.text('Dr Kashyap').first), 1,
          reason: 'small title appears once collapsed');
      expect(_opacityOf(tester, find.text('Dr Kashyap').last), 0);
    });

    testWidgets('Reduce Transparency removes the blur', (tester) async {
      await tester.pumpWidget(_app(_largeTitlePage()));
      expect(find.byType(BackdropFilter), findsOneWidget);
      AccessibilitySettings.reduceTransparency.value = true;
      await tester.pump();
      expect(find.byType(BackdropFilter), findsNothing);
    });

    testWidgets('header actions have 44pt touch targets and labels',
        (tester) async {
      await tester.pumpWidget(_app(_largeTitlePage(badge: 3)));
      final size = tester.getSize(find.byType(ChromeIconButton));
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));
      expect(find.bySemanticsLabel('Notifications, 3 new'), findsOneWidget);
    });

    testWidgets('fits at 2x text size without overflow', (tester) async {
      await tester.pumpWidget(_app(_largeTitlePage(), textScale: 2));
      expect(tester.takeException(), isNull);
    });
  });

  test('greeting follows the time of day', () {
    expect(timeOfDayGreeting(DateTime(2026, 1, 1, 8)), 'Good morning');
    expect(timeOfDayGreeting(DateTime(2026, 1, 1, 14)), 'Good afternoon');
    expect(timeOfDayGreeting(DateTime(2026, 1, 1, 21)), 'Good evening');
  });

  group('NoteCard', () {
    testWidgets('acknowledged notes get a checkmark, not a dimmed card',
        (tester) async {
      await tester.pumpWidget(_app(NoteCard(note: _note(acknowledged: true))));
      expect(find.bySemanticsLabel(RegExp('Acknowledged')), findsOneWidget);
      final dims = tester
          .widgetList<Opacity>(find.descendant(
              of: find.byType(NoteCard), matching: find.byType(Opacity)))
          .where((o) => o.opacity < 1 && o.opacity > 0);
      expect(dims, isEmpty, reason: 'no blanket opacity on the card');
    });

    testWidgets('priority is announced via the edge indicator',
        (tester) async {
      await tester.pumpWidget(_app(NoteCard(note: _note())));
      expect(find.bySemanticsLabel(RegExp('Urgent priority')), findsOneWidget);
    });

    testWidgets('long notes expand and collapse', (tester) async {
      await tester.pumpWidget(_app(SingleChildScrollView(
          child: NoteCard(note: _note(content: 'x ' * 200)))));
      expect(find.text('Show more'), findsOneWidget);
      await tester.tap(find.text('Show more'));
      await tester.pumpAndSettle();
      expect(find.text('Show less'), findsOneWidget);
    });

    testWidgets('renders at 2x text size without overflow', (tester) async {
      await tester.pumpWidget(_app(
        SingleChildScrollView(child: NoteCard(note: _note(acknowledged: true))),
        textScale: 2,
      ));
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('PatientCard status chip is announced and fits 2x text',
      (tester) async {
    final patient = Patient(
      id: 'p1',
      name: 'Asha Rao',
      age: 34,
      gender: 'F',
      wardId: '12345',
      bedNumber: '12',
      diagnosis: 'Pneumonia',
      admittedAt: DateTime(2026, 10, 1),
    );
    await tester.pumpWidget(_app(PatientCard(patient: patient), textScale: 2));
    expect(find.bySemanticsLabel(RegExp('Status: Active')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('staggered entrance only runs when asked', (tester) async {
    await tester.pumpWidget(_app(Builder(
      builder: (context) => Column(children: [
        staggeredEntrance(context,
            index: 0, animate: false, child: const Text('plain')),
        staggeredEntrance(context,
            index: 9, animate: true, child: const Text('past cap')),
      ]),
    )));
    // Neither is wrapped: one is disabled, the other is past the 8-item cap.
    expect(find.text('plain'), findsOneWidget);
    expect(find.text('past cap'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
