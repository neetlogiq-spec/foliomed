import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foliomed/models/app_user.dart';
import 'package:foliomed/providers/account_provider.dart';
import 'package:foliomed/providers/appearance_provider.dart';
import 'package:foliomed/screens/tools/score_tool.dart';
import 'package:foliomed/tools/newborn_scores.dart';
import 'package:provider/provider.dart';

class _FakeAccount extends ChangeNotifier implements AccountProvider {
  _FakeAccount(this.currentUser);
  @override
  final AppUser? currentUser;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(390 * 3, 3200 * 3);
    view.devicePixelRatio = 3;
  });
  tearDown(() => TestWidgetsFlutterBinding.instance.platformDispatcher.views.first
    ..resetPhysicalSize()
    ..resetDevicePixelRatio());

  testWidgets('Downes: answer every item → total, band, copy and note buttons', (tester) async {
    final doctor = AppUser(uid: 'u', name: 'Dr A', email: 'a@x.com', role: UserRole.doctor, createdAt: DateTime(2026));
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppearanceProvider()),
        ChangeNotifierProvider<AccountProvider>.value(value: _FakeAccount(doctor)),
      ],
      child: const MaterialApp(home: ScoreTool(definition: downes)),
    ));
    expect(find.text('0 of 5 answered'), findsOneWidget);
    expect(find.text('Copy'), findsNothing);

    await tester.tap(find.text('60–80/min'));
    await tester.tap(find.text('Mild'));
    await tester.tap(find.text('In room air, settles with oxygen'));
    await tester.tap(find.text('Reduced'));
    await tester.pump();
    expect(find.text('4 of 5 answered'), findsOneWidget);
    await tester.tap(find.text('Heard with a stethoscope'));
    await tester.pump();

    expect(find.text('5'), findsWidgets);
    expect(find.text('Moderate respiratory distress'), findsOneWidget);
    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('Add as Note'), findsOneWidget);
  });
}
