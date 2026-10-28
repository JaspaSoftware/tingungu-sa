import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../services/api_client.dart';

class YoutubeVideo {
  final String id;
  final String title;
  final String channelTitle;
  final String thumbnailUrl;
  final String publishedAt;
  final String description;

  YoutubeVideo({
    required this.id,
    required this.title,
    required this.channelTitle,
    required this.thumbnailUrl,
    required this.publishedAt,
    required this.description,
  });

  factory YoutubeVideo.fromJson(Map<String, dynamic> json) {
    return YoutubeVideo(
      id: json['snippet']['resourceId']['videoId'] ?? '',
      title: json['snippet']['title'] ?? 'Untitled',
      channelTitle: json['snippet']['channelTitle'] ?? 'Unknown',
      thumbnailUrl: json['snippet']['thumbnails']['medium']['url'] ?? '',
      publishedAt: json['snippet']['publishedAt'] ?? '',
      description: json['snippet']['description'] ?? '',
    );
  }
}

class YoutubeService {
  static const String apiKey = AppConfig.youtubeApiKey;
  static const String playlistId = AppConfig.youtubePlaylistId;

  static const String _baseUrl = 'https://www.googleapis.com/youtube/v3';
  static final ApiClient _api = ApiClient.shared;

  /// Fetch videos from Tingungu TV channel
  static Future<List<YoutubeVideo>> getChannelVideos({
    int maxResults = 12,
  }) async {
    if (apiKey.isEmpty || playlistId.isEmpty) {
      debugPrint(
        'YouTube is not configured. Set YOUTUBE_API_KEY and YOUTUBE_PLAYLIST_ID.',
      );
      return [];
    }

    try {
      final response = await _api.get(
        'playlistItems',
        baseUrl: _baseUrl,
        queryParameters: {
          'part': 'snippet',
          'playlistId': playlistId,
          'maxResults': '$maxResults',
          'key': apiKey,
          'order': 'date',
        },
        timeout: const Duration(seconds: 15),
      );
      final data = response.body;
      if (data is Map<String, dynamic>) {
        if (data['items'] is List) {
          List<YoutubeVideo> videos = [];
          for (var item in data['items']) {
            if (item is Map<String, dynamic>) {
              videos.add(YoutubeVideo.fromJson(item));
            }
          }
          return videos;
        }
      }

      return [];
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching YouTube videos: $e');
      }
      return [];
    }
  }

  /// Format published date
  static String formatDate(String dateString) {
    try {
      final dateTime = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays == 0) {
        if (difference.inHours == 0) {
          return '${difference.inMinutes} min ago';
        }
        return '${difference.inHours} hour ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      } else if (difference.inDays < 30) {
        return '${(difference.inDays / 7).floor()} weeks ago';
      } else {
        return '${(difference.inDays / 30).floor()} months ago';
      }
    } catch (e) {
      return 'Recently';
    }
  }
}
