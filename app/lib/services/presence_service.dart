import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// A member's manually-chosen status. Persists in Firestore until they
/// change it themselves or start a new session (see [PresenceService.
/// goOnlineForNewSession]); it is independent of [PresenceService]'s
/// foreground/background tracking.
enum PresenceStatus { online, busy, away }

/// Tracks and displays each member's live presence.
///
/// Two Firestore fields on `users/{uid}` drive this:
/// - `presence_status`: the member's chosen status ('online' | 'busy' | 'away')
/// - `presence_active`: whether their app is currently open/foregrounded
///
/// The circle shown to other members is grey whenever `presence_active` is
/// false, regardless of `presence_status` - only an open app can be green,
/// busy, or away. `presence_status` itself survives backgrounding the app
/// (e.g. a member marked Busy stays Busy after switching apps and back),
/// and is only reset to Online at the start of a fresh session.
class PresenceService {
  PresenceService._();

  static const String _statusField = 'presence_status';
  static const String _activeField = 'presence_active';

  static DocumentReference<Map<String, dynamic>>? _userDoc() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance.collection('users').doc(uid);
  }

  static Future<void> _update(Map<String, dynamic> data) async {
    final doc = _userDoc();
    if (doc == null) return;
    try {
      await doc.set({
        ...data,
        'presence_updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Presence is best-effort; a failed write shouldn't interrupt the user.
    }
  }

  /// Call right after a successful login/registration, and on a cold start
  /// into an already-authenticated session. Every fresh session starts
  /// Online, even if the member had left themselves as Busy/Away before
  /// their last logout.
  static Future<void> goOnlineForNewSession() {
    return _update({
      _statusField: PresenceStatus.online.name,
      _activeField: true,
    });
  }

  /// Call when the app returns to the foreground within an existing
  /// session. Marks the member active again without touching whatever
  /// status they'd left themselves as.
  static Future<void> markAppForeground() {
    return _update({_activeField: true});
  }

  /// Call when the app is backgrounded. The member appears grey to others
  /// immediately, regardless of their chosen status.
  static Future<void> markAppBackground() {
    return _update({_activeField: false});
  }

  /// Call right before signing out.
  static Future<void> goOffline() {
    return _update({_activeField: false});
  }

  /// Called from the status picker when a member sets their own status.
  static Future<void> setStatus(PresenceStatus status) {
    return _update({_statusField: status.name, _activeField: true});
  }

  static PresenceStatus _statusFromString(String? value) {
    return PresenceStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => PresenceStatus.online,
    );
  }

  /// The dot color to render for a member, given their raw Firestore fields.
  static Color colorFor({required bool active, required String? status}) {
    if (!active) return Colors.grey.shade400;
    switch (_statusFromString(status)) {
      case PresenceStatus.busy:
        return Colors.red.shade600;
      case PresenceStatus.away:
        return const Color(0xFFFB8B24);
      case PresenceStatus.online:
        return Colors.green.shade600;
    }
  }

  /// The human-readable label to render alongside the dot.
  static String labelFor({required bool active, required String? status}) {
    if (!active) return 'Offline';
    switch (_statusFromString(status)) {
      case PresenceStatus.busy:
        return 'Busy';
      case PresenceStatus.away:
        return 'Away';
      case PresenceStatus.online:
        return 'Online';
    }
  }
}
