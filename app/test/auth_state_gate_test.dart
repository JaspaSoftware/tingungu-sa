import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tingungu_app/widgets/auth_state_gate.dart';

void main() {
  testWidgets('routes signed-out and authenticated stream transitions', (
    tester,
  ) async {
    final authEvents = StreamController<User?>.broadcast();
    final provisionedUids = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: AuthStateGate(
          authStateChanges: authEvents.stream,
          currentUser: null,
          signedOut: const Text('Sign in route'),
          authenticated: const Text('Protected home'),
          provisionProfile: (user) async => provisionedUids.add(user.uid),
          errorBuilder: (_) => const Text('Authentication unavailable'),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Sign in route'), findsNothing);
    authEvents.add(null);
    await tester.pumpAndSettle();
    expect(find.text('Sign in route'), findsOneWidget);
    expect(find.text('Protected home'), findsNothing);

    authEvents.add(_TestUser('restored-user'));
    await tester.pumpAndSettle();
    expect(find.text('Protected home'), findsOneWidget);
    expect(provisionedUids, ['restored-user']);

    authEvents.add(_TestUser('restored-user'));
    await tester.pumpAndSettle();
    expect(provisionedUids, ['restored-user']);

    authEvents.add(null);
    await tester.pumpAndSettle();
    expect(find.text('Sign in route'), findsOneWidget);
    expect(find.text('Protected home'), findsNothing);
    await authEvents.close();
  });

  testWidgets('retries missing-profile recovery without signing out', (
    tester,
  ) async {
    final authEvents = StreamController<User?>.broadcast();
    var attempts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: AuthStateGate(
          authStateChanges: authEvents.stream,
          currentUser: _TestUser('incomplete-account'),
          signedOut: const Text('Sign in route'),
          authenticated: const Text('Protected home'),
          provisionProfile: (_) async {
            attempts++;
            if (attempts == 1) throw StateError('temporary Firestore error');
          },
          errorBuilder: (_) => const Text('Authentication unavailable'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Unable to complete account setup'), findsOneWidget);
    expect(find.text('Sign in route'), findsNothing);
    expect(find.text('Protected home'), findsNothing);

    await tester.tap(find.text('Retry account setup'));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.text('Protected home'), findsOneWidget);
    expect(find.text('Sign in route'), findsNothing);
    await authEvents.close();
  });

  testWidgets('holds authenticated route until profile provisioning succeeds', (
    tester,
  ) async {
    final authEvents = StreamController<User?>.broadcast();
    final provision = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: AuthStateGate(
          authStateChanges: authEvents.stream,
          currentUser: _TestUser('restored-user'),
          signedOut: const Text('Sign in route'),
          authenticated: const Text('Protected home'),
          provisionProfile: (_) => provision.future,
          errorBuilder: (_) => const Text('Authentication unavailable'),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Protected home'), findsNothing);

    provision.complete();
    await tester.pumpAndSettle();

    expect(find.text('Protected home'), findsOneWidget);
    expect(find.text('Sign in route'), findsNothing);
    await authEvents.close();
  });

  testWidgets('older user provisioning cannot replace a newer auth session', (
    tester,
  ) async {
    final authEvents = StreamController<User?>.broadcast();
    final firstUserProvisioning = Completer<void>();
    final secondUserProvisioning = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: AuthStateGate(
          authStateChanges: authEvents.stream,
          currentUser: _TestUser('first-user'),
          signedOut: const Text('Sign in route'),
          authenticated: const Text('Protected home'),
          provisionProfile: (user) => user.uid == 'first-user'
              ? firstUserProvisioning.future
              : secondUserProvisioning.future,
          errorBuilder: (_) => const Text('Authentication unavailable'),
        ),
      ),
    );

    authEvents.add(_TestUser('second-user'));
    await tester.pump();
    firstUserProvisioning.complete();
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Protected home'), findsNothing);

    secondUserProvisioning.complete();
    await tester.pumpAndSettle();
    expect(find.text('Protected home'), findsOneWidget);
    await authEvents.close();
  });

  testWidgets('keeps auth errors distinct from signed-out state', (
    tester,
  ) async {
    final authEvents = StreamController<User?>.broadcast();
    await tester.pumpWidget(
      MaterialApp(
        home: AuthStateGate(
          authStateChanges: authEvents.stream,
          currentUser: null,
          signedOut: const Text('Sign in route'),
          authenticated: const Text('Protected home'),
          provisionProfile: (_) async {},
          errorBuilder: (_) => const Text('Authentication unavailable'),
        ),
      ),
    );

    authEvents.addError(StateError('temporary stream failure'));
    await tester.pumpAndSettle();

    expect(find.text('Authentication unavailable'), findsOneWidget);
    expect(find.text('Sign in route'), findsNothing);
    expect(find.text('Protected home'), findsNothing);
    await authEvents.close();
  });

  testWidgets('stale profile completion cannot override a signed-out state', (
    tester,
  ) async {
    final authEvents = StreamController<User?>.broadcast();
    final provision = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: AuthStateGate(
          authStateChanges: authEvents.stream,
          currentUser: _TestUser('restored-user'),
          signedOut: const Text('Sign in route'),
          authenticated: const Text('Protected home'),
          provisionProfile: (_) => provision.future,
          errorBuilder: (_) => const Text('Authentication unavailable'),
        ),
      ),
    );

    authEvents.add(null);
    await tester.pumpAndSettle();
    expect(find.text('Sign in route'), findsOneWidget);

    provision.complete();
    await tester.pumpAndSettle();
    expect(find.text('Sign in route'), findsOneWidget);
    expect(find.text('Protected home'), findsNothing);
    await authEvents.close();
  });
}

class _TestUser implements User {
  _TestUser(this.uid);

  @override
  final String uid;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
