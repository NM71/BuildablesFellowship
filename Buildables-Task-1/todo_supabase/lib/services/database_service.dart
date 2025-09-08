import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../providers/task_provider.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;
  static SharedPreferences? _prefs;

  factory DatabaseService() => _instance;

  DatabaseService._internal();

  Future<Database?> get database async {
    if (_database != null) return _database!;
    if (!kIsWeb) {
      _database = await _initDatabase();
    }
    return _database;
  }

  Future<SharedPreferences> get prefs async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  Future<Database> _initDatabase() async {
    try {
      final documentsDirectory = await getApplicationDocumentsDirectory();
      final path = join(documentsDirectory.path, 'todo_database.db');

      return await openDatabase(
        path,
        version: 2,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
    } catch (e) {
      // Fallback for any platform issues
      return await openDatabase(
        'todo_database.db',
        version: 2,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE tasks(
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        category TEXT NOT NULL,
        completed INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        owner_id TEXT DEFAULT '',
        synced INTEGER NOT NULL DEFAULT 0,
        deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE tasks ADD COLUMN owner_id TEXT DEFAULT ""');
    }
  }

  // CRUD Operations
  Future<int> insertTask(Task task, {bool isSynced = true}) async {
    if (kIsWeb) {
      return await _insertTaskWeb(task, isSynced: isSynced);
    } else {
      final db = await database;
      if (db == null) return 0;

      final taskMap = {
        'id': task.id,
        'name': task.title, // Changed from task.name to task.title
        'description': task.description,
        'category': task.category,
        'completed': task.completed ? 1 : 0,
        'created_at': task.createdAt.toIso8601String(),
        'owner_id': task.ownerId,
        'synced': isSynced ? 1 : 0,
        'deleted': 0,
      };
      return await db.insert(
        'tasks',
        taskMap,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<int> _insertTaskWeb(Task task, {bool isSynced = true}) async {
    final prefs = await this.prefs;
    final tasks = await getAllTasks();
    tasks.add(task);

    final tasksJson = tasks
        .map(
          (t) => {
            'id': t.id,
            'name': t.title, // Changed from t.name to t.title
            'description': t.description,
            'category': t.category,
            'completed': t.completed,
            'created_at': t.createdAt.toIso8601String(),
            'owner_id': t.ownerId,
            'synced': isSynced ? 1 : 0,
            'deleted': 0,
          },
        )
        .toList();

    await prefs.setString('tasks', jsonEncode(tasksJson));
    return 1;
  }

  Future<List<Task>> getAllTasks() async {
    if (kIsWeb) {
      return await _getAllTasksWeb();
    } else {
      final db = await database;
      if (db == null) return [];

      final List<Map<String, dynamic>> maps = await db.query(
        'tasks',
        where: 'deleted = ?',
        whereArgs: [0],
      );

      return List.generate(maps.length, (i) {
        return Task(
          id: maps[i]['id'],
          title: maps[i]['name'], // Changed from 'name' to 'title'
          description: maps[i]['description'],
          category: maps[i]['category'],
          completed: maps[i]['completed'] == 1,
          createdAt: DateTime.parse(maps[i]['created_at']),
          ownerId: maps[i]['owner_id'] ?? '', // Fallback for old data
        );
      });
    }
  }

  Future<List<Task>> _getAllTasksWeb() async {
    final prefs = await this.prefs;
    final tasksJson = prefs.getString('tasks');

    if (tasksJson == null) return [];

    final List<dynamic> tasksList = jsonDecode(tasksJson);
    return tasksList
        .map(
          (json) => Task(
            id: json['id'],
            title: json['name'], // Changed from 'name' to 'title'
            description: json['description'],
            category: json['category'],
            completed: json['completed'],
            createdAt: DateTime.parse(json['created_at']),
            ownerId: json['owner_id'] ?? '',
          ),
        )
        .toList();
  }

  Future<void> clearAllTasks() async {
    if (kIsWeb) {
      final prefs = await this.prefs;
      await prefs.remove('tasks');
    } else {
      final db = await database;
      if (db != null) {
        await db.delete('tasks');
      }
    }
  }

  Future<void> close() async {
    if (!kIsWeb) {
      final db = await database;
      db?.close();
    }
  }
}
