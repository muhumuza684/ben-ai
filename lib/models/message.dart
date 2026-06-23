class Message {
  final String role;
  final String content;
  final DateTime timestamp;

  Message({
    required this.role,
    required this.content,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toApiMap() => {'role': role, 'content': content};

  Map<String, dynamic> toDbMap() => {
    'role': role,
    'content': content,
    'timestamp': timestamp.toIso8601String(),
  };

  factory Message.fromMap(Map<String, dynamic> m) => Message(
    role: m['role'],
    content: m['content'],
    timestamp: DateTime.parse(m['timestamp']),
  );
}
