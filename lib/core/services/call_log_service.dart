import 'dart:async';
import 'dart:developer' as developer;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/call_log_entry.dart';
import 'contacts_service.dart';

class CallLogService {
  static Database? _database;
  static const String _tableName = 'call_logs';
  static final StreamController<void> _changeController = StreamController<void>.broadcast();

  static Stream<void> get changes => _changeController.stream;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    final String path = join(await getDatabasesPath(), 'call_logs.db');
    
    return await openDatabase(
      path,
      version: 1,
      onCreate: (Database db, int version) async {
        await db.execute('''
          CREATE TABLE $_tableName(
            id TEXT PRIMARY KEY,
            number TEXT NOT NULL,
            name TEXT,
            type INTEGER NOT NULL,
            timestamp INTEGER NOT NULL,
            duration INTEGER NOT NULL DEFAULT 0,
            isRead INTEGER NOT NULL DEFAULT 1
          )
        ''');
      },
    );
  }

  static Future<void> addCallLog(CallLogEntry entry) async {
    final db = await database;
    await db.insert(_tableName, entry.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    _notifyChange();
  }

  static Future<List<CallLogEntry>> getAllCallLogs({
    CallType? filterType,
    int? limit,
    int? offset,
  }) async {
    final db = await database;
    
    String query = 'SELECT * FROM $_tableName';
    List<dynamic> whereArgs = [];
    
    if (filterType != null) {
      query += ' WHERE type = ?';
      whereArgs.add(filterType.index);
    }
    
    query += ' ORDER BY timestamp DESC';
    
    if (limit != null) {
      query += ' LIMIT $limit';
      if (offset != null) {
        query += ' OFFSET $offset';
      }
    }

    final List<Map<String, dynamic>> maps = await db.rawQuery(query, whereArgs);
    final callLogs = maps.map((map) => CallLogEntry.fromMap(map)).toList();
    
    // Enrich with contact names
    return await _enrichWithContactNames(callLogs);
  }

  static Future<List<CallLogEntry>> _enrichWithContactNames(List<CallLogEntry> callLogs) async {
    try {
      // Check if we have contacts permission
      if (!await ContactsService.hasPermission()) {
        return callLogs;
      }

      final enrichedLogs = <CallLogEntry>[];
      
      for (final callLog in callLogs) {
        try {
          final contact = await ContactsService.getContactByNumber(callLog.number);
          if (contact != null && contact.displayName.isNotEmpty) {
            // Update the call log with the contact name
            final enrichedLog = CallLogEntry(
              id: callLog.id,
              number: callLog.number,
              name: contact.displayName,
              type: callLog.type,
              timestamp: callLog.timestamp,
              duration: callLog.duration,
              isRead: callLog.isRead,
            );
            enrichedLogs.add(enrichedLog);
          } else {
            enrichedLogs.add(callLog);
          }
        } catch (e) {
          developer.log('Error enriching call log ${callLog.id}: $e');
          enrichedLogs.add(callLog);
        }
      }
      
      return enrichedLogs;
    } catch (e) {
      developer.log('Error enriching call logs with contacts: $e');
      return callLogs;
    }
  }

  static Future<List<CallLogEntry>> getRecentCalls({int limit = 50}) async {
    return await getAllCallLogs(limit: limit);
  }

  static Future<List<CallLogEntry>> getMissedCalls() async {
    return await getAllCallLogs(filterType: CallType.missed);
  }

  static Future<List<CallLogEntry>> getCallLogsForNumber(String number) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'number = ?',
      whereArgs: [number],
      orderBy: 'timestamp DESC',
    );
    return maps.map((map) => CallLogEntry.fromMap(map)).toList();
  }

  static Future<int> getUnreadMissedCallsCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $_tableName WHERE type = ? AND isRead = 0',
      [CallType.missed.index],
    );
    return result.first['count'] as int;
  }

  static Future<void> markAllAsRead() async {
    final db = await database;
    await db.update(
      _tableName,
      {'isRead': 1},
      where: 'isRead = ?',
      whereArgs: [0],
    );
    _notifyChange();
  }

  static Future<void> markAsRead(String id) async {
    final db = await database;
    await db.update(
      _tableName,
      {'isRead': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
    _notifyChange();
  }

  static Future<void> deleteCallLog(String id) async {
    final db = await database;
    await db.delete(_tableName, where: 'id = ?', whereArgs: [id]);
    _notifyChange();
  }

  static Future<void> clearAllCallLogs() async {
    final db = await database;
    await db.delete(_tableName);
    _notifyChange();
  }

  static Future<Map<String, int>> getCallStatistics() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT 
        type,
        COUNT(*) as count,
        SUM(duration) as totalDuration
      FROM $_tableName 
      GROUP BY type
    ''');
    
    Map<String, int> stats = {
      'totalCalls': 0,
      'incomingCalls': 0,
      'outgoingCalls': 0,
      'missedCalls': 0,
      'totalDuration': 0,
    };

    for (final row in result) {
      final type = CallType.values[row['type'] as int];
      final count = row['count'] as int;
      final duration = row['totalDuration'] as int;
      
      stats['totalCalls'] = stats['totalCalls']! + count;
      stats['totalDuration'] = stats['totalDuration']! + duration;
      
      switch (type) {
        case CallType.incoming:
          stats['incomingCalls'] = count;
          break;
        case CallType.outgoing:
          stats['outgoingCalls'] = count;
          break;
        case CallType.missed:
          stats['missedCalls'] = count;
          break;
      }
    }

    return stats;
  }

  static void _notifyChange() {
    if (!_changeController.isClosed) {
      _changeController.add(null);
    }
  }
}