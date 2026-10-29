import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../data/society_model.dart';
import 'api_client.dart';
import 'public_profile_service.dart';

class SocietyService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final ApiClient _api = ApiClient.shared;

  /// The public directory lives in MySQL and is served by the API.
  static Future<List<Society>> _fetchDirectory() async {
    final response = await _api.get(
      'societies',
      baseUrl: AppConfig.apiBaseUrl,
    );
    if (response.body is! List) {
      throw const FormatException('Societies response must be a list.');
    }
    return (response.body as List)
        .map((row) {
          if (row is! Map<String, dynamic>) {
            throw const FormatException('Society record must be an object.');
          }
          return Society.fromApi(row);
        })
        .toList();
  }

  static Future<List<Society>> getAllSocieties() async {
    try {
      final societies = await _fetchDirectory();
      societies.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      return societies;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Error fetching societies: $error');
      }
      return [];
    }
  }

  static Future<List<Society>> searchSocieties(String query) async {
    final q = query.toLowerCase();
    final all = await getAllSocieties();
    return all
        .where(
          (society) =>
              society.name.toLowerCase().contains(q) ||
              (society.circuit?.toLowerCase().contains(q) ?? false),
        )
        .toList();
  }

  static Future<List<Society>> getSocietiesByCircuit(String circuit) async {
    final all = await getAllSocieties();
    return all.where((society) => society.circuit == circuit).toList();
  }

  /// Join a society by updating the authenticated user's profile.
  static Future<Map<String, dynamic>> joinSociety(
    String userId,
    String societyName,
  ) async {
    try {
      await _db.collection('users').doc(userId).set({
        'society': societyName,
        'society_name': societyName,
      }, SetOptions(merge: true));
      await PublicProfileService.update({
        'society': societyName,
        'society_name': societyName,
      });

      return {'success': true, 'message': 'Joined society successfully'};
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Error joining society: $error');
      }
      return {'success': false, 'message': 'Error: $error'};
    }
  }

  /// Get a user's society from Firestore.
  static Future<Society?> getUserSociety(String userId) async {
    try {
      final userDoc = await _db.collection('users').doc(userId).get();
      if (userDoc.exists && userDoc.data() != null) {
        final data = userDoc.data()!;
        final societyName = (data['society'] ?? data['society_name'])
            ?.toString();

        if (societyName != null && societyName.trim().isNotEmpty) {
          final cleanName = societyName.trim();
          final lower = cleanName.toLowerCase();
          final directory = await getAllSocieties();
          for (final society in directory) {
            final name = society.name.toLowerCase();
            if (name == lower || name.contains(lower) || lower.contains(name)) {
              return society;
            }
          }

          return Society(
            id: 'virtual',
            name: cleanName,
            circuit: 'Methodist Church',
            location: 'Local Society',
          );
        }
      }
      return null;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Error fetching user society: $error');
      }
      return null;
    }
  }

  /// Leave society by updating the user's profile.
  static Future<Map<String, dynamic>> leaveSociety(String userId) async {
    try {
      await _db.collection('users').doc(userId).update({
        'society': FieldValue.delete(),
      });
      await PublicProfileService.update({'society': '', 'society_name': ''});

      return {'success': true, 'message': 'Left society successfully'};
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Error leaving society: $error');
      }
      return {'success': false, 'message': 'Error: $error'};
    }
  }
}
