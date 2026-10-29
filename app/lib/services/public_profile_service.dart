import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Member-visible profile data, stored in `public_profiles/{uid}`.
///
/// Signed-in members may read individual documents; collection listing is
/// disabled. The private `users/{uid}` document is readable only by its owner
/// and admins.
class PublicProfileService {
  PublicProfileService._();

  static final _col = FirebaseFirestore.instance.collection('public_profiles');
  static const _publicFields = {
    'displayname',
    'avatar',
    'society',
    'society_name',
    'presence_status',
    'presence_active',
    'presence_updated_at',
    'presence_backgrounded_at',
  };

  /// Merge [data] into the signed-in member's public profile (best effort).
  static Future<void> update(Map<String, dynamic> data) async {
    if (data.keys.any((key) => !_publicFields.contains(key))) {
      throw ArgumentError.value(
        data.keys,
        'data',
        'Contains fields that are not part of the public profile.',
      );
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await _col.doc(uid).set(data, SetOptions(merge: true));
    } catch (error) {
      if (kDebugMode) debugPrint('Could not update public profile: $error');
    }
  }

  /// Rebuild the public profile from the member's private profile.
  /// Also backfills members who registered before this collection existed.
  static Future<void> syncFromPrivateProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final d = snap.data() ?? {};
      final society = (d['society'] ?? d['society_name'])?.toString() ?? '';
      await _col.doc(user.uid).set({
        'displayname':
            (d['displayname'] ?? d['display_name'] ?? user.displayName ?? '')
                .toString(),
        'avatar': (d['avatar'] ?? '').toString(),
        'society': society,
        'society_name': society,
      }, SetOptions(merge: true));
    } catch (error) {
      if (kDebugMode) debugPrint('Could not sync public profile: $error');
    }
  }
}
