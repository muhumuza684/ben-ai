import 'dart:convert';
import 'package:http/http.dart' as http;

class WebSearchResult {
  final String title;
  final String snippet;
  final String url;
  WebSearchResult({required this.title, required this.snippet, required this.url});
}

class WebSearchService {
  static Future<List<WebSearchResult>> search(String query) async {
    final uri = Uri.https('api.duckduckgo.com', '/', {
      'q': query,
      'format': 'json',
      'no_html': '1',
      'skip_disambig': '0',
      'no_redirect': '1',
    });
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) throw Exception('Search unavailable');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final results = <WebSearchResult>[];
    final abstractText = data['AbstractText'] as String? ?? '';
    final abstractUrl = data['AbstractURL'] as String? ?? '';
    final heading = data['Heading'] as String? ?? query;
    if (abstractText.isNotEmpty) results.add(WebSearchResult(title: heading, snippet: abstractText, url: abstractUrl));
    for (final item in (data['RelatedTopics'] as List? ?? const [])) {
      if (item is Map && item['Text'] is String) {
        results.add(WebSearchResult(title: item['Text'] as String, snippet: item['Text'] as String, url: item['FirstURL'] as String? ?? ''));
      }
      if (results.length >= 5) break;
    }
    return results;
  }
}
