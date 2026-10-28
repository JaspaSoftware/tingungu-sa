import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../data/community_model.dart';
import 'api_client.dart';

class CommunityService {
  static final ApiClient _api = ApiClient.shared;

  static Future<ApiResponse> _request(
    String path, {
    Map<String, String>? queryParameters,
    Map<String, dynamic>? body,
  }) {
    if (body != null) {
      return _api.post(
        path,
        baseUrl: AppConfig.communityApiBaseUrl,
        queryParameters: queryParameters,
        body: body,
      );
    }
    return _api.get(
      path,
      baseUrl: AppConfig.communityApiBaseUrl,
      queryParameters: queryParameters,
      timeout: const Duration(seconds: 10),
    );
  }

  static Map<String, dynamic> _requireObject(Object? body) {
    if (body is Map<String, dynamic>) return body;
    throw const FormatException('Community service returned an invalid response.');
  }

  /// Get all available communities.
  static Future<List<Community>> getAvailableCommunities() async {
    try {
      final data = _requireObject(
        (await _request('get_communities.php')).body,
      );
      if (data['success'] == true && data['data'] is List) {
        return (data['data'] as List)
            .map((item) => Community.fromJson(item))
            .toList();
      }
      return [];
    } catch (error) {
      if (kDebugMode) debugPrint('Error fetching communities: $error');
      return [];
    }
  }

  /// Join a community with an invitation code.
  static Future<Map<String, dynamic>> joinCommunityWithCode(
    String invitationCode,
    int userId,
  ) async {
    try {
      return _requireObject(
        (await _request(
          'join_community.php',
          body: {
            'invitation_code': invitationCode,
            'user_id': userId,
          },
        ))
            .body,
      );
    } catch (error) {
      if (kDebugMode) debugPrint('Error joining community: $error');
      return {'success': false, 'message': error.toString()};
    }
  }

  /// Get a user's joined communities.
  static Future<List<Community>> getUserCommunities(int userId) async {
    try {
      final data = _requireObject(
        (await _request(
          'get_user_communities.php',
          queryParameters: {'user_id': '$userId'},
        ))
            .body,
      );
      if (data['success'] == true && data['data'] is List) {
        return (data['data'] as List)
            .map((item) => Community.fromJson(item))
            .toList();
      }
      return [];
    } catch (error) {
      if (kDebugMode) debugPrint('Error fetching user communities: $error');
      return [];
    }
  }

  /// Get community details by ID.
  static Future<Community?> getCommunityDetails(int communityId) async {
    try {
      final data = _requireObject(
        (await _request(
          'get_community_details.php',
          queryParameters: {'id': '$communityId'},
        ))
            .body,
      );
      if (data['success'] == true && data['data'] != null) {
        return Community.fromJson(data['data']);
      }
      return null;
    } catch (error) {
      if (kDebugMode) debugPrint('Error fetching community details: $error');
      return null;
    }
  }
}
