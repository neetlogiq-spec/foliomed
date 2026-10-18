import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foliomed/widgets/app_sheet.dart';

void main() {
  test('projection follows Apple’s decay formula', () {
    expect(projectSheetOffset(0), 0);
    expect(projectSheetOffset(1000), closeTo(499, 1));
    expect(projectSheetOffset(-1000), closeTo(-499, 1));
  });

  test('rubber band resists progressively', () {
    final small = rubberBand(20, 400);
    final big = rubberBand(200, 400);
    expect(small, lessThan(20));
    expect(big, lessThan(200));
    expect(big / 200, lessThan(small / 20));
  });

  Future<void> openSheet(WidgetTester tester, Widget content) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showAppSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => content,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  const plain = SizedBox(
    height: 400,
    child: Center(child: Text('sheet body')),
  );

  testWidgets('opens and shows content', (tester) async {
    await openSheet(tester, plain);
    expect(find.text('sheet body'), findsOneWidget);
  });

  testWidgets('a short slow drag springs back open', (tester) async {
    await openSheet(tester, plain);
    final before = tester.getTopLeft(find.text('sheet body')).dy;
    await tester.timedDrag(
        find.text('sheet body'), const Offset(0, 60), const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('sheet body'), findsOneWidget);
    expect(tester.getTopLeft(find.text('sheet body')).dy, closeTo(before, 1));
  });

  testWidgets('dragging past halfway dismisses', (tester) async {
    await openSheet(tester, plain);
    await tester.timedDrag(
        find.text('sheet body'), const Offset(0, 300), const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('sheet body'), findsNothing);
  });

  testWidgets('a quick flick dismisses even from a short distance',
      (tester) async {
    await openSheet(tester, plain);
    await tester.fling(find.text('sheet body'), const Offset(0, 80), 2500);
    await tester.pumpAndSettle();
    expect(find.text('sheet body'), findsNothing);
  });

  testWidgets('pulling an upward drag rubber-bands and settles back',
      (tester) async {
    await openSheet(tester, plain);
    final before = tester.getTopLeft(find.text('sheet body')).dy;
    final gesture =
        await tester.startGesture(tester.getCenter(find.text('sheet body')));
    await gesture.moveBy(const Offset(0, -20));
    await gesture.moveBy(const Offset(0, -150));
    await tester.pump();
    final stretched = tester.getTopLeft(find.text('sheet body')).dy;
    expect(stretched, lessThan(before));
    expect(before - stretched, lessThan(150), reason: 'resists, not 1:1');
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('sheet body')).dy, closeTo(before, 1));
  });

  testWidgets('a list at its top hands the pull to the sheet', (tester) async {
    await openSheet(
      tester,
      SizedBox(
        height: 500,
        child: ListView.builder(
          itemCount: 50,
          itemBuilder: (_, i) => SizedBox(height: 50, child: Text('row $i')),
        ),
      ),
    );
    expect(find.text('row 0'), findsOneWidget);
    await tester.timedDrag(
        find.text('row 2'), const Offset(0, 400), const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('row 0'), findsNothing, reason: 'sheet dismissed');
  });

  testWidgets('a scrolled list scrolls back first instead of dismissing',
      (tester) async {
    await openSheet(
      tester,
      SizedBox(
        height: 500,
        child: ListView.builder(
          itemCount: 50,
          itemBuilder: (_, i) => SizedBox(height: 50, child: Text('row $i')),
        ),
      ),
    );
    await tester.drag(find.text('row 5'), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(find.text('row 0'), findsNothing);
    await tester.timedDrag(
        find.text('row 15'), const Offset(0, 200), const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.byType(ListView), findsOneWidget, reason: 'still open');
  });

  testWidgets('DraggableScrollableSheet content: resizes, then dismisses',
      (tester) async {
    await openSheet(
      tester,
      DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, controller) => ListView.builder(
          controller: controller,
          itemCount: 50,
          itemBuilder: (_, i) => SizedBox(height: 50, child: Text('item $i')),
        ),
      ),
    );
    expect(find.text('item 0'), findsOneWidget);
    // Long pull: shrinks to min size, then the remainder moves the sheet.
    await tester.timedDrag(
        find.text('item 1'), const Offset(0, 550), const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('item 0'), findsNothing, reason: 'sheet dismissed');
  });
}
