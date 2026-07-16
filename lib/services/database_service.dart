import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/message.dart';
import '../models/reminder.dart';
import '../models/contact.dart';

class DatabaseService {
  static Database? _db;

  static Future<void> init() async {
    final dbPath = await getDatabasesPath();
    _db = await openDatabase(
      join(dbPath, 'ben.db'),
      version: 2,
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

  static Future<List<Reminder>> getPendingReminders() async {
    final rows = await db.query('reminders', where: 'fired = 0', orderBy: 'scheduled_at ASC');
    return rows.map((r) => Reminder.fromMap(r)).toList();
  }

  static Future<void> markReminderFired(int id) async {
    await db.update('reminders', {'fired': 1}, where: 'id = ?', whereArgs: [id]);
  }
}
