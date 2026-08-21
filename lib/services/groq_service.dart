import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/message.dart';
import '../models/reminder.dart';
import '../models/contact.dart';

const _groqApiKey = String.fromEnvironment('GROQ_API_KEY');
const _groqUrl = 'https://api.groq.com/openai/v1/chat/completions';
const _model = 'llama3-8b-8192';

class BenResponse {
  final String text;
  BenResponse({required this.text});
}

class GroqService {
  static Future<BenResponse> chat({
    required Contact contact,
    required List<Message> history,
    required String userMessage,
    required String userName,
    String? conversationSummary,
  }) async {
    final systemPrompt = '''${contact.systemPrompt}

Language: ${_languageName(contact.languageCode)} (${contact.languageCode}). Always reply in this language unless the user explicitly switches languages.
Phone-call rules: wait for the user's complete utterance, answer naturally in 1-2 short spoken sentences, and do not narrate internal reasoning.
User's name: $userName
${conversationSummary != null && conversationSummary.isNotEmpty ? 'Recent conversation:\n$conversationSummary' : ''}''';

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
      throw Exception('Groq error: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    final text = data['choices'][0]['message']['content'] as String;
    return BenResponse(text: text.trim());
  }

  static Future<Reminder?> detectReminder({
    required String userMessage,
    required String conversationSummary,
  }) async {
    // Keep the core scheduling promise deterministic. The AI parser is useful
    // for nuanced requests, but common phrases must work even if the network
    // or API key is unavailable.
    final local = _parseLocalReminder(userMessage, conversationSummary);
    if (local != null) return local;

    final prompt = '''
Extract any reminder or scheduled call request from this message.
Message: "$userMessage"
Current local date and time: ${DateTime.now().toIso8601String()}

If there is a reminder request reply with ONLY this JSON:
{"has_reminder":true,"task":"what to remind about","scheduled_at":"ISO-8601 local datetime"}

If no reminder reply with ONLY:
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
        'messages': [{'role': 'user', 'content': prompt}],
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

      final now = DateTime.now();
      final rawDate = json['scheduled_at']?.toString();
      DateTime scheduledAt;
      if (rawDate != null && rawDate.isNotEmpty) {
        scheduledAt = DateTime.parse(rawDate).toLocal();
      } else {
        final parts = (json['remind_at'] as String).split(':');
        scheduledAt = DateTime(now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1]));
      }
      if (scheduledAt.isBefore(now)) scheduledAt = scheduledAt.add(const Duration(days: 1));

      return Reminder(task: json['task'] as String, scheduledAt: scheduledAt, lastConversationSummary: conversationSummary);
    } catch (_) {
      return null;
    }
  }

  static Reminder? _parseLocalReminder(String message, String summary) {
    final lower = message.toLowerCase();
    final looksScheduled = lower.contains('call me') || lower.contains('remind me') || lower.contains('ring me') || lower.contains('schedule');
    if (!looksScheduled) return null;
    final now = DateTime.now();
    DateTime? when;
    final inMatch = RegExp(r'\bin\s+(\d+)\s+minutes?\b').firstMatch(lower);
    if (inMatch != null) {
      when = now.add(Duration(minutes: int.parse(inMatch.group(1)!)));
    } else {
      final timeMatch = RegExp(r'\bat\s+(\d{1,2})(?::(\d{2}))?\s*(am|pm)?', caseSensitive: false).firstMatch(lower);
      if (timeMatch != null) {
        var hour = int.parse(timeMatch.group(1)!);
        final minute = int.tryParse(timeMatch.group(2) ?? '0') ?? 0;
        final meridiem = timeMatch.group(3);
        if (meridiem == 'pm' && hour < 12) hour += 12;
        if (meridiem == 'am' && hour == 12) hour = 0;
        when = DateTime(now.year, now.month, now.day, hour, minute);
        if (lower.contains('tomorrow')) when = when.add(const Duration(days: 1));
        if (when.isBefore(now)) when = when.add(const Duration(days: 1));
      }
    }
    if (when == null) return null;
    final task = message
        .replaceAll(RegExp(r'\b(call me|remind me|ring me|schedule|tomorrow|at\s+\d{1,2}(?::\d{2})?\s*(?:am|pm)?|in\s+\d+\s+minutes?)\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return Reminder(task: task.isEmpty ? 'Your scheduled conversation' : task, scheduledAt: when, lastConversationSummary: summary);
  }

  static String _languageName(String code) {
    switch (code) {
      case 'fr-FR': return 'French';
      case 'es-ES': return 'Spanish';
      case 'zh-CN': return 'Mandarin Chinese';
      case 'de-DE': return 'German';
      case 'sw-KE': return 'Swahili';
      default: return 'English';
    }
  }

  static String buildGreeting(Contact contact, String userName, String summary) {
    if (contact.languageCode != 'en-US') {
      switch (contact.languageCode) {
        case 'fr-FR': return 'Salut $userName, je suis ${contact.name}. Comment vas-tu ?';
        case 'es-ES': return 'Hola $userName, soy ${contact.name}. ¿Cómo estás?';
        case 'zh-CN': return '嗨，$userName，我是${contact.name}。最近怎么样？';
        case 'de-DE': return 'Hey $userName, hier ist ${contact.name}. Wie geht es dir?';
        case 'sw-KE': return 'Habari $userName, ni ${contact.name}. Ukoje leo?';
      }
    }
    if (summary.isNotEmpty) {
      switch (contact.id) {
        case 1: return "Yo $userName! Good to hear from you again. What's good?";
        case 2: return "Hey $userName! Let's get it! What are we working on today?";
        case 3: return "Hey $userName, I'm glad you called. How are you feeling today?";
        case 4: return "Omg $userName! Finally! I have so much to tell you. But you first — what's up?";
      }
    }
    switch (contact.id) {
      case 1: return "Yo $userName! You called. What's good?";
      case 2: return "Hey $userName! Mike here. Let's get this energy up — what's going on?";
      case 3: return "Hi $userName, this is Zara. I'm here for you. What's on your mind?";
      case 4: return "Hey $userName! Nala speaking. Okay spill — what's the tea?";
      default: return "Hey $userName! Good to hear from you.";
    }
  }
}
