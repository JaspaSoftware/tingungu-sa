import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Member-visible profile data, stored in `public_profiles/{uid}`.
///
/// Other members may read this collection; the private `users/{uid}` document
/// (email, phone, wallet, role) is readable only by its owner and admins.
class PublicProfileService {
  PublicProfileService._();

  static final _col = FirebaseFirestore.instance.collection('public_profiles');

  /// Merge [data] into the signed-in member's public profile (best effort).
  static Future<void> update(Map<String, dynamic> data) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await _col.doc(uid).set(data, SetOptions(merge: true));
    } catch (_) {}
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
    } catch (_) {}
  }
}
