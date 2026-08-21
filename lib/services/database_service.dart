import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/message.dart';
import '../models/reminder.dart';
import '../models/contact.dart';
import '../models/call_log.dart';
import '../models/chat_message.dart';

class DatabaseService {
  static Database? _db;

  static Future<void> init() async {
    final dbPath = await getDatabasesPath();
    _db = await openDatabase(
      join(dbPath, 'ben.db'),
      version: 3,
      onCreate: (db, version) async {
        await _createTables(db);
        await _insertDefaultContacts(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await _createTables(db);
        await _insertDefaultContacts(db);
      },
    );
  }

  static Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS contacts (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        specialty TEXT NOT NULL,
        gender TEXT NOT NULL,
        avatar_color TEXT NOT NULL,
        photo_path TEXT,
        system_prompt TEXT NOT NULL,
        last_called_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        contact_id INTEGER NOT NULL,
        role TEXT NOT NULL,
        content TEXT NOT NULL,
        timestamp TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS chat_messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        contact_id INTEGER NOT NULL,
        type TEXT NOT NULL,
        text TEXT,
        audio_path TEXT,
        audio_duration INTEGER,
        is_me INTEGER NOT NULL,
        timestamp TEXT NOT NULL,
        read INTEGER DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS call_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        contact_id INTEGER NOT NULL,
        direction TEXT NOT NULL,
        status TEXT NOT NULL,
        started_at TEXT NOT NULL,
        duration_seconds INTEGER DEFAULT 0,
        note TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS reminders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        contact_id INTEGER NOT NULL DEFAULT 1,
        task TEXT NOT NULL,
        scheduled_at TEXT NOT NULL,
        fired INTEGER DEFAULT 0,
        last_conversation_summary TEXT
      )
    ''');
  }

  static Future<void> _insertDefaultContacts(Database db) async {
    final existing = await db.query('contacts');
    if (existing.isNotEmpty) return;
    for (final c in Contact.defaults()) {
      await db.insert('contacts', c.toMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  static Database get db => _db!;

  static Future<List<Contact>> getContacts() async {
    final rows = await db.query('contacts', orderBy: 'id ASC');
    return rows.map((r) => Contact.fromMap(r)).toList();
  }

  static Future<Contact?> getContact(int id) async {
    final rows = await db.query('contacts', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Contact.fromMap(rows.first);
  }

  static Future<void> updateContact(Contact contact) async {
    await db.update('contacts', contact.toMap(),
        where: 'id = ?', whereArgs: [contact.id]);
  }

  static Future<int> addContact(Contact contact) async {
    return db.insert('contacts', contact.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> updateLastCalled(int contactId) async {
    await db.update(
      'contacts',
      {'last_called_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [contactId],
    );
  }

  static Future<void> saveMessage(Message msg, int contactId) async {
    final map = msg.toDbMap();
    map['contact_id'] = contactId;
    await db.insert('messages', map);
  }

  static Future<List<Message>> getRecentMessages(int contactId, {int limit = 20}) async {
    final rows = await db.query(
      'messages',
      where: 'contact_id = ?',
      whereArgs: [contactId],
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return rows.reversed.map((r) => Message.fromMap(r)).toList();
  }

  static Future<int> saveChatMessage(ChatMessage message) async {
    return db.insert('chat_messages', message.toMap());
  }

  static Future<List<ChatMessage>> getChatMessages(int contactId) async {
    final rows = await db.query('chat_messages', where: 'contact_id = ?', whereArgs: [contactId], orderBy: 'timestamp ASC');
    return rows.map((row) => ChatMessage.fromMap(row)).toList();
  }

  static Future<ChatMessage?> getLastChatMessage(int contactId) async {
    final rows = await db.query('chat_messages', where: 'contact_id = ?', whereArgs: [contactId], orderBy: 'timestamp DESC', limit: 1);
    if (rows.isEmpty) return null;
    return ChatMessage.fromMap(rows.first);
  }

  static Future<int> getUnreadCount(int contactId) async {
    final result = await db.rawQuery('SELECT COUNT(*) AS count FROM chat_messages WHERE contact_id = ? AND is_me = 0 AND read = 0', [contactId]);
    return (result.first['count'] as int?) ?? 0;
  }

  static Future<void> markAllRead(int contactId) async {
    await db.update('chat_messages', {'read': 1}, where: 'contact_id = ?', whereArgs: [contactId]);
  }

  static Future<String> getConversationSummary(int contactId) async {
    final rows = await db.query(
      'messages',
      where: 'contact_id = ?',
      whereArgs: [contactId],
      orderBy: 'timestamp DESC',
      limit: 30,
    );
    if (rows.isEmpty) return '';
    return rows.reversed.map((r) => '${r['role']}: ${r['content']}').join('\n');
  }

  static Future<int> saveReminder(Reminder reminder, int contactId) async {
    final map = reminder.toMap();
    map['contact_id'] = contactId;
    return await db.insert('reminders', map);
  }

  static Future<Reminder?> getReminder(int id) async {
    final rows = await db.query('reminders', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Reminder.fromMap(rows.first);
  }

  static Future<List<Reminder>> getPendingReminders() async {
    final rows = await db.query('reminders', where: 'fired = 0', orderBy: 'scheduled_at ASC');
    return rows.map((r) => Reminder.fromMap(r)).toList();
  }

  static Future<void> markReminderFired(int id) async {
    await db.update('reminders', {'fired': 1}, where: 'id = ?', whereArgs: [id]);
  }

  static Future<int> saveCallLog(CallLog log) async {
    return db.insert('call_logs', log.toMap());
  }

  static Future<void> updateCallLog(int id, {String? status, int? durationSeconds, String? note}) async {
    final values = <String, dynamic>{};
    if (status != null) values['status'] = status;
    if (durationSeconds != null) values['duration_seconds'] = durationSeconds;
    if (note != null) values['note'] = note;
    if (values.isNotEmpty) await db.update('call_logs', values, where: 'id = ?', whereArgs: [id]);
  }

  static Future<List<CallLog>> getCallLogs({int limit = 50}) async {
    final rows = await db.query('call_logs', orderBy: 'started_at DESC', limit: limit);
    return rows.map((row) => CallLog.fromMap(row)).toList();
  }
}
