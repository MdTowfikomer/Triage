import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  final dbPath = r'C:\Users\MD Towfik Omer\.gemini\antigravity-cli\brain\75c2bca9-b504-481d-a9e6-7e8509b5772c\triage_outbox_bin.db';
  final db = await openDatabase(dbPath, readOnly: true);
  print('=== Local Routines ===');
  final routines = await db.rawQuery('SELECT occurrence_id, name, status, scheduled_time, executed_at FROM local_routines');
  for (final r in routines) {
    print(r);
  }
  print('=== Routine Claims ===');
  final claims = await db.rawQuery('SELECT * FROM routine_claims');
  for (final c in claims) {
    print(c);
  }
  await db.close();
}
