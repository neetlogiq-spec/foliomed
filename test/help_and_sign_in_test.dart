import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foliomed/models/app_user.dart';
import 'package:foliomed/providers/account_provider.dart';
import 'package:foliomed/providers/appearance_provider.dart';
import 'package:foliomed/screens/help/help_center_screen.dart';
import 'package:foliomed/screens/start/sign_in_screen.dart';
import 'package:provider/provider.dart';

class _FakeAccount extends ChangeNotifier implements AccountProvider {
  @override
  AppUser? get currentUser => null;
  @override
  bool get isLoading => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _app(Widget child) => MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppearanceProvider()),
        ChangeNotifierProvider<AccountProvider>.value(value: _FakeAccount()),
      ],
      child: MaterialApp(home: child),
    );

void main() {
  setUp(() {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(390 * 3, 2400 * 3);
    view.devicePixelRatio = 3;
  });
  tearDown(() => TestWidgetsFlutterBinding.instance.platformDispatcher.views.first
    ..resetPhysicalSize()
    ..resetDevicePixelRatio());

  testWidgets('Help: popular questions expand in place; topics are tiles; search finds answers', (tester) async {
    await tester.pumpWidget(_app(const HelpCenterScreen()));
    expect(find.text('What is the job list?'), findsOneWidget);
    expect(find.textContaining('The day’s tasks for each patient'), findsNothing);
    await tester.tap(find.text('What is the job list?'));
    await tester.pumpAndSettle();
    expect(find.textContaining('The day’s tasks for each patient'), findsOneWidget);

    expect(find.text('Newborns'), findsOneWidget);
    expect(find.text('Account and privacy'), findsOneWidget);

    await tester.enterText(find.byType(CupertinoSearchTextField), 'phototherapy');
    await tester.pump();
    expect(find.textContaining(RegExp('answer', caseSensitive: false)), findsWidgets);
    expect(find.text('Newborns'), findsWidgets); // section shown under the result
  });

  testWidgets('Sign in: reassurances, and Google always offered', (tester) async {
    await tester.pumpWidget(_app(const SignInScreen()));
    expect(find.text('FolioMed'), findsOneWidget);
    expect(find.text('No new password'), findsOneWidget);
    expect(find.text('Only your wards'), findsOneWidget);
    expect(find.text('Sign in with Google'), findsOneWidget);
    expect(find.text('Continue with Apple'), findsNothing); // test host is not iOS
    expect(tester.takeException(), isNull);
  });
}
