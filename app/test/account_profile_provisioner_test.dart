import 'package:flutter_test/flutter_test.dart';
import 'package:tingungu_app/services/account_profile_provisioner.dart';

void main() {
  group('AccountProfileProvisioner', () {
    test(
      'creates a profile at the authenticated UID and verifies it',
      () async {
        final store = _FakeUserProfileStore();
        final provisioner = AccountProfileProvisioner(store: store);

        await provisioner.ensureProfile(
          uid: 'firebase-uid-123',
          email: 'member@example.test',
          displayName: '  Member Name  ',
          photoUrl: 'https://example.test/avatar.png',
        );

        expect(store.createdUids, ['firebase-uid-123']);
        expect(store.profiles['firebase-uid-123'], {
          'displayname': 'Member Name',
          'email': 'member@example.test',
          'cellnumber': '',
          'avatar': 'https://example.test/avatar.png',
          'society': '',
          'dob': '',
          'profile_completed': false,
        });
      },
    );

    test('email and Google accounts share the common profile fields', () async {
      final emailStore = _FakeUserProfileStore();
      final googleStore = _FakeUserProfileStore();
      final emailProvisioner = AccountProfileProvisioner(store: emailStore);
      final googleProvisioner = AccountProfileProvisioner(store: googleStore);

      await emailProvisioner.ensureProfile(
        uid: 'email-user',
        email: 'member@example.test',
        displayName: 'Member Name',
        photoUrl: 'https://example.test/member.png',
      );
      await googleProvisioner.ensureProfile(
        uid: 'google-user',
        email: 'member@example.test',
        displayName: 'Member Name',
        photoUrl: 'https://example.test/member.png',
      );

      expect(
        emailStore.profiles['email-user'],
        googleStore.profiles['google-user'],
      );
      expect(emailStore.createdUids, ['email-user']);
      expect(googleStore.createdUids, ['google-user']);
    });

    test(
      'preserves the original createdAt and all existing profile fields',
      () async {
        final originalCreatedAt = DateTime.utc(2020, 1, 2);
        final store = _FakeUserProfileStore()
          ..profiles['firebase-uid-123'] = {
            'displayname': 'Established Name',
            'email': 'member@example.test',
            'createdAt': originalCreatedAt,
            'customField': 'preserve me',
          };
        final provisioner = AccountProfileProvisioner(store: store);

        await provisioner.ensureProfile(
          uid: 'firebase-uid-123',
          email: 'new@example.test',
          displayName: 'New Provider Name',
        );

        expect(
          store.profiles['firebase-uid-123']?['createdAt'],
          originalCreatedAt,
        );
        expect(
          store.profiles['firebase-uid-123'],
          containsPair('displayname', 'Established Name'),
        );
        expect(
          store.profiles['firebase-uid-123'],
          containsPair('customField', 'preserve me'),
        );
        expect(store.createdUids, isEmpty);
      },
    );

    test(
      'does not backfill missing createdAt or recreate an existing profile',
      () async {
        final store = _FakeUserProfileStore()
          ..profiles['firebase-uid-123'] = {
            'displayname': 'Established Name',
            'email': 'member@example.test',
            'society': 'North Society',
            'customField': 'preserve me',
          };
        final provisioner = AccountProfileProvisioner(store: store);

        await provisioner.ensureProfile(
          uid: 'firebase-uid-123',
          email: 'different@example.test',
          displayName: 'Default Name',
        );

        expect(store.profiles['firebase-uid-123'], {
          'displayname': 'Established Name',
          'email': 'member@example.test',
          'society': 'North Society',
          'customField': 'preserve me',
        });
        expect(
          store.profiles['firebase-uid-123'],
          isNot(contains('createdAt')),
        );
        expect(store.createdUids, isEmpty);
      },
    );

    test(
      'accepts a write error when verification finds the committed profile',
      () async {
        final store = _FakeUserProfileStore()..failAfterNextCreate = true;
        final provisioner = AccountProfileProvisioner(store: store);

        await provisioner.ensureProfile(
          uid: 'firebase-uid-123',
          email: 'member@example.test',
        );

        expect(store.profiles, contains('firebase-uid-123'));
        expect(store.createdUids, ['firebase-uid-123']);
      },
    );

    test('propagates a failed write when the profile remains absent', () async {
      final store = _FakeUserProfileStore()..failBeforeNextCreate = true;
      final provisioner = AccountProfileProvisioner(store: store);

      await expectLater(
        provisioner.ensureProfile(uid: 'firebase-uid-123'),
        throwsA(isA<StateError>()),
      );
      expect(store.profiles, isEmpty);

      await provisioner.ensureProfile(uid: 'firebase-uid-123');
      expect(store.profiles, contains('firebase-uid-123'));
      expect(store.createdUids, ['firebase-uid-123', 'firebase-uid-123']);
    });

    test(
      'does not interpret a profile read error as a missing profile',
      () async {
        final store = _FakeUserProfileStore()..failNextRead = true;
        final provisioner = AccountProfileProvisioner(store: store);

        await expectLater(
          provisioner.ensureProfile(uid: 'firebase-uid-123'),
          throwsA(isA<StateError>()),
        );
        expect(store.createdUids, isEmpty);
      },
    );

    test(
      'reports failed post-write verification and recovers on retry',
      () async {
        final store = _FakeUserProfileStore()..failReadOnCall = 2;
        final provisioner = AccountProfileProvisioner(store: store);

        await expectLater(
          provisioner.ensureProfile(uid: 'firebase-uid-123'),
          throwsA(isA<StateError>()),
        );
        expect(store.profiles, contains('firebase-uid-123'));
        expect(store.createdUids, ['firebase-uid-123']);

        await provisioner.ensureProfile(uid: 'firebase-uid-123');
        expect(store.createdUids, ['firebase-uid-123']);
      },
    );

    test('rejects an empty UID without touching the profile store', () async {
      final store = _FakeUserProfileStore();
      final provisioner = AccountProfileProvisioner(store: store);

      await expectLater(
        provisioner.ensureProfile(uid: ' '),
        throwsArgumentError,
      );
      expect(store.readCount, 0);
      expect(store.createdUids, isEmpty);
    });
  });
}

class _FakeUserProfileStore implements UserProfileStore {
  final Map<String, Map<String, dynamic>> profiles = {};
  final List<String> createdUids = [];
  int readCount = 0;
  bool failNextRead = false;
  int? failReadOnCall;
  bool failBeforeNextCreate = false;
  bool failAfterNextCreate = false;

  @override
  Future<Map<String, dynamic>?> readProfile(String uid) async {
    readCount++;
    if (failNextRead || readCount == failReadOnCall) {
      failNextRead = false;
      throw StateError('Profile read failed');
    }
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
      throw StateError('Profile write failed');
    }
    profiles.putIfAbsent(uid, () => Map<String, dynamic>.from(profile));
    if (failAfterNextCreate) {
      failAfterNextCreate = false;
      throw StateError('Profile write response was lost');
    }
  }
}
