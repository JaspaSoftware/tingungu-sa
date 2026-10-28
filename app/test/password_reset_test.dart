import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tingungu_app/screens/login_screen.dart';

void main() {
  testWidgets('sends a reset request and reports that an email was sent', (
    tester,
  ) async {
    final response = Completer<void>();
    final submittedEmails = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(
          initialEmail: ' member@example.test ',
          passwordReset: (email) {
            submittedEmails.add(email);
            return response.future;
          },
        ),
      ),
    );

    await _openPasswordReset(tester);
    await tester.tap(find.text('Send Reset Link'));
    await tester.pumpAndSettle();

    expect(submittedEmails, ['member@example.test']);
    expect(find.text('Reset Password'), findsNothing);

    response.complete();
    await tester.pumpAndSettle();

    expect(
      find.text('Password reset email sent! Check your inbox.'),
      findsOneWidget,
    );
    expect(find.textContaining('password has been changed'), findsNothing);
  });

  testWidgets('rejects empty and invalid emails before making a request', (
    tester,
  ) async {
    var requestCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(
          passwordReset: (_) async {
            requestCount++;
          },
        ),
      ),
    );

    await _openPasswordReset(tester);
    await tester.tap(find.text('Send Reset Link'));
    await tester.pumpAndSettle();
    expect(find.text('Please enter a valid email address'), findsOneWidget);
    expect(requestCount, 0);

    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'not-an-email',
    );
    await tester.tap(find.text('Send Reset Link'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter a valid email address'), findsOneWidget);
    expect(requestCount, 0);
    expect(find.text('Reset Password'), findsOneWidget);
  });

  testWidgets('maps network failures and allows a subsequent retry', (
    tester,
  ) async {
    var requestCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(
          initialEmail: 'member@example.test',
          passwordReset: (_) async {
            requestCount++;
            if (requestCount == 1) {
              throw FirebaseAuthException(
                code: 'network-request-failed',
                message: 'raw reset provider details',
              );
            }
          },
        ),
      ),
    );

    await _openPasswordReset(tester);
    await tester.tap(find.text('Send Reset Link'));
    await tester.pumpAndSettle();

    expect(
      find.text('Check your internet connection and try again.'),
      findsOneWidget,
    );
    expect(find.text('raw reset provider details'), findsNothing);

    await _openPasswordReset(tester);
    await tester.tap(find.text('Send Reset Link'));
    await tester.pumpAndSettle();

    expect(requestCount, 2);
    expect(
      find.text('Password reset email sent! Check your inbox.'),
      findsOneWidget,
    );
  });

  testWidgets('unknown reset errors use a safe fallback', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(
          initialEmail: 'member@example.test',
          passwordReset: (_) =>
              Future<void>.error(StateError('private reset provider details')),
        ),
      ),
    );

    await _openPasswordReset(tester);
    await tester.tap(find.text('Send Reset Link'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        "We couldn't send the password reset email. Please try again later.",
      ),
      findsOneWidget,
    );
    expect(find.text('private reset provider details'), findsNothing);
  });

  testWidgets('late reset failure after disposal does not update UI', (
    tester,
  ) async {
    final response = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(
          initialEmail: 'member@example.test',
          passwordReset: (_) => response.future,
        ),
      ),
    );

    await _openPasswordReset(tester);
    await tester.tap(find.text('Send Reset Link'));
    await tester.pump();

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('Different screen'))),
    );
    response.completeError(StateError('private reset failure'));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Different screen'), findsOneWidget);
    expect(find.textContaining('private reset failure'), findsNothing);
  });
}

Future<void> _openPasswordReset(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Forgot Password?'));
  await tester.tap(find.text('Forgot Password?'));
  await tester.pumpAndSettle();
}
