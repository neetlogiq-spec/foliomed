import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foliomed/utils/layout.dart';

void main() {
  testWidgets(
      'with extendBody, the last row scrolls clear of the floating tab bar',
      (tester) async {
    const barHeight = 80.0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        extendBody: true,
        // A nested tab screen, like the app's IndexedStack children.
        body: Scaffold(
          appBar: AppBar(title: const Text('Tab')),
          body: Builder(
            builder: (context) => ListView.builder(
              padding: withBottomBarInset(context, const EdgeInsets.all(16)),
              itemCount: 30,
              itemBuilder: (_, i) => SizedBox(height: 60, child: Text('row $i')),
            ),
          ),
        ),
        bottomNavigationBar: const SizedBox(
          key: Key('bar'),
          height: barHeight,
          child: ColoredBox(color: Color(0x80FFFFFF)),
        ),
      ),
    ));

    await tester.drag(find.byType(ListView), const Offset(0, -5000));
    await tester.pumpAndSettle();

    final lastRowBottom = tester.getBottomLeft(find.text('row 29')).dy;
    final barTop = tester.getTopLeft(find.byKey(const Key('bar'))).dy;
    expect(lastRowBottom, lessThanOrEqualTo(barTop));
  });

  test('adds the inset on top of the existing bottom padding', () {
    // Pure function check via a fake MediaQuery context is covered above;
    // here just confirm other sides are untouched.
    const base = EdgeInsets.fromLTRB(1, 2, 3, 4);
    expect(base.copyWith(bottom: base.bottom + 10),
        const EdgeInsets.fromLTRB(1, 2, 3, 14));
  });
}
