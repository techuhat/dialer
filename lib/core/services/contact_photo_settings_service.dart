import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/contact_photo_settings.dart';

/// Persists per-contact photo display settings using SQLite (sqflite).
class ContactPhotoSettingsService {
  static Database? _database;
  static const String _tableName = 'contact_photo_settings';


  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    final String path =
        join(await getDatabasesPath(), 'contact_photo_settings.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (Database db, int version) async {
        await db.execute('''
          CREATE TABLE $_tableName (
            contactId TEXT PRIMARY KEY,
            overlayOpacity REAL NOT NULL DEFAULT 0.35,
            rotation REAL NOT NULL DEFAULT 0,
            fitMode TEXT NOT NULL DEFAULT 'cover'
          )
        ''');
      },
    );
  }


  /// Returns settings for [contactId], or `null` if none saved.
  static Future<ContactPhotoSettings?> getSettings(String contactId) async {
    if (contactId.isEmpty) return null;
    final Database db = await database;
    final List<Map<String, dynamic>> rows = await db.query(
      _tableName,
      where: 'contactId = ?',
      whereArgs: <Object>[contactId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ContactPhotoSettings.fromMap(rows.first);
  }

  /// Inserts or replaces settings for a contact.
  static Future<void> saveSettings(ContactPhotoSettings settings) async {
    final Database db = await database;
    await db.insert(
      _tableName,
      settings.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Removes saved settings for a contact.
  static Future<void> deleteSettings(String contactId) async {
    if (contactId.isEmpty) return;
    final Database db = await database;
    await db.delete(
      _tableName,
      where: 'contactId = ?',
      whereArgs: <Object>[contactId],
    );
  }
}
