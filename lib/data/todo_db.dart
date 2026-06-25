import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class TodoDB {
  static final TodoDB instance = TodoDB._internal();
  TodoDB._internal();

  late Database db;

  Future<void> init() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    final dir = await getApplicationSupportDirectory();
    final path = '${dir.path}/pebble.db';

    db = await openDatabase(
      path,
      version: 4,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE todos (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT NOT NULL,
            text TEXT NOT NULL,
            tag TEXT,
            position INTEGER,
            done INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS timer_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT NOT NULL,
            type TEXT NOT NULL,
            seconds INTEGER NOT NULL,
            created_at TEXT NOT NULL
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
      },
    );
  }

  Future<List<Map<String, dynamic>>> getTodos(String date) async {
    return db.query(
      'todos',
      where: 'date = ?',
      whereArgs: [date],
      orderBy: 'position ASC',
    );
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

  Future<void> toggleDone(int id, bool done) async {
    await db.update(
      'todos',
      {'done': done ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteTodo(int id) async {
    await db.delete('todos', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateTodo({
    required int id,
    required String text,
    required String tag,
  }) async {
    await db.update(
      'todos',
      {'text': text, 'tag': tag},
      where: 'id = ?',
      whereArgs: [id],
    );
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
  }) async {
    await db.insert('timer_logs', {
      'date': date,
      'type': type,
      'seconds': seconds,
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
    final rows = await db.rawQuery('SELECT DISTINCT tag FROM todos WHERE tag IS NOT NULL AND tag != ""');
    return rows.map((r) => r['tag'] as String).toList();
  }
}
