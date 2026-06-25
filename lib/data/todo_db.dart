import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';

import 'dart:io';

class TodoDB {
  static final TodoDB instance = TodoDB._internal();
  TodoDB._internal();

  late Database db;

  Future<void> init() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dir = await getApplicationSupportDirectory();
    final path = '${dir.path}/avelo.db';

    db = await openDatabase(
      path,
      version: 8,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE todos (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT NOT NULL,
            text TEXT NOT NULL,
            tag TEXT,
            done INTEGER NOT NULL DEFAULT 0,
            position INTEGER NOT NULL DEFAULT 0,
            recurring TEXT DEFAULT 'none',
            reminder_time TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS timer_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT NOT NULL,
            type TEXT NOT NULL,
            seconds INTEGER NOT NULL,
            task_id INTEGER,
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS subtasks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            todo_id INTEGER NOT NULL,
            text TEXT NOT NULL,
            done INTEGER NOT NULL DEFAULT 0,
            position INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS settings (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
      },
      onUpgrade: (db, old, _) async {
        if (old < 2) {
          await db.execute('ALTER TABLE todos ADD COLUMN tag TEXT');
          await db.execute('ALTER TABLE todos ADD COLUMN position INTEGER');
        }
        if (old < 3) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS timer_logs (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              date TEXT NOT NULL,
              type TEXT NOT NULL,
              seconds INTEGER NOT NULL,
              created_at TEXT NOT NULL
            )
          ''');
        }
        if (old < 4) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS settings (
              key TEXT PRIMARY KEY,
              value TEXT NOT NULL
            )
          ''');
        }
        if (old < 5) {
          await db.execute('ALTER TABLE timer_logs ADD COLUMN task_id INTEGER');
        }
        if (old < 6) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS subtasks (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              todo_id INTEGER NOT NULL,
              text TEXT NOT NULL,
              done INTEGER NOT NULL DEFAULT 0,
              position INTEGER NOT NULL DEFAULT 0
            )
          ''');
        }
        if (old < 7) {
          await db.execute('ALTER TABLE todos ADD COLUMN recurring TEXT DEFAULT "none"');
        }
        if (old < 8) {
          await db.execute('ALTER TABLE todos ADD COLUMN reminder_time TEXT');
        }
      },
    );
  }

  Future<List<Map<String, dynamic>>> getTodos(String date) async {
    return await db.rawQuery('''
      SELECT todos.*, 
        (SELECT COUNT(*) FROM subtasks WHERE todo_id = todos.id) as subtask_count,
        (SELECT COUNT(*) FROM subtasks WHERE todo_id = todos.id AND done = 1) as subtask_done_count
      FROM todos
      WHERE date = ?
      ORDER BY position ASC, id ASC
    ''', [date]);
  }

  Future<void> addTodo(String date, String text, String tag) async {
    final res = await db.rawQuery(
      'SELECT MAX(position) as maxPos FROM todos WHERE date = ?',
      [date],
    );

    final maxPos = res.isNotEmpty && res.first['maxPos'] != null
        ? res.first['maxPos'] as int
        : 0;

    await db.insert('todos', {
      'date': date,
      'text': text,
      'tag': tag,
      'position': maxPos + 1,
      'done': 0,
    });
  }

  Future<void> reorder(int id, int newPos) async {
    await db.update(
      'todos',
      {'position': newPos},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateTodo({
    required int id,
    required String text,
    required String tag,
    String recurring = 'none',
    String? reminderTime,
  }) async {
    await db.update(
      'todos',
      {'text': text, 'tag': tag, 'recurring': recurring, 'reminder_time': reminderTime},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteTodo(int id) async {
    await db.delete('todos', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> toggleDone(int id, bool done) async {
    await db.update(
      'todos',
      {'done': done ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );

    if (done) {
      final rows = await db.query('todos', where: 'id = ?', whereArgs: [id]);
      if (rows.isNotEmpty) {
        final todo = rows.first;
        final recurring = todo['recurring'] as String? ?? 'none';
        if (recurring != 'none') {
          final currentDateStr = todo['date'] as String;
          final currentDate = DateTime.parse(currentDateStr);
          DateTime nextDate;
          if (recurring == 'daily') {
            nextDate = currentDate.add(const Duration(days: 1));
          } else if (recurring == 'weekly') {
            nextDate = currentDate.add(const Duration(days: 7));
          } else if (recurring == 'monthly') {
            nextDate = DateTime(currentDate.year, currentDate.month + 1, currentDate.day);
          } else {
            return;
          }
          final nextDateStr = nextDate.toIso8601String().split('T')[0];

          // Check if already exists to prevent infinite duplicates
          final existing = await db.query('todos', where: 'date = ? AND text = ?', whereArgs: [nextDateStr, todo['text']]);
          if (existing.isEmpty) {
            final newId = await db.insert('todos', {
              'date': nextDateStr,
              'text': todo['text'],
              'tag': todo['tag'],
              'done': 0,
              'position': todo['position'],
              'recurring': recurring,
              'reminder_time': todo['reminder_time'],
            });

            // copy subtasks
            final subtasks = await getSubtasks(id);
            for (final st in subtasks) {
              await addSubtask(newId, st['text'] as String);
            }
          }
        }
      }
    }
  }

  Future<void> setSetting(String key, String value) async {
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getSetting(String key) async {
    final rows = await db.query(
      'settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value']?.toString();
  }

  Future<void> addTimerLog({
    required String date,
    required String type,
    required int seconds,
    int? taskId,
  }) async {
    await db.insert('timer_logs', {
      'date': date,
      'type': type,
      'seconds': seconds,
      'task_id': taskId,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<Map<String, int>> getTimerTotalsForDate(String date) async {
    final rows = await db.rawQuery(
      '''
      SELECT type, COALESCE(SUM(seconds), 0) as total
      FROM timer_logs
      WHERE date = ?
      GROUP BY type
      ''',
      [date],
    );

    int work = 0;
    int brk = 0;

    for (final row in rows) {
      final type = row['type']?.toString() ?? '';
      final value = (row['total'] as num?)?.toInt() ?? 0;
      if (type == 'work') work = value;
      if (type == 'break') brk = value;
    }

    return {'work': work, 'break': brk, 'total': work + brk};
  }

  Future<List<Map<String, dynamic>>> getTimerDailyStats({
    int limit = 14,
  }) async {
    return db.rawQuery(
      '''
      SELECT
        date,
        COALESCE(SUM(CASE WHEN type = 'work' THEN seconds ELSE 0 END), 0) as work_seconds,
        COALESCE(SUM(CASE WHEN type = 'break' THEN seconds ELSE 0 END), 0) as break_seconds
      FROM timer_logs
      GROUP BY date
      ORDER BY date DESC
      LIMIT ?
      ''',
      [limit],
    );
  }

  Future<List<String>> getUniqueTags() async {
    final rows = await db.rawQuery("SELECT DISTINCT tag FROM todos WHERE tag IS NOT NULL AND tag != ''");
    return rows.map((r) => r['tag'] as String).toList();
  }

  Future<List<Map<String, dynamic>>> getTimeSpentPerTag(int days) async {
    final date = DateTime.now().subtract(Duration(days: days));
    final dateStr = date.toIso8601String().split('T')[0];
    
    return await db.rawQuery('''
      SELECT t.tag, SUM(l.seconds) as total_seconds
      FROM timer_logs l
      INNER JOIN todos t ON l.task_id = t.id
      WHERE l.date >= ? AND l.type = 'work' AND t.tag IS NOT NULL AND t.tag != ''
      GROUP BY t.tag
      ORDER BY total_seconds DESC
    ''', [dateStr]);
  }

  // --- Subtasks ---

  Future<List<Map<String, dynamic>>> getSubtasks(int todoId) async {
    return await db.query('subtasks', where: 'todo_id = ?', whereArgs: [todoId], orderBy: 'position ASC, id ASC');
  }

  Future<void> addSubtask(int todoId, String text) async {
    final rows = await db.rawQuery('SELECT COUNT(*) FROM subtasks WHERE todo_id = ?', [todoId]);
    final count = rows.isNotEmpty ? (rows.first.values.first as num).toInt() : 0;
    await db.insert('subtasks', {'todo_id': todoId, 'text': text, 'done': 0, 'position': count});
  }

  Future<void> updateSubtaskText(int id, String text) async {
    await db.update('subtasks', {'text': text}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> toggleSubtaskDone(int id, bool done) async {
    await db.update('subtasks', {'done': done ? 1 : 0}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteSubtask(int id) async {
    await db.delete('subtasks', where: 'id = ?', whereArgs: [id]);
  }
}
