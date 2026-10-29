import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tingungu_app/screens/register_screen.dart';
import 'package:tingungu_app/services/account_profile_provisioner.dart';

void main() {
  testWidgets('registers email account and provisions the returned UID', (
    tester,
  ) async {
    final store = _FakeUserProfileStore();
    final provisioner = AccountProfileProvisioner(store: store);
    final createdCredentials = <(String, String)>[];

    await tester.pumpWidget(
      MaterialApp(
        home: RegisterScreen(
          createEmailAccount: (email, password) async {
            createdCredentials.add((email, password));
            return const RegistrationAccount(
              uid: 'auth-user-123',
              email: 'member@example.test',
            );
          },
          profileProvisioner: provisioner,
        ),
      ),
    );

    await _fillEmailRegistration(tester);
    await _submitEmailRegistration(tester);

    expect(createdCredentials, [('member@example.test', 'password123')]);
    expect(store.createdUids, ['auth-user-123']);
    expect(store.profiles['auth-user-123'], {
      'displayname': 'Member Name',
      'email': 'member@example.test',
      'cellnumber': '',
      'avatar': '',
      'society': '',
      'dob': '',
      'profile_completed': false,
    });
    expect(find.text('✅ Account created successfully!'), findsOneWidget);
    expect(find.text('Creating your account...'), findsNothing);
  });

  testWidgets('does not provision an account when form validation fails', (
    tester,
  ) async {
    var createCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: RegisterScreen(
          createEmailAccount: (_, _) async {
            createCalls++;
            return const RegistrationAccount(uid: 'should-not-be-created');
          },
          profileProvisioner: AccountProfileProvisioner(
            store: _FakeUserProfileStore(),
          ),
        ),
      ),
    );

    await tester.ensureVisible(find.text('Continue with Email'));
    await tester.tap(find.text('Continue with Email'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter your name'), findsOneWidget);
    expect(createCalls, 0);
  });

  testWidgets('rejects invalid email and weak password before auth call', (
    tester,
  ) async {
    var createCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: RegisterScreen(
          createEmailAccount: (_, _) async {
            createCalls++;
            return const RegistrationAccount(uid: 'not-created');
          },
          profileProvisioner: AccountProfileProvisioner(
            store: _FakeUserProfileStore(),
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextFormField).at(0), 'Member Name');
    await tester.enterText(find.byType(TextFormField).at(1), 'invalid-email');
    await tester.enterText(find.byType(TextFormField).at(2), 'weak');
    await tester.enterText(find.byType(TextFormField).at(3), 'weak');
    await tester.ensureVisible(find.byType(Checkbox));
    await tester.tap(find.byType(Checkbox));
    await tester.ensureVisible(find.text('Continue with Email'));
    await tester.tap(find.text('Continue with Email'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid email'), findsOneWidget);
    expect(find.text('Use at least 8 characters'), findsOneWidget);
    expect(createCalls, 0);
    expect(find.text('Creating your account...'), findsNothing);
  });

  testWidgets('maps Firebase registration failures without provider details', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RegisterScreen(
          createEmailAccount: (_, _) => Future.error(
            FirebaseAuthException(
              code: 'network-request-failed',
              message: 'raw provider response',
            ),
          ),
          profileProvisioner: AccountProfileProvisioner(
            store: _FakeUserProfileStore(),
          ),
        ),
      ),
    );

    await _fillEmailRegistration(tester);
    await _submitEmailRegistration(tester);

    expect(
      find.text('Check your internet connection and try again.'),
      findsOneWidget,
    );
    expect(find.text('raw provider response'), findsNothing);
    expect(find.text('Creating your account...'), findsNothing);
  });

  testWidgets('shows the existing email-already-in-use recovery dialog', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RegisterScreen(
          createEmailAccount: (_, _) =>
              Future.error(FirebaseAuthException(code: 'email-already-in-use')),
          profileProvisioner: AccountProfileProvisioner(
            store: _FakeUserProfileStore(),
          ),
        ),
      ),
    );

    await _fillEmailRegistration(tester);
    await _submitEmailRegistration(tester);

    expect(find.text('Account Exists'), findsOneWidget);
    expect(find.text('Sign In Now'), findsOneWidget);
    expect(find.text('Creating your account...'), findsNothing);
  });

  testWidgets(
    'retries failed provisioning with the existing auth UID and no second account',
    (tester) async {
      final store = _FakeUserProfileStore()..failBeforeNextCreate = true;
      final createCalls = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: RegisterScreen(
            createEmailAccount: (email, _) async {
              createCalls.add(email);
              return const RegistrationAccount(
                uid: 'already-authenticated-uid',
                email: 'member@example.test',
              );
            },
            profileProvisioner: AccountProfileProvisioner(store: store),
          ),
        ),
      );

      await _fillEmailRegistration(tester);
      await _submitEmailRegistration(tester);

      expect(createCalls, ['member@example.test']);
      expect(store.profiles, isEmpty);
      expect(
        find.text(
          "Your account was created, but we couldn't finish setting up your profile. Please retry account setup.",
        ),
        findsOneWidget,
      );
      expect(find.text('Creating your account...'), findsNothing);

      await _submitEmailRegistration(tester);

      expect(createCalls, ['member@example.test']);
      expect(store.createdUids, [
        'already-authenticated-uid',
        'already-authenticated-uid',
      ]);
      expect(store.profiles, contains('already-authenticated-uid'));
      expect(find.text('✅ Account created successfully!'), findsOneWidget);
      expect(find.text('Creating your account...'), findsNothing);
    },
  );

  testWidgets('verifies a profile when the write response is lost', (
    tester,
  ) async {
    final store = _FakeUserProfileStore()..failAfterNextCreate = true;
    var createCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: RegisterScreen(
          createEmailAccount: (_, _) async {
            createCalls++;
            return const RegistrationAccount(
              uid: 'committed-profile-uid',
              email: 'member@example.test',
            );
          },
          profileProvisioner: AccountProfileProvisioner(store: store),
        ),
      ),
    );

    await _fillEmailRegistration(tester);
    await _submitEmailRegistration(tester);

    expect(createCalls, 1);
    expect(store.createdUids, ['committed-profile-uid']);
    expect(store.profiles, contains('committed-profile-uid'));
    expect(find.text('✅ Account created successfully!'), findsOneWidget);
    expect(find.textContaining("couldn't finish setting up"), findsNothing);
  });

  testWidgets('Google registration cancellation is not treated as success', (
    tester,
  ) async {
    var profileReads = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: RegisterScreen(
          googleAccountSignIn: () async => null,
          profileProvisioner: AccountProfileProvisioner(
            store: _CountingProfileStore(() => profileReads++),
          ),
        ),
      ),
    );

    await tester.ensureVisible(find.text('Continue with Google'));
    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();

    expect(profileReads, 0);
    expect(find.text('Creating your account...'), findsNothing);
    expect(find.text('✅ Account created successfully!'), findsNothing);
  });

  testWidgets('Google registration provisions the signed-in UID', (
    tester,
  ) async {
    final store = _FakeUserProfileStore();
    var googleCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: RegisterScreen(
          googleAccountSignIn: () async {
            googleCalls++;
            return const RegistrationAccount(
              uid: 'google-user-456',
              email: 'google@example.test',
              displayName: 'Google Member',
            );
          },
          profileProvisioner: AccountProfileProvisioner(store: store),
        ),
      ),
    );

    await tester.ensureVisible(find.text('Continue with Google'));
    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();

    expect(googleCalls, 1);
    expect(store.createdUids, ['google-user-456']);
    expect(store.profiles['google-user-456'], {
      'displayname': 'Google Member',
      'email': 'google@example.test',
      'cellnumber': '',
      'avatar': '',
      'society': '',
      'dob': '',
      'profile_completed': false,
    });
    expect(find.text('Creating your account...'), findsNothing);
  });

  testWidgets('Google profile retry reuses the authenticated account', (
    tester,
  ) async {
    final store = _FakeUserProfileStore()..failBeforeNextCreate = true;
    var googleCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: RegisterScreen(
          googleAccountSignIn: () async {
            googleCalls++;
            return const RegistrationAccount(
              uid: 'google-retry-uid',
              email: 'google@example.test',
            );
          },
          profileProvisioner: AccountProfileProvisioner(store: store),
        ),
      ),
    );

    await tester.ensureVisible(find.text('Continue with Google'));
    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        "Your account was created, but we couldn't finish setting up your profile. Please retry account setup.",
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();

    expect(googleCalls, 1);
    expect(store.createdUids, ['google-retry-uid', 'google-retry-uid']);
    expect(store.profiles, contains('google-retry-uid'));
    expect(find.text('Creating your account...'), findsNothing);
    expect(find.textContaining("couldn't finish setting up"), findsNothing);
  });

  testWidgets('Google authentication failures do not expose provider text', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RegisterScreen(
          googleAccountSignIn: () => Future<RegistrationAccount?>.error(
            StateError('raw Google provider detail'),
          ),
          profileProvisioner: AccountProfileProvisioner(
            store: _FakeUserProfileStore(),
          ),
        ),
      ),
    );

    await tester.ensureVisible(find.text('Continue with Google'));
    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();

    expect(
      find.text('Google Sign-In could not be completed. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('raw Google provider detail'), findsNothing);
    expect(find.text('Creating your account...'), findsNothing);
  });
}

