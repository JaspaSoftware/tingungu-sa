import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../data/media_video_model.dart';
import 'api_client.dart';

class MediaService {
  static const String _baseUrl = AppConfig.legacyBackendUrl;
  static final ApiClient _api = ApiClient.shared;

  /// Get latest media videos (for home page)
  static Future<List<MediaVideo>> getLatestVideos({int limit = 5}) async {
    try {
      final response = await _api.get(
        'get_latest_videos.php',
        baseUrl: _baseUrl,
        queryParameters: {'limit': '$limit'},
        timeout: const Duration(seconds: 10),
      );
      final data = response.body;
      if (data is Map<String, dynamic>) {
        if (data['success'] == true && data['data'] is List) {
          List<MediaVideo> videos = [];
          for (var videoData in data['data']) {
            videos.add(MediaVideo.fromJson(videoData));
          }
          return videos;
        }
      }

      return [];
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching latest videos: $e');
      }
      return [];
    }
  }

  /// Get all media videos (for media page)
  static Future<List<MediaVideo>> getAllVideos() async {
    try {
      final response = await _api.get(
        'get_all_videos.php',
        baseUrl: _baseUrl,
        timeout: const Duration(seconds: 10),
      );
      final data = response.body;
      if (data is Map<String, dynamic>) {
        if (data['success'] == true && data['data'] is List) {
          List<MediaVideo> videos = [];
          for (var videoData in data['data']) {
            videos.add(MediaVideo.fromJson(videoData));
          }
          return videos;
        }
      }

      return [];
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching all videos: $e');
      }
      return [];
    }
  }

  /// Format date to relative time
  static String formatDate(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes} min ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()}w ago';
    } else {
      return '${(difference.inDays / 30).floor()}m ago';
    }
  }
}