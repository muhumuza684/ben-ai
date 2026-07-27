class ChatMessage {
  final int? id;
  final int contactId;
  final String type;
  final String? text;
  final String? audioPath;
  final int? audioDuration;
  final bool isMe;
  final DateTime timestamp;
  final bool read;

  ChatMessage({
    this.id,
    required this.contactId,
    required this.type,
    this.text,
    this.audioPath,
    this.audioDuration,
    required this.isMe,
    DateTime? timestamp,
    this.read = false,
  }) : timestamp = timestamp ?? DateTime.now();

  String get timeLabel {
    final h = timestamp.hour;
    final m = timestamp.minute.toString().padLeft(2, '0');
    final period = h >= 12 ? 'pm' : 'am';
    final hour = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$hour:$m $period';
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'contact_id': contactId,
    'type': type,
    'text': text,
    'audio_path': audioPath,
    'audio_duration': audioDuration,
    'is_me': isMe ? 1 : 0,
    'timestamp': timestamp.toIso8601String(),
    'read': read ? 1 : 0,
  };

  factory ChatMessage.fromMap(Map<String, dynamic> m) => ChatMessage(
    id: m['id'],
    contactId: m['contact_id'],
    type: m['type'],
    text: m['text'],
    audioPath: m['audio_path'],
    audioDuration: m['audio_duration'],
    isMe: m['is_me'] == 1,
    timestamp: DateTime.parse(m['timestamp']),
    read: m['read'] == 1,
  );
}