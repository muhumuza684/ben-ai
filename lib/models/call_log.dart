class CallLog {
  final int? id;
  final int contactId;
  final String direction;
  final String status;
  final DateTime startedAt;
  final int durationSeconds;
  final String? note;

  const CallLog({
    this.id,
    required this.contactId,
    required this.direction,
    required this.status,
    required this.startedAt,
    this.durationSeconds = 0,
    this.note,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'contact_id': contactId,
    'direction': direction,
    'status': status,
    'started_at': startedAt.toIso8601String(),
    'duration_seconds': durationSeconds,
    'note': note,
  };

  factory CallLog.fromMap(Map<String, dynamic> map) => CallLog(
    id: map['id'],
    contactId: map['contact_id'] as int,
    direction: map['direction'] as String,
    status: map['status'] as String,
    startedAt: DateTime.parse(map['started_at'] as String),
    durationSeconds: (map['duration_seconds'] as int?) ?? 0,
    note: map['note'] as String?,
  );
}
