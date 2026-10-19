import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foliomed/utils/app_theme.dart';
import 'package:foliomed/widgets/app_alert_dialog.dart';

Widget _dialog({VoidCallback? onDelete}) => AppAlertDialog(
      title: const Text('Delete ward?'),
      content: const TextField(decoration: InputDecoration(hintText: 'Type to confirm')),
      actions: [
        TextButton(onPressed: () {}, child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: onDelete,
          child: const Text('Delete', style: TextStyle(color: Colors.white)),
        ),
        ElevatedButton(onPressed: () {}, child: const Text('Save')),
      ],
    );

void main() {
  tearDown(() => AppAlertDialog.useCupertino = () => false);

  group('on Apple platforms', () {
    setUp(() => AppAlertDialog.useCupertino = () => true);

    testWidgets('renders a native alert with a working text field',
        (tester) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: _dialog())));
      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      await tester.enterText(find.byType(TextField), 'DELETE');
      expect(find.text('DELETE'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('maps button roles to Cupertino actions', (tester) async {
      await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: _dialog(onDelete: () {}))));
      final actions = tester
          .widgetList<CupertinoDialogAction>(find.byType(CupertinoDialogAction))
          .toList();
      expect(actions, hasLength(3));
      expect(actions[0].isDefaultAction, isFalse, reason: 'Cancel is plain');
      expect(actions[1].isDestructiveAction, isTrue, reason: 'red → destructive');
      expect(actions[1].isDefaultAction, isFalse);
      expect(actions[2].isDefaultAction, isTrue, reason: 'filled → default');
    });

    testWidgets('a disabled button stays disabled', (tester) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: _dialog())));
      final delete = tester
          .widgetList<CupertinoDialogAction>(find.byType(CupertinoDialogAction))
          .elementAt(1);
      expect(delete.onPressed, isNull);
    });

    testWidgets('hard-coded label colours are removed', (tester) async {
      await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: _dialog(onDelete: () {}))));
      final label = tester.widget<Text>(find.text('Delete'));
      expect(label.style?.color, isNull);
    });
  });

  testWidgets('elsewhere it stays a Material AlertDialog', (tester) async {
    AppAlertDialog.useCupertino = () => false;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: _dialog())));
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byType(CupertinoAlertDialog), findsNothing);
  });

  testWidgets('Material: destructive is red text, not a red fill',
      (tester) async {
    AppAlertDialog.useCupertino = () => false;
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: _dialog(onDelete: () {}))));
    final delete = tester.widget<ButtonStyleButton>(find.ancestor(
        of: find.text('Delete'), matching: find.byWidgetPredicate((w) => w is ButtonStyleButton)));
    expect(delete, isA<TextButton>());
    expect(delete.style!.foregroundColor!.resolve({}), AppColors.danger);
    final save = find.ancestor(
        of: find.text('Save'), matching: find.byType(ElevatedButton));
    expect(save, findsOneWidget, reason: 'non-destructive filled stays filled');
  });
}
