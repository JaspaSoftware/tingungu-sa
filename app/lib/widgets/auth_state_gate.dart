import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'profile_provisioning_gate.dart';

class AuthStateGate extends StatelessWidget {
  const AuthStateGate({
    super.key,
    required this.authStateChanges,
    required this.currentUser,
    required this.signedOut,
    required this.authenticated,
    required this.provisionProfile,
    required this.errorBuilder,
  });

  final Stream<User?> authStateChanges;
  final User? currentUser;
  final Widget signedOut;
  final Widget authenticated;
  final Future<void> Function(User user) provisionProfile;
  final Widget Function(Object error) errorBuilder;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: authStateChanges,
      initialData: currentUser,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return errorBuilder(snapshot.error!);
        }
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user == null) return signedOut;

        return ProfileProvisioningGate(
          key: ValueKey(user.uid),
          provision: () => provisionProfile(user),
          child: authenticated,
        );
      },
    );
  }
}
