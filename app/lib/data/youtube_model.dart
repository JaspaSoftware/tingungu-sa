// File: lib/services/youtube_model.dart

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';

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
  static const String _defaultApiKey = 'YOUR_YOUTUBE_API_KEY';
  static const String _defaultPlaylistId = 'YOUR_PLAYLIST_ID';

  static const String _baseUrl =
      'https://www.googleapis.com/youtube/v3/playlistItems';

  /// Fetch videos from Tingungu TV channel
  static Future<List<YoutubeVideo>> getChannelVideos({
    int maxResults = 12,
  }) async {
    try {
      final config = await FirebaseFirestore.instance
          .collection('admin_settings')
          .doc('config')
          .get();
      final google = config.data()?['google'];
      final apiKey = google is Map<String, dynamic>
          ? (google['youtubeApiKey'] as String?)?.trim() ?? _defaultApiKey
          : _defaultApiKey;
      final playlistId = google is Map<String, dynamic>
          ? (google['youtubePlaylistId'] as String?)?.trim() ??
                _defaultPlaylistId
          : _defaultPlaylistId;

      if (apiKey == _defaultApiKey || playlistId == _defaultPlaylistId) {
        return [];
      }

      final url = Uri.parse(
        '$_baseUrl?part=snippet&playlistId=$playlistId&maxResults=$maxResults&key=$apiKey&order=date',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['items'] is List) {
          List<YoutubeVideo> videos = [];
          for (var item in data['items']) {
            videos.add(YoutubeVideo.fromJson(item));
          }
          return videos;
        }
      } else {
        throw Exception('Failed to load videos: ${response.statusCode}');
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
