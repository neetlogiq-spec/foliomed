import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foliomed/widgets/birth_time_field.dart';

Widget _host(DateTime? bornAt) => MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: BirthTimeField(bornAt: bornAt, onChanged: (_) {}),
        ),
      ),
    );

void main() {
  testWidgets('empty: label and hint do not overlap, no overflow', (tester) async {
    tester.view.physicalSize = const Size(360, 200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_host(null));
    expect(tester.takeException(), isNull);
    final label = tester.getRect(find.text('Birth date & time'));
    final hint = find.text('Tap to set');
    if (hint.evaluate().isNotEmpty) {
      expect(label.overlaps(tester.getRect(hint)), isFalse);
    }
  });

  testWidgets('set: value and hours-of-life helper are on separate lines', (tester) async {
    tester.view.physicalSize = const Size(320, 200); // narrow phone
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final born = DateTime.now().subtract(const Duration(hours: 30));
    await tester.pumpWidget(_host(born));
    expect(tester.takeException(), isNull);
    final helper = tester.getRect(find.textContaining('h old'));
    final label = tester.getRect(find.text('Birth date & time'));
    final field = tester.getRect(find.byType(EditableText));
    expect(field.overlaps(label), isFalse);
    expect(helper.top, greaterThanOrEqualTo(field.bottom));
  });

  testWidgets('empty state renders', (tester) async {
    tester.view.physicalSize = const Size(320, 200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_host(null));
    final label = tester.getRect(find.text('Birth date & time'));
    final hint = tester.getRect(find.text('Tap to set'));
    expect(hint.top, greaterThanOrEqualTo(label.bottom),
        reason: 'label floats above the hint, never on top of it');
  });
}
