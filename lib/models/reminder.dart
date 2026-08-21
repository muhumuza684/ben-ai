class Reminder {
  final int? id;
  final int? contactId;
  final String task;
  final DateTime scheduledAt;
  final bool fired;
  final String? lastConversationSummary;

  Reminder({
    this.id,
    this.contactId,
    required this.task,
    required this.scheduledAt,
    this.fired = false,
    this.lastConversationSummary,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'contact_id': contactId,
    'task': task,
    'scheduled_at': scheduledAt.toIso8601String(),
    'fired': fired ? 1 : 0,
    'last_conversation_summary': lastConversationSummary,
  };

  factory Reminder.fromMap(Map<String, dynamic> m) => Reminder(
    id: m['id'],
    contactId: m['contact_id'],
    task: m['task'],
    scheduledAt: DateTime.parse(m['scheduled_at']),
    fired: m['fired'] == 1,
    lastConversationSummary: m['last_conversation_summary'],
  );
}
