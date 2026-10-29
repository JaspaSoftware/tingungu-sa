import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tingungu_app/widgets/profile_provisioning_gate.dart';

void main() {
  testWidgets('keeps dependent screens hidden until profile setup succeeds', (
    tester,
  ) async {
    final result = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: ProfileProvisioningGate(
          provision: () => result.future,
          child: const Text('Profile-dependent home'),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Profile-dependent home'), findsNothing);

    result.complete();
    await tester.pumpAndSettle();

    expect(find.text('Profile-dependent home'), findsOneWidget);
    expect(find.text('Unable to complete account setup'), findsNothing);
  });

  testWidgets('does not provision again for repeated same-user rebuilds', (
    tester,
  ) async {
    var provisionAttempts = 0;
    Widget buildGate() => MaterialApp(
      home: ProfileProvisioningGate(
        key: const ValueKey('firebase-uid'),
        provision: () async {
          provisionAttempts++;
        },
        child: const Text('Profile-dependent home'),
      ),
    );

    await tester.pumpWidget(buildGate());
    await tester.pumpAndSettle();
    await tester.pumpWidget(buildGate());
    await tester.pumpAndSettle();

    expect(provisionAttempts, 1);
    expect(find.text('Profile-dependent home'), findsOneWidget);
  });

  testWidgets(
    'shows recovery action and retries provisioning without sign-in',
    (tester) async {
      var provisionAttempts = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: ProfileProvisioningGate(
            provision: () {
              provisionAttempts++;
              return provisionAttempts == 1
                  ? Future<void>.error(StateError('Firestore unavailable'))
                  : Future<void>.value();
            },
            child: const Text('Profile-dependent home'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(provisionAttempts, 1);
      expect(find.text('Unable to complete account setup'), findsOneWidget);
      expect(find.textContaining('Your sign-in succeeded'), findsOneWidget);
      expect(find.text('Profile-dependent home'), findsNothing);

      await tester.tap(find.text('Retry account setup'));
      await tester.pumpAndSettle();

      expect(provisionAttempts, 2);
      expect(find.text('Profile-dependent home'), findsOneWidget);
      expect(find.text('Unable to complete account setup'), findsNothing);
    },
  );
}
