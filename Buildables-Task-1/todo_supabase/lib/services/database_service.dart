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

      return await openDatabase(path, version: 1, onCreate: _onCreate);
    } catch (e) {
      // Fallback for any platform issues
      return await openDatabase(
        'todo_database.db',
        version: 1,
        onCreate: _onCreate,
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
        synced INTEGER NOT NULL DEFAULT 0,
        deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');
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
        'name': task.name,
        'description': task.description,
        'category': task.category,
        'completed': task.completed ? 1 : 0,
        'created_at': task.createdAt.toIso8601String(),
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
            'name': t.name,
            'description': t.description,
            'category': t.category,
            'completed': t.completed,
            'created_at': t.createdAt.toIso8601String(),
            'synced': isSynced ? 1 : 0,
            'deleted': 0,
          },
        )
        .toList();

    await prefs.setString('tasks', jsonEncode(tasksJson));
    return 1;
  }

  Future<int> updateTask(Task task) async {
    if (kIsWeb) {
      return await _updateTaskWeb(task);
    } else {
      final db = await database;
      if (db == null) return 0;

      final taskMap = {
        'name': task.name,
        'description': task.description,
        'category': task.category,
        'completed': task.completed ? 1 : 0,
        'synced': 0,
        'deleted': 0,
      };
      return await db.update(
        'tasks',
        taskMap,
        where: 'id = ?',
        whereArgs: [task.id],
      );
    }
  }

  Future<int> _updateTaskWeb(Task task) async {
    final prefs = await this.prefs;
    final tasks = await getAllTasks();

    final index = tasks.indexWhere((t) => t.id == task.id);
    if (index != -1) {
      tasks[index] = task;

      final tasksJson = tasks
          .map(
            (t) => {
              'id': t.id,
              'name': t.name,
              'description': t.description,
              'category': t.category,
              'completed': t.completed,
              'created_at': t.createdAt.toIso8601String(),
              'synced': 0,
              'deleted': 0,
            },
          )
          .toList();

      await prefs.setString('tasks', jsonEncode(tasksJson));
      return 1;
    }
    return 0;
  }

  Future<int> deleteTask(int id) async {
    if (kIsWeb) {
      return await _deleteTaskWeb(id);
    } else {
      final db = await database;
      if (db == null) return 0;

      return await db.update(
        'tasks',
        {'deleted': 1, 'synced': 0},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  Future<int> _deleteTaskWeb(int id) async {
    final prefs = await this.prefs;
    final tasks = await getAllTasks();

    tasks.removeWhere((task) => task.id == id);

    final tasksJson = tasks
        .map(
          (t) => {
            'id': t.id,
            'name': t.name,
            'description': t.description,
            'category': t.category,
            'completed': t.completed,
            'created_at': t.createdAt.toIso8601String(),
            'synced': 0,
            'deleted': 0,
          },
        )
        .toList();

    await prefs.setString('tasks', jsonEncode(tasksJson));
    return 1;
  }

  Future<int> toggleTaskCompletion(int id, bool completed) async {
    if (kIsWeb) {
      return await _toggleTaskCompletionWeb(id, completed);
    } else {
      final db = await database;
      if (db == null) return 0;

      return await db.update(
        'tasks',
        {'completed': completed ? 1 : 0, 'synced': 0},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  Future<int> _toggleTaskCompletionWeb(int id, bool completed) async {
    final prefs = await this.prefs;
    final tasks = await getAllTasks();

    final index = tasks.indexWhere((t) => t.id == id);
    if (index != -1) {
      tasks[index] = tasks[index].copyWith(completed: completed);

      final tasksJson = tasks
          .map(
            (t) => {
              'id': t.id,
              'name': t.name,
              'description': t.description,
              'category': t.category,
              'completed': t.completed,
              'created_at': t.createdAt.toIso8601String(),
              'synced': 0,
              'deleted': 0,
            },
          )
          .toList();

      await prefs.setString('tasks', jsonEncode(tasksJson));
      return 1;
    }
    return 0;
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
          name: maps[i]['name'],
          description: maps[i]['description'],
          category: maps[i]['category'],
          completed: maps[i]['completed'] == 1,
          createdAt: DateTime.parse(maps[i]['created_at']),
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
            name: json['name'],
            description: json['description'],
            category: json['category'],
            completed: json['completed'],
            createdAt: DateTime.parse(json['created_at']),
          ),
        )
        .toList();
  }

  Future<List<Task>> getUnsyncedTasks() async {
    if (kIsWeb) {
      final tasks = await _getAllTasksWeb();
      return tasks
          .where(
            (task) => task.id < 0,
          ) // Only tasks with negative IDs (offline-created)
          .toList();
    } else {
      final db = await database;
      if (db == null) return [];

      final List<Map<String, dynamic>> maps = await db.query(
        'tasks',
        where: 'synced = ? AND deleted = ?',
        whereArgs: [0, 0],
      );

      return List.generate(maps.length, (i) {
        return Task(
          id: maps[i]['id'],
          name: maps[i]['name'],
          description: maps[i]['description'],
          category: maps[i]['category'],
          completed: maps[i]['completed'] == 1,
          createdAt: DateTime.parse(maps[i]['created_at']),
        );
      });
    }
  }

  Future<void> markAsSynced(int id) async {
    if (kIsWeb) {
      // For web, we don't need to track sync status as detailed
      return;
    } else {
      final db = await database;
      if (db != null) {
        await db.update(
          'tasks',
          {'synced': 1},
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    }
  }

  Future<void> markAsUnsynced(int id) async {
    if (kIsWeb) {
      // For web, we don't need to track sync status as detailed
      return;
    } else {
      final db = await database;
      if (db != null) {
        await db.update(
          'tasks',
          {'synced': 0},
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    }
  }

  Future<List<Task>> getDeletedTasks() async {
    if (kIsWeb) {
      // For web, return empty list as we don't track deleted tasks separately
      return [];
    } else {
      final db = await database;
      if (db == null) return [];

      final List<Map<String, dynamic>> maps = await db.query(
        'tasks',
        where: 'deleted = ?',
        whereArgs: [1],
      );

      return List.generate(maps.length, (i) {
        return Task(
          id: maps[i]['id'],
          name: maps[i]['name'],
          description: maps[i]['description'],
          category: maps[i]['category'],
          completed: maps[i]['completed'] == 1,
          createdAt: DateTime.parse(maps[i]['created_at']),
        );
      });
    }
  }

  Future<void> permanentlyDeleteTask(int id) async {
    if (kIsWeb) {
      // For web, we don't need to permanently delete
      return;
    } else {
      final db = await database;
      if (db != null) {
        await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
      }
    }
  }

  Future<void> clearDeletedTasks() async {
    if (kIsWeb) {
      // For web, we don't need to clear deleted tasks
      return;
    } else {
      final db = await database;
      if (db != null) {
        await db.delete('tasks', where: 'deleted = ?', whereArgs: [1]);
      }
    }
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
