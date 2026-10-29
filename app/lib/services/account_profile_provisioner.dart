import 'package:cloud_firestore/cloud_firestore.dart';

abstract interface class UserProfileStore {
  Future<Map<String, dynamic>?> readProfile(String uid);

  Future<void> createProfileIfAbsent(
    String uid,
    Map<String, dynamic> profile,
  );
}

class FirestoreUserProfileStore implements UserProfileStore {
  FirestoreUserProfileStore(this.firestore);

  final FirebaseFirestore firestore;

  @override
  Future<Map<String, dynamic>?> readProfile(String uid) async {
    final snapshot = await firestore.collection('users').doc(uid).get();
    return snapshot.data();
  }

  @override
  Future<void> createProfileIfAbsent(
    String uid,
    Map<String, dynamic> profile,
  ) async {
    final reference = firestore.collection('users').doc(uid);
    await firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      if (snapshot.exists) return;

      transaction.set(reference, {
        ...profile,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }
}

class AccountProfileProvisioner {
  AccountProfileProvisioner({required this.store});

  static AccountProfileProvisioner? _instance;

  static AccountProfileProvisioner get instance =>
      _instance ??= AccountProfileProvisioner(
        store: FirestoreUserProfileStore(FirebaseFirestore.instance),
      );

  final UserProfileStore store;

  Future<void> ensureProfile({
    required String uid,
    String? email,
    String? displayName,
    String? photoUrl,
  }) async {
    if (uid.trim().isEmpty) {
      throw ArgumentError.value(uid, 'uid', 'Must not be empty.');
    }

    final profile = <String, dynamic>{
      'displayname': displayName?.trim().isNotEmpty == true
          ? displayName!.trim()
          : 'New User',
      'cellnumber': '',
      'avatar': photoUrl ?? '',
      'society': '',
      'dob': '',
      'profile_completed': false,
      if (email?.isNotEmpty == true) 'email': email,
    };

    if (await store.readProfile(uid) != null) return;

    try {
      await store.createProfileIfAbsent(uid, profile);
    } catch (writeError) {
      try {
        if (await store.readProfile(uid) != null) return;
      } catch (_) {
        throw AccountProfileProvisioningException(
          'The profile write could not be verified.',
          cause: writeError,
        );
      }
      rethrow;
    }

    if (await store.readProfile(uid) == null) {
      throw const AccountProfileProvisioningException(
        'The profile was not available after it was created.',
      );
    }
  }
}

class AccountProfileProvisioningException implements Exception {
  const AccountProfileProvisioningException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}
