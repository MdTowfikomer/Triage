import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import '../outbox/uuid_util.dart';

class LocalNoteItem {
  final String id;
  final String content;
  final String category; // 'note', 'idea', 'reminder', 'shopping'
  final DateTime createdAt;
  final bool isSynced;

  const LocalNoteItem({
    required this.id,
    required this.content,
    required this.category,
    required this.createdAt,
    this.isSynced = false,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'content': content,
    'category': category,
    'created_at': createdAt.toIso8601String(),
    'is_synced': isSynced ? 1 : 0,
  };

  factory LocalNoteItem.fromRow(Row row) => LocalNoteItem(
    id: row['id'] as String,
    content: row['content'] as String,
    category: row['category'] as String,
    createdAt: DateTime.parse(row['created_at'] as String),
    isSynced: (row['is_synced'] as int? ?? 0) == 1,
  );
}

class LocalNotesRepository {
  Database? _db;

  Database get db {
    if (_db == null) {
      throw StateError('LocalNotesRepository is not initialized.');
    }
    return _db!;
  }

  bool get isOpen => _db != null;

  Future<void> initialize({Database? customDb, String? dbPath}) async {
    if (_db != null) return;
    if (customDb != null) {
      _db = customDb;
    } else {
      final path = dbPath ?? await _getDefaultDatabasePath();
      final file = File(path);
      if (!file.parent.existsSync()) {
        file.parent.createSync(recursive: true);
      }
      _db = sqlite3.open(path);
      _db!.execute('PRAGMA journal_mode = WAL;');
      _db!.execute('PRAGMA synchronous = NORMAL;');
    }
    _createSchema();
  }

  static Future<String> _getDefaultDatabasePath() async {
    final docsDir = await getApplicationDocumentsDirectory();
    return p.join(docsDir.path, 'triage_notes.db');
  }

  void _createSchema() {
    _db!.execute('''
      CREATE TABLE IF NOT EXISTS notes (
        id TEXT PRIMARY KEY,
        content TEXT NOT NULL,
        category TEXT NOT NULL,
        created_at TEXT NOT NULL,
        is_synced INTEGER NOT NULL DEFAULT 0
      );
      CREATE INDEX IF NOT EXISTS idx_notes_created ON notes(created_at DESC);
      CREATE INDEX IF NOT EXISTS idx_notes_category ON notes(category);
    ''');
  }

  Future<LocalNoteItem> createNote({
    required String content,
    required String category,
  }) async {
    final id = UuidUtil.generate();
    final now = DateTime.now().toUtc();
    final note = LocalNoteItem(
      id: id,
      content: content.trim(),
      category: category.toLowerCase().trim(),
      createdAt: now,
    );
    _db!.execute(
      '''
      INSERT INTO notes (id, content, category, created_at, is_synced)
      VALUES (?, ?, ?, ?, ?);
      ''',
      [note.id, note.content, note.category, note.createdAt.toIso8601String(), 0],
    );
    return note;
  }

  Future<List<LocalNoteItem>> getNotes({String? categoryQuery, String? searchQuery}) async {
    String sql = 'SELECT * FROM notes';
    final List<Object?> params = [];
    final List<String> conditions = [];

    if (categoryQuery != null && categoryQuery.isNotEmpty && categoryQuery.toLowerCase() != 'all') {
      conditions.add('category = ?');
      params.add(categoryQuery.toLowerCase());
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      conditions.add('content LIKE ?');
      params.add('%${searchQuery.trim()}%');
    }

    if (conditions.isNotEmpty) {
      sql += ' WHERE ${conditions.join(' AND ')}';
    }
    sql += ' ORDER BY created_at DESC;';

    final result = _db!.select(sql, params);
    return result.map(LocalNoteItem.fromRow).toList();
  }

  Future<void> deleteNote(String id) async {
    _db!.execute('DELETE FROM notes WHERE id = ?;', [id]);
  }

  Future<void> dispose() async {
    _db?.dispose();
    _db = null;
  }
}
