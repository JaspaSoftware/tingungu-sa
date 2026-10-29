import 'package:flutter/foundation.dart';

import '../data/scripture_model.dart';
import 'api_client.dart';

class ScriptureService {
  static const String _baseUrl = 'https://labs.bible.org/api';
  static final ApiClient _api = ApiClient.shared;

  /// Fetch a random scripture verse
  /// Uses NET Bible API which supports 'random' as passage parameter
  /// No API key required
  static Future<Scripture> getRandomScripture() async {
    try {
      final response = await _api.get(
        '',
        baseUrl: _baseUrl,
        queryParameters: {
          'passage': 'random',
          'formatting': 'plain',
          'type': 'json',
        },
        timeout: const Duration(seconds: 10),
      );
      final data = response.body;
      if (data is List && data.isNotEmpty && data.first is Map<String, dynamic>) {
        final verse = data.first as Map<String, dynamic>;
        final text = verse['text'] ?? '';
        final bookname = verse['bookname'] ?? 'Unknown';
        final chapter = verse['chapter'] ?? 0;
        final verseNum = verse['verse'] ?? 0;

        return Scripture(
          text: '"$text"',
          reference: '$bookname $chapter:$verseNum',
          translation: 'NET Bible',
        );
      }

      return _getDefaultScripture();
    } catch (e) {
      debugPrint('Error fetching scripture: $e');
      return _getDefaultScripture();
    }
  }

  /// Fallback default scripture
  static Scripture _getDefaultScripture() {
    return Scripture(
      text:
          '"For I know the plans I have for you, declares the Lord, plans for welfare and not for evil, to give you a future and a hope."',
      reference: 'Jeremiah 29:11',
      translation: 'ESV',
    );
  }
}
