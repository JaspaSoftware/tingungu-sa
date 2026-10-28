import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:tingungu_app/screens/login_screen.dart';
import 'package:tingungu_app/screens/register_screen.dart';
import 'package:tingungu_app/services/account_profile_provisioner.dart';

void main() {
  testWidgets('invalid login input does not call authentication', (
    tester,
  ) async {
    var signInCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(
          emailSignIn: (_, _) async {
            signInCalls++;
            return true;
          },
        ),
      ),
    );

    await tester.enterText(find.byType(TextFormField).at(0), 'not-an-email');
    await tester.enterText(find.byType(TextFormField).at(1), '');
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    expect(signInCalls, 0);
    expect(find.text('Please enter a valid email address'), findsOneWidget);
    expect(find.text('Signing in...'), findsNothing);
  });

  testWidgets('shows mapped login errors and clears loading while mounted', (
    tester,
  ) async {
    final response = Completer<bool>();
    await tester.pumpWidget(
      MaterialApp(home: LoginScreen(emailSignIn: (_, _) => response.future)),
    );

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'member@example.test',
    );
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'not-the-password',
    );
    await tester.tap(find.text('Sign In'));
    await tester.pump();

    expect(find.text('Signing in...'), findsOneWidget);

    response.completeError(FirebaseAuthException(code: 'invalid-credential'));
    await tester.pumpAndSettle();

    expect(find.text('Invalid email or password.'), findsOneWidget);
    expect(find.text('Signing in...'), findsNothing);
    expect(
      tester
          .widget<ElevatedButton>(
            find.ancestor(
              of: find.text('Sign In'),
              matching: find.byType(ElevatedButton),
            ),
          )
          .onPressed,
      isNotNull,
    );
  });

  for (final (label, error, expectedMessage) in [
    (
      'network failure',
      FirebaseAuthException(code: 'network-request-failed'),
      'Check your internet connection and try again.',
    ),
    (
      'unexpected failure',
      StateError('sensitive provider detail'),
      "We couldn't sign you in. Please try again later.",
    ),
  ]) {
    testWidgets('$label displays only a safe message', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(emailSignIn: (_, _) => Future<bool>.error(error)),
        ),
      );

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'member@example.test',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'not-the-password',
      );
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(find.text(expectedMessage), findsOneWidget);
      expect(find.text('sensitive provider detail'), findsNothing);
      expect(find.text('Signing in...'), findsNothing);
    });
  }

  testWidgets('Google cancellation is quiet and clears loading', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: LoginScreen(googleSignIn: () async => null)),
    );

    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();

    expect(find.text('Signing in...'), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('Google failures show safe translated messages', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(
          googleSignIn: () => Future<RegistrationAccount?>.error(
            PlatformException(
              code: GoogleSignIn.kNetworkError,
              message: 'sensitive provider detail',
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();

    expect(
      find.text('Check your internet connection and try again.'),
      findsOneWidget,
    );
    expect(find.text('sensitive provider detail'), findsNothing);
    expect(find.text('Signing in...'), findsNothing);
  });

  testWidgets('Google credential failures show safe guidance', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(
          googleSignIn: () => Future<RegistrationAccount?>.error(
            PlatformException(
              code: GoogleSignIn.kSignInFailedError,
              message: 'raw Google credential detail',
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();

    expect(
      find.text('Google sign-in could not be completed. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('raw Google credential detail'), findsNothing);
    expect(find.text('Signing in...'), findsNothing);
  });

  testWidgets('unexpected Google failures use the safe fallback', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(
          googleSignIn: () => Future<RegistrationAccount?>.error(
            StateError('private provider response'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();

    expect(
      find.text("We couldn't sign you in. Please try again later."),
      findsOneWidget,
    );
    expect(find.text('private provider response'), findsNothing);
    expect(find.text('Signing in...'), findsNothing);
  });

  testWidgets('successful email login retains its success feedback', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: LoginScreen(emailSignIn: (_, _) async => true)),
    );

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'member@example.test',
    );
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'correct-password',
    );
    await tester.tap(find.text('Sign In'));
    await tester.pump();

    expect(find.text('✅ Login successful!'), findsOneWidget);
    expect(find.text('Signing in...'), findsNothing);
    expect(
      find.text("We couldn't sign you in. Please try again later."),
      findsNothing,
    );
  });

  for (final (label, error) in [
    (
      'Firebase authentication error',
      FirebaseAuthException(code: 'wrong-password'),
    ),
    ('unexpected authentication error', StateError('authentication failed')),
  ]) {
    testWidgets('$label after disposal does not update the widget', (
      tester,
    ) async {
      final response = Completer<bool>();
      await tester.pumpWidget(
        MaterialApp(home: LoginScreen(emailSignIn: (_, _) => response.future)),
      );

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'member@example.test',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'not-the-password',
      );
      await tester.tap(find.text('Sign In'));
      await tester.pump();
      expect(find.text('Signing in...'), findsOneWidget);

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('Different screen'))),
      );
      response.completeError(error);
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Different screen'), findsOneWidget);
      expect(find.text('Invalid email or password.'), findsNothing);
      expect(find.textContaining('authentication failed'), findsNothing);
    });
  }

  testWidgets(
    'successful login response after disposal performs no UI update',
    (tester) async {
      final response = Completer<bool>();
      await tester.pumpWidget(
        MaterialApp(home: LoginScreen(emailSignIn: (_, _) => response.future)),
      );

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'member@example.test',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'correct-password',
      );
      await tester.tap(find.text('Sign In'));
      await tester.pump();

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('Different screen'))),
      );
      response.complete(true);
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Different screen'), findsOneWidget);
      expect(find.text('✅ Login successful!'), findsNothing);
    },
  );

  testWidgets('Google success clears loading without displaying an error', (
    tester,
  ) async {
    final response = Completer<RegistrationAccount?>();
    final profileStore = _FakeUserProfileStore();
    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(
          googleSignIn: () => response.future,
          profileProvisioner: AccountProfileProvisioner(store: profileStore),
        ),
      ),
    );

    await tester.tap(find.text('Continue with Google'));
    await tester.pump();
    expect(find.text('Signing in...'), findsOneWidget);

    response.complete(
      const RegistrationAccount(
        uid: 'google-login-uid',
        email: 'google@example.test',
        displayName: 'Google Member',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Signing in...'), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
    expect(profileStore.createdUids, ['google-login-uid']);
    expect(profileStore.profiles['google-login-uid'], {
      'displayname': 'Google Member',
      'email': 'google@example.test',
      'cellnumber': '',
      'avatar': '',
      'society': '',
      'dob': '',
      'profile_completed': false,
    });
  });

  testWidgets('late Google failure after disposal does not update UI', (
    tester,
  ) async {
    final response = Completer<RegistrationAccount?>();
    await tester.pumpWidget(
      MaterialApp(home: LoginScreen(googleSignIn: () => response.future)),
    );

    await tester.tap(find.text('Continue with Google'));
    await tester.pump();
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('Different screen'))),
    );

    response.completeError(StateError('private Google error'));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Different screen'), findsOneWidget);
    expect(find.textContaining('private Google error'), findsNothing);
  });

  testWidgets('late Google success after disposal performs no UI update', (
    tester,
  ) async {
    final response = Completer<RegistrationAccount?>();
    await tester.pumpWidget(
      MaterialApp(home: LoginScreen(googleSignIn: () => response.future)),
    );

    await tester.tap(find.text('Continue with Google'));
    await tester.pump();
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('Different screen'))),
    );

    response.complete(const RegistrationAccount(uid: 'late-google-user'));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Different screen'), findsOneWidget);
    expect(find.text('Google sign-in could not be completed'), findsNothing);
  });
}

class _FakeUserProfileStore implements UserProfileStore {
  final Map<String, Map<String, dynamic>> profiles = {};
  final List<String> createdUids = [];

  @override
  Future<Map<String, dynamic>?> readProfile(String uid) async {
    final profile = profiles[uid];
    return profile == null ? null : Map<String, dynamic>.from(profile);
  }

  @override
  Future<void> createProfileIfAbsent(
    String uid,
    Map<String, dynamic> profile,
  ) async {
    createdUids.add(uid);
    profiles.putIfAbsent(uid, () => Map<String, dynamic>.from(profile));
  }
}
