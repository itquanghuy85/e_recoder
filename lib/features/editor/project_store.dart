import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'edit_project.dart';

final projectStoreProvider = Provider<ProjectStore>(
  (ref) => SqliteProjectStore(),
);

/// Where edit projects live between sessions, so an interrupted edit is never lost.
abstract class ProjectStore {
  Future<EditProject?> load(String id);
  Future<void> save(EditProject project);
  Future<void> delete(String id);
}

class SqliteProjectStore implements ProjectStore {
  Database? _db;

  Future<Database> _open() async {
    final existing = _db;
    if (existing != null) return existing;
    final path = p.join(await getDatabasesPath(), 'projects.db');
    final db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, v) => db.execute(
        'CREATE TABLE projects (id TEXT PRIMARY KEY, json TEXT NOT NULL, updatedAt INTEGER NOT NULL)',
      ),
    );
    return _db = db;
  }

  @override
  Future<EditProject?> load(String id) async {
    final db = await _open();
    final rows = await db.query(
      'projects',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    try {
      return EditProject.decode(rows.first['json'] as String);
    } catch (_) {
      // A project written by an incompatible build: start fresh rather than crash.
      return null;
    }
  }

  @override
  Future<void> save(EditProject project) async {
    final db = await _open();
    await db.insert('projects', {
      'id': project.id,
      'json': project.encode(),
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> delete(String id) async {
    final db = await _open();
    await db.delete('projects', where: 'id = ?', whereArgs: [id]);
  }
}

class MemoryProjectStore implements ProjectStore {
  final Map<String, String> data = {};

  @override
  Future<EditProject?> load(String id) async {
    final s = data[id];
    return s == null ? null : EditProject.decode(s);
  }

  @override
  Future<void> save(EditProject project) async =>
      data[project.id] = project.encode();

  @override
  Future<void> delete(String id) async => data.remove(id);
}
