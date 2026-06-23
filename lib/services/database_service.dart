import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/message.dart';
import '../models/reminder.dart';

class DatabaseService {
  static Database? _db;

  static Future<void> init() async {
    final dbPath = await getDatabasesPath();
    _db = await openDatabase(
      join(dbPath, 'ben.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE messages (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            role TEXT NOT NULL,
            content TEXT NOT NULL,
            timestamp TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE reminders (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            task TEXT NOT NULL,
            scheduled_at TEXT NOT NULL,
            fired INTEGER DEFAULT 0,
            last_conversation_summary TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE user_profile (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
      },
    );
  }

  static Database get db => _db!;

  static Future<void> saveMessage(Message msg) async {
    await db.insert('messages', msg.toDbMap());
  }

  static Future<List<Message>> getRecentMessages({int limit = 20}) async {
    final rows = await db.query('messages', orderBy: 'timestamp DESC', limit: limit);
    return rows.reversed.map((r) => Message.fromMap(r)).toList();
  }

  static Future<String> getConversationSummary() async {
    final rows = await db.query('messages', orderBy: 'timestamp DESC', limit: 30);
    if (rows.isEmpty) return '';
    return rows.reversed.map((r) => '${r['role']}: ${r['content']}').join('\n');
  }

  static Future<int> saveReminder(Reminder reminder) async {
    return await db.insert('reminders', reminder.toMap());
  }

  static Future<List<Reminder>> getPendingReminders() async {
    final rows = await db.query('reminders', where: 'fired = 0', orderBy: 'scheduled_at ASC');
    return rows.map((r) => Reminder.fromMap(r)).toList();
  }

  static Future<void> markReminderFired(int id) async {
    await db.update('reminders', {'fired': 1}, where: 'id = ?', whereArgs: [id]);
  }
}