Future<void> _fillEmailRegistration(WidgetTester tester) async {
  await tester.enterText(find.byType(TextFormField).at(0), 'Member Name');
  await tester.enterText(
    find.byType(TextFormField).at(1),
    'member@example.test',
  );
  await tester.enterText(find.byType(TextFormField).at(2), 'password123');
  await tester.enterText(find.byType(TextFormField).at(3), 'password123');
  await tester.ensureVisible(find.byType(Checkbox));
  await tester.tap(find.byType(Checkbox));
}

Future<void> _submitEmailRegistration(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Continue with Email'));
  await tester.tap(find.text('Continue with Email'));
  await tester.pumpAndSettle();
}

class _FakeUserProfileStore implements UserProfileStore {
  final Map<String, Map<String, dynamic>> profiles = {};
  final List<String> createdUids = [];
  bool failBeforeNextCreate = false;
  bool failAfterNextCreate = false;

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
    if (failBeforeNextCreate) {
      failBeforeNextCreate = false;
      throw StateError('Firestore write failed');
    }
    profiles.putIfAbsent(uid, () => Map<String, dynamic>.from(profile));
    if (failAfterNextCreate) {
      failAfterNextCreate = false;
      throw StateError('Firestore response was lost');
    }
  }
}

class _CountingProfileStore implements UserProfileStore {
  _CountingProfileStore(this.onRead);

  final void Function() onRead;

  @override
  Future<Map<String, dynamic>?> readProfile(String uid) async {
    onRead();
    return null;
  }

  @override
  Future<void> createProfileIfAbsent(
    String uid,
    Map<String, dynamic> profile,
  ) async {}
}
