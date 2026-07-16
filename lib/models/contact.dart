import 'dart:convert';

class Contact {
  final int id; // 1-4, fixed slots
  String name;
  String specialty;
  String gender; // 'male' or 'female'
  String avatarColor; // hex color string
  String? photoPath; // local file path if user set a photo
  String systemPrompt; // AI personality prompt
  DateTime? lastCalledAt;

  Contact({
    required this.id,
    required this.name,
    required this.specialty,
    required this.gender,
    required this.avatarColor,
    required this.systemPrompt,
    this.photoPath,
    this.lastCalledAt,
  });

  // Default 4 contacts
  static List<Contact> defaults() => [
    Contact(
      id: 1,
      name: 'Ben',
      specialty: 'Daily vibes & general chat',
      gender: 'male',
      avatarColor: '#1e3a2e',
      systemPrompt: '''You are Ben, a casual male AI best friend on a voice call.
Talk like a real friend — warm, funny, direct. Keep replies to 1-2 short sentences.
Never use bullet points. Never say you are an AI unless directly asked.
You are good at general conversation, daily life, and being a supportive friend.''',
    ),
    Contact(
      id: 2,
      name: 'Mike',
      specialty: 'Motivation & goals',
      gender: 'male',
      avatarColor: '#1e2a3a',
      systemPrompt: '''You are Mike, a hyped-up male AI friend on a voice call.
You are motivational, energetic, and always pushing people to be their best.
Talk like a gym bro who genuinely cares. Keep replies to 1-2 short sentences.
Never use bullet points. Never say you are an AI unless directly asked.
You are great at motivation, goals, hustle, and accountability.''',
    ),
    Contact(
      id: 3,
      name: 'Zara',
      specialty: 'Emotional support & listening',
      gender: 'female',
      avatarColor: '#3a1e2e',
      systemPrompt: '''You are Zara, a caring female AI friend on a voice call.
You are empathetic, warm, and an excellent listener. You make people feel heard.
Talk gently but honestly. Keep replies to 1-2 short sentences.
Never use bullet points. Never say you are an AI unless directly asked.
You are great at emotional support, relationships, and helping people process feelings.''',
    ),
    Contact(
      id: 4,
      name: 'Nala',
      specialty: 'Fun, gossip & entertainment',
      gender: 'female',
      avatarColor: '#3a2a1e',
      systemPrompt: '''You are Nala, a fun and sassy female AI friend on a voice call.
You are funny, playful, sometimes sarcastic, and great at keeping things light.
Talk like that one friend who always makes you laugh. Keep replies to 1-2 short sentences.
Never use bullet points. Never say you are an AI unless directly asked.
You are great at fun conversations, jokes, gossip, and entertainment.''',
    ),
  ];

  // Accent colors per contact
  String get accentColor {
    switch (id) {
      case 1: return '#4ade80';
      case 2: return '#60a5fa';
      case 3: return '#f472b6';
      case 4: return '#fb923c';
      default: return '#4ade80';
    }
  }

  String get initials => name.isNotEmpty ? name[0].toUpperCase() : '?';

  String get lastCalledLabel {
    if (lastCalledAt == null) return 'Never called';
    final diff = DateTime.now().difference(lastCalledAt!);
    if (diff.inMinutes < 60) return 'Called ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'Called ${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Called yesterday';
    return 'Called ${diff.inDays} days ago';
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'specialty': specialty,
    'gender': gender,
    'avatar_color': avatarColor,
    'photo_path': photoPath,
    'system_prompt': systemPrompt,
    'last_called_at': lastCalledAt?.toIso8601String(),
  };

  factory Contact.fromMap(Map<String, dynamic> m) => Contact(
    id: m['id'],
    name: m['name'],
    specialty: m['specialty'],
    gender: m['gender'],
    avatarColor: m['avatar_color'],
    systemPrompt: m['system_prompt'],
    photoPath: m['photo_path'],
    lastCalledAt: m['last_called_at'] != null
        ? DateTime.parse(m['last_called_at'])
        : null,
  );
}
