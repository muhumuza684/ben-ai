import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/message.dart';
import '../models/reminder.dart';

// ── IMPORTANT: Replace with your real Claude API key ──
const _apiKey = 'YOUR_CLAUDE_API_KEY_HERE';
const _apiUrl = 'https://api.anthropic.com/v1/messages';
const _model = 'claude-haiku-4-5-20251001'; // Fast + cheap for voice

class BenResponse {
  final String text;
  final Reminder? reminder; // non-null if Ben detected a reminder

  BenResponse({required this.text, this.reminder});
}

class ClaudeService {
  /// Sends conversation to Claude and gets Ben's reply.
  /// Also checks if the user set a reminder.
  static Future<BenResponse> chat({
    required List<Message> history,
    required String userMessage,
    required String userName,
    String? conversationSummary,
  }) async {
    final systemPrompt = _buildSystemPrompt(userName, conversationSummary);

    // Build message list: history + new user message
    final messages = [
      ...history.map((m) => m.toApiMap()),
      {'role': 'user', 'content': userMessage},
    ];

    final body = jsonEncode({
      'model': _model,
      'max_tokens': 300,
      'system': systemPrompt,
      'messages': messages,
    });

    final response = await http.post(
      Uri.parse(_apiUrl),
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': _apiKey,
        'anthropic-version': '2023-06-01',
      },
      body: body,
    );

    if (response.statusCode != 200) {
      throw Exception('Claude API error: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    final rawText = data['content'][0]['text'] as String;

    // Parse reminder if Ben detected one
    final reminder = _extractReminder(rawText, conversationSummary);

    // Clean the response text (remove reminder JSON if Ben included it)
    final cleanText = _cleanText(rawText);

    return BenResponse(text: cleanText, reminder: reminder);
  }

  /// Separate call to detect reminders from user message
  static Future<Reminder?> detectReminder({
    required String userMessage,
    required String conversationSummary,
  }) async {
    final prompt = '''
You are a reminder extractor. Given the user's message, extract any reminder or scheduling request.

User message: "$userMessage"

If the user is asking to be reminded about something or wants a call at a certain time, respond with ONLY this JSON:
{
  "has_reminder": true,
  "task": "description of what to remind about",
  "remind_at": "HH:MM" (24-hour format, today)
}

If there is no reminder request, respond with ONLY:
{"has_reminder": false}

Respond with JSON only. No other text.
''';

    final response = await http.post(
      Uri.parse(_apiUrl),
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': _apiKey,
        'anthropic-version': '2023-06-01',
      },
      body: jsonEncode({
        'model': _model,
        'max_tokens': 100,
        'messages': [
          {'role': 'user', 'content': prompt}
        ],
      }),
    );

    if (response.statusCode != 200) return null;

    try {
      final data = jsonDecode(response.body);
      final text = data['content'][0]['text'] as String;
      final json = jsonDecode(text.trim());

      if (json['has_reminder'] != true) return null;

      final timeStr = json['remind_at'] as String;
      final parts = timeStr.split(':');
      final now = DateTime.now();
      final scheduledAt = DateTime(
        now.year, now.month, now.day,
        int.parse(parts[0]), int.parse(parts[1]),
      );

      return Reminder(
        task: json['task'] as String,
        scheduledAt: scheduledAt,
        lastConversationSummary: conversationSummary,
      );
    } catch (_) {
      return null;
    }
  }

  static String _buildSystemPrompt(String userName, String? summary) {
    return '''
You are Ben, a casual AI best friend. You talk like a real friend — warm, funny, direct, never robotic.

User's name: $userName
${summary != null && summary.isNotEmpty ? 'Recent conversation context:\n$summary' : ''}

Rules:
- Keep replies short (1-3 sentences max) — this is a voice call, not an essay
- Be casual and natural. Use contractions. Be real.
- If the user mentions something emotional, acknowledge it first before moving on
- If user mentions a time or reminder, confirm it warmly and ask a follow-up
- Never say you are an AI unless directly asked
- Never use bullet points or lists — just talk normally
- Remember: you are their friend, not an assistant
''';
  }

  static Reminder? _extractReminder(String text, String? summary) {
    return null; // Reminder detection is done separately via detectReminder()
  }

  static String _cleanText(String text) {
    return text.trim();
  }
}
