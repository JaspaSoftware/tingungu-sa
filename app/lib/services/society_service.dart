import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'public_profile_service.dart';
import 'package:flutter/foundation.dart';

import '../data/society_model.dart';

class SocietyService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const String _apiBase = 'https://tingungu-api.azurewebsites.net/api';

  /// The directory lives in MySQL and is served by the authenticated API.
  static Future<List<Society>> _fetchDirectory() async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (token == null) return [];
    final res = await http.get(
      Uri.parse('$_apiBase/societies'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode != 200) {
      throw Exception('Societies request failed (${res.statusCode})');
    }
    return (jsonDecode(res.body) as List)
        .map((row) => Society.fromApi(row as Map<String, dynamic>))
        .toList();
  }

  static Future<List<Society>> getAllSocieties() async {
    try {
      final societies = await _fetchDirectory();
      societies.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return societies;
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching societies: $e');
      }
      return [];
    }
  }

  static Future<List<Society>> searchSocieties(String query) async {
    final q = query.toLowerCase();
    final all = await getAllSocieties();
    return all
        .where(
          (s) =>
              s.name.toLowerCase().contains(q) ||
              (s.circuit?.toLowerCase().contains(q) ?? false),
        )
        .toList();
  }

  static Future<List<Society>> getSocietiesByCircuit(String circuit) async {
    final all = await getAllSocieties();
    return all.where((s) => s.circuit == circuit).toList();
  }
  /// Join a society (Update user profile in Firestore)
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
    } catch (e) {
      if (kDebugMode) {
        print('Error joining society: $e');
      }
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// Get user's society from Firestore
  static Future<Society?> getUserSociety(String userId) async {
    try {
      final userDoc = await _db.collection('users').doc(userId).get();
      if (userDoc.exists && userDoc.data() != null) {
        final data = userDoc.data()!;
        final societyName = (data['society'] ?? data['society_name'])
            ?.toString();

        if (societyName != null && societyName.trim().isNotEmpty) {
          final cleanName = societyName.trim();

          // Find the society object by name (case-insensitive)
          final lower = cleanName.toLowerCase();
          final directory = await getAllSocieties();
          for (final society in directory) {
            final name = society.name.toLowerCase();
            if (name == lower || name.contains(lower) || lower.contains(name)) {
              return society;
            }
          }

          // Return a virtual society if name exists on user profile
          return Society(
            id: 'virtual',
            name: cleanName,
            circuit: 'Methodist Church',
            location: 'Local Society',
          );
        }
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching user society: $e');
      }
      return null;
    }
  }

  /// Leave society (Update user profile in Firestore)
  static Future<Map<String, dynamic>> leaveSociety(String userId) async {
    try {
      await _db.collection('users').doc(userId).update({
        'society': FieldValue.delete(),
      });
      await PublicProfileService.update({'society': '', 'society_name': ''});

      return {'success': true, 'message': 'Left society successfully'};
    } catch (e) {
      if (kDebugMode) {
        print('Error leaving society: $e');
      }
      return {'success': false, 'message': 'Error: $e'};
    }
  }
}
