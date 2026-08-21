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
    final prompt = '''
Extract any reminder or scheduled call request from this message.
Message: "$userMessage"

If there is a reminder request reply with ONLY this JSON:
{"has_reminder":true,"task":"what to remind about","remind_at":"HH:MM"}

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

      final parts = (json['remind_at'] as String).split(':');
      final now = DateTime.now();
      var scheduledAt = DateTime(
        now.year, now.month, now.day,
        int.parse(parts[0]), int.parse(parts[1]),
      );
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
