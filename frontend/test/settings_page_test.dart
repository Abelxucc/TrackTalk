import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracktalk/settings/settings_page.dart';

Future<void> _tap(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Account shows the sign-in email and opens password reset', (
    tester,
  ) async {
    const signInEmail = 'alex@example.com';
    await tester.pumpWidget(
      const MaterialApp(home: SettingsPage(email: signInEmail)),
    );

    expect(find.text('Reminders'), findsNothing);
    expect(find.text('Sign-in email'), findsOneWidget);
    expect(find.text(signInEmail), findsOneWidget);

    await _tap(tester, const Key('settings-reset-password'));
    final email = tester.widget<TextFormField>(
      find.byKey(const Key('reset-email')),
    );
    expect(email.controller!.text, signInEmail);
    expect(find.text('Back to Settings'), findsOneWidget);

    await _tap(tester, const Key('page-back'));
    expect(find.text('Account'), findsOneWidget);
  });
}
