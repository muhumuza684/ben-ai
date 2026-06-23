import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/message.dart';
import '../models/reminder.dart';

// ── Get your FREE Groq API key at https://console.groq.com ──
// Sign up → API Keys → Create key → paste below
const _groqApiKey = String.fromEnvironment('GROQ_API_KEY');
const _groqUrl = 'https://api.groq.com/openai/v1/chat/completions';
const _model = 'llama3-8b-8192'; // Free, fast, smart enough for Ben

class BenResponse {
  final String text;
  final Reminder? reminder;
  BenResponse({required this.text, this.reminder});
}

class GroqService {
  static Future<BenResponse> chat({
    required List<Message> history,
    required String userMessage,
    required String userName,
    String? conversationSummary,
  }) async {
    final systemPrompt = _buildSystemPrompt(userName, conversationSummary);

    final messages = [
      {'role': 'system', 'content': systemPrompt},
      ...history.map((m) => m.toApiMap()),
      {'role': 'user', 'content': userMessage},
    ];

    final response = await http.post(
      Uri.parse(_groqUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_groqApiKey',
      },
      body: jsonEncode({
        'model': _model,
        'messages': messages,
        'max_tokens': 150,
        'temperature': 0.85,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Groq error: ${response.statusCode} ${response.body}');
    }

    final data = jsonDecode(response.body);
    final text = data['choices'][0]['message']['content'] as String;

    return BenResponse(text: text.trim());
  }

  static Future<Reminder?> detectReminder({
    required String userMessage,
    required String conversationSummary,
  }) async {
    final prompt = '''
Extract any reminder or scheduled call request from this message.
Message: "$userMessage"

If there is a reminder request, reply with ONLY this JSON (no other text):
{"has_reminder":true,"task":"what to remind about","remind_at":"HH:MM"}

If no reminder, reply with ONLY:
{"has_reminder":false}
''';

    final response = await http.post(
      Uri.parse(_groqUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_groqApiKey',
      },
      body: jsonEncode({
        'model': _model,
        'messages': [
          {'role': 'user', 'content': prompt}
        ],
        'max_tokens': 80,
        'temperature': 0.1,
      }),
    );

    if (response.statusCode != 200) return null;

    try {
      final data = jsonDecode(response.body);
      final text = (data['choices'][0]['message']['content'] as String).trim();
      final json = jsonDecode(text);

      if (json['has_reminder'] != true) return null;

      final timeStr = json['remind_at'] as String;
      final parts = timeStr.split(':');
      final now = DateTime.now();
      var scheduledAt = DateTime(
        now.year, now.month, now.day,
        int.parse(parts[0]), int.parse(parts[1]),
      );

      // If time already passed today, schedule for tomorrow
      if (scheduledAt.isBefore(now)) {
        scheduledAt = scheduledAt.add(const Duration(days: 1));
      }

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
You are Ben, a casual AI best friend talking to $userName on a voice call.

${summary != null && summary.isNotEmpty ? 'Recent conversation:\n$summary\n' : ''}

Rules:
- Reply in 1-2 short sentences only. This is a voice call, keep it brief.
- Talk like a real friend. Casual, warm, sometimes funny.
- Use the person's name occasionally but not every message.
- If they mention stress or problems, acknowledge it first.
- If they set a reminder, confirm it warmly.
- Never use bullet points or lists.
- Never say you are an AI unless directly asked.
''';
  }
}
