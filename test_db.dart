import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  sqfliteFfiInit();
  var dbFactory = databaseFactoryFfi;
  final dbPath = '/home/grey/.local/share/com.example.avelo/avelo.db';
  if (!File(dbPath).existsSync()) {
    print('DB not found');
    return;
  }
  var db = await dbFactory.openDatabase(dbPath);
  try {
    var result = await db.rawQuery('SELECT DISTINCT tag FROM todos WHERE tag IS NOT NULL AND tag != ""');
    print(result);
  } catch (e) {
    print('Error: $e');
  }
  await db.close();
}
