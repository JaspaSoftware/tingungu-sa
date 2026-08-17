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
/// Three Firestore fields on `users/{uid}` drive this:
/// - `presence_status`: the member's chosen status ('online' | 'busy' | 'away')
/// - `presence_active`: whether they're signed in (false only after Logout)
/// - `presence_backgrounded_at`: server timestamp of when the app was last
///   backgrounded, or null while foregrounded
///
/// The circle shown to other members is grey only when `presence_active` is
/// false - that only happens on an explicit Logout, never from merely
/// backgrounding the app. `presence_status` survives backgrounding (e.g. a
/// member marked Busy stays Busy after switching apps and back).
///
/// Away is *not* written by a timer while the app sits backgrounded - a
/// background isolate can be suspended by the OS at any point, so a delayed
/// write from that state is unreliable. Instead [markAppBackground] records
/// a timestamp immediately (a single fast write, sent right as the app is
/// backgrounded, before it risks being suspended), and [colorFor]/[labelFor]
/// derive Away at render time by comparing that timestamp to now. This never
/// touches `presence_status`, so a manual Busy/Away choice is untouched by
/// the automatic Away.
class PresenceService {
  PresenceService._();

  static const String _statusField = 'presence_status';
  static const String _activeField = 'presence_active';
  static const String _backgroundedAtField = 'presence_backgrounded_at';

  /// How long the app must sit backgrounded before a member renders as Away.
  static const Duration awayDelay = Duration(minutes: 1);

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
      _backgroundedAtField: null,
    });
  }

  /// Call when the app returns to the foreground within an existing
  /// session, or the member taps the screen after being away. Marks the
  /// member active and clears the backgrounded timestamp, without touching
  /// whatever status they'd left themselves as.
  static Future<void> markAppForeground() {
    return _update({_activeField: true, _backgroundedAtField: null});
  }

  /// Call the moment the app is backgrounded. Records when it happened so
  /// Away can be derived later - see the class doc for why this isn't a
  /// delayed write.
  static Future<void> markAppBackground() {
    return _update({_backgroundedAtField: FieldValue.serverTimestamp()});
  }

  /// Call right before signing out. This is the only path that should ever
  /// make a member appear Offline to others.
  static Future<void> goOffline() {
    return _update({_activeField: false, _backgroundedAtField: null});
  }

  /// Called from the status picker when a member sets their own status.
  static Future<void> setStatus(PresenceStatus status) {
    return _update({
      _statusField: status.name,
      _activeField: true,
      _backgroundedAtField: null,
    });
  }

  static PresenceStatus _statusFromString(String? value) {
    return PresenceStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => PresenceStatus.online,
    );
  }

  static DateTime? _asDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  /// The status to actually render, folding in the automatic Away derived
  /// from [backgroundedAt]. Never overrides a manual Busy/Away choice.
  static PresenceStatus _effectiveStatus({
    required String? status,
    dynamic backgroundedAt,
  }) {
    final chosen = _statusFromString(status);
    if (chosen != PresenceStatus.online) return chosen;
    final backgroundedSince = _asDateTime(backgroundedAt);
    if (backgroundedSince == null) return chosen;
    if (DateTime.now().difference(backgroundedSince) >= awayDelay) {
      return PresenceStatus.away;
    }
    return chosen;
  }

  /// The dot color to render for a member, given their raw Firestore fields.
  static Color colorFor({
    required bool active,
    required String? status,
    dynamic backgroundedAt,
  }) {
    if (!active) return Colors.grey.shade400;
    switch (_effectiveStatus(status: status, backgroundedAt: backgroundedAt)) {
      case PresenceStatus.busy:
        return Colors.red.shade600;
      case PresenceStatus.away:
        return const Color(0xFFFB8B24);
      case PresenceStatus.online:
        return Colors.green.shade600;
    }
  }

  /// The human-readable label to render alongside the dot.
  static String labelFor({
    required bool active,
    required String? status,
    dynamic backgroundedAt,
  }) {
    if (!active) return 'Offline';
    switch (_effectiveStatus(status: status, backgroundedAt: backgroundedAt)) {
      case PresenceStatus.busy:
        return 'Busy';
      case PresenceStatus.away:
        return 'Away';
      case PresenceStatus.online:
        return 'Online';
    }
  }
}
