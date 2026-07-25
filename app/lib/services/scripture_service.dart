import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../data/scripture_model.dart';

class ScriptureService {
  static const String _baseUrl = 'https://labs.bible.org/api/';

  /// Fetch a random scripture verse
  /// Uses NET Bible API which supports 'random' as passage parameter
  /// No API key required
  static Future<Scripture> getRandomScripture() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl?passage=random&formatting=plain&type=json'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data is List && data.isNotEmpty) {
          final verse = data[0];

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
      }

      // Return default if API fails
      return _getDefaultScripture();
    } catch (e) {
      if (kDebugMode) {
        if (kDebugMode) {
          print('Error fetching scripture: $e');
        }
      }
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
