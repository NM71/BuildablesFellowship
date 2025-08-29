import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Task model
class Task {
  final int id;
  final String name;
  final String? description;
  final String category;
  final bool completed;
  final DateTime createdAt;

  Task({
    required this.id,
    required this.name,
    this.description,
    required this.category,
    required this.completed,
    required this.createdAt,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      category: json['category'] as String? ?? 'Other',
      completed: json['completed'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Task copyWith({
    int? id,
    String? name,
    String? description,
    String? category,
    bool? completed,
    DateTime? createdAt,
  }) {
    return Task(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      completed: completed ?? this.completed,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

// Loading states
enum TaskOperation { create, update, delete, toggle }

class TaskState {
  final List<Task> tasks;
  final bool isLoading;
  final bool isRefreshing;
  final TaskOperation? currentOperation;
  final String? error;

  TaskState({
    this.tasks = const [],
    this.isLoading = false,
    this.isRefreshing = false,
    this.currentOperation,
    this.error,
  });

  TaskState copyWith({
    List<Task>? tasks,
    bool? isLoading,
    bool? isRefreshing,
    TaskOperation? currentOperation,
    String? error,
  }) {
    return TaskState(
      tasks: tasks ?? this.tasks,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      currentOperation: currentOperation ?? this.currentOperation,
      error: error ?? this.error,
    );
  }
}

// Simple Task Notifier - just handles CRUD with Supabase
class TaskNotifier extends StateNotifier<TaskState> {
  TaskNotifier() : super(TaskState()) {
    _loadTasks();
  }

  final _supabase = Supabase.instance.client;
  bool _mounted = true;

  void _loadTasks() {
    // Load initial tasks from Supabase
    _fetchTasks();

    // Set up real-time subscription with error handling
    try {
      _supabase
          .from('todo')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false)
          .listen(
            (data) {
              if (!_mounted) return; // Check if disposed
              final tasks = data.map((json) => Task.fromJson(json)).toList();
              state = state.copyWith(tasks: tasks, isLoading: false);
            },
            onError: (error) {
              if (kDebugMode) {
                print('Realtime subscription error: $error');
              }
              // Don't update state on error to avoid breaking the UI
              state = state.copyWith(isLoading: false);
            },
          );
    } catch (e) {
      if (kDebugMode) {
        print('Failed to set up realtime subscription: $e');
      }
      // Continue without realtime updates
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> _fetchTasks() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _supabase
          .from('todo')
          .select()
          .order('created_at', ascending: false);

      final tasks = response.map((json) => Task.fromJson(json)).toList();
      state = state.copyWith(tasks: tasks, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  // Refresh tasks manually
  Future<void> refreshTasks() async {
    state = state.copyWith(isRefreshing: true, error: null);
    try {
      final response = await _supabase
          .from('todo')
          .select()
          .order('created_at', ascending: false);

      final tasks = response.map((json) => Task.fromJson(json)).toList();
      state = state.copyWith(tasks: tasks, isRefreshing: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isRefreshing: false);
    }
  }

  // Create task
  Future<String> createTask({
    required String name,
    String? description,
    required String category,
  }) async {
    state = state.copyWith(
      isLoading: true,
      currentOperation: TaskOperation.create,
      error: null,
    );

    try {
      final response = await _supabase
          .from('todo')
          .insert({
            'name': name,
            'description': description,
            'category': category,
            'completed': false,
          })
          .select()
          .single();

      final newTask = Task.fromJson(response);
      final updatedTasks = [newTask, ...state.tasks];
      state = state.copyWith(
        tasks: updatedTasks,
        isLoading: false,
        currentOperation: null,
      );
      return 'Task "${newTask.name}" added successfully';
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        currentOperation: null,
        error: e.toString(),
      );
      return 'Failed to add task: ${e.toString()}';
    }
  }

  // Update task
  Future<String> updateTask({
    required int id,
    required String name,
    String? description,
    required String category,
    required bool completed,
  }) async {
    state = state.copyWith(
      isLoading: true,
      currentOperation: TaskOperation.update,
      error: null,
    );

    try {
      await _supabase
          .from('todo')
          .update({
            'name': name,
            'description': description,
            'category': category,
            'completed': completed,
          })
          .eq('id', id);

      final updatedTask = Task(
        id: id,
        name: name,
        description: description,
        category: category,
        completed: completed,
        createdAt: DateTime.now(),
      );

      final updatedTasks = state.tasks.map((task) {
        return task.id == id ? updatedTask : task;
      }).toList();

      state = state.copyWith(
        tasks: updatedTasks,
        isLoading: false,
        currentOperation: null,
      );
      return 'Task updated to "$name"';
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        currentOperation: null,
        error: e.toString(),
      );
      return 'Failed to update task: ${e.toString()}';
    }
  }

  // Toggle completion
  Future<String> toggleTaskCompletion(int id, bool completed) async {
    state = state.copyWith(
      isLoading: true,
      currentOperation: TaskOperation.toggle,
      error: null,
    );

    try {
      await _supabase
          .from('todo')
          .update({'completed': completed})
          .eq('id', id);

      final updatedTasks = state.tasks.map((task) {
        return task.id == id ? task.copyWith(completed: completed) : task;
      }).toList();

      state = state.copyWith(
        tasks: updatedTasks,
        isLoading: false,
        currentOperation: null,
      );
      return completed ? 'Task marked as completed' : 'Task marked as pending';
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        currentOperation: null,
        error: e.toString(),
      );
      return 'Failed to update task: ${e.toString()}';
    }
  }

  // Delete task
  Future<String> deleteTask(int id) async {
    // Find task name for feedback
    final taskToDelete = state.tasks.firstWhere((task) => task.id == id);
    final taskName = taskToDelete.name;

    state = state.copyWith(
      isLoading: true,
      currentOperation: TaskOperation.delete,
      error: null,
    );

    try {
      await _supabase.from('todo').delete().eq('id', id);

      final updatedTasks = state.tasks.where((task) => task.id != id).toList();
      state = state.copyWith(
        tasks: updatedTasks,
        isLoading: false,
        currentOperation: null,
      );
      return 'Task "$taskName" deleted successfully';
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        currentOperation: null,
        error: e.toString(),
      );
      return 'Failed to delete task: ${e.toString()}';
    }
  }

  @override
  void dispose() {
    _mounted = false;
    super.dispose();
  }
}

// Providers
final taskProvider = StateNotifierProvider<TaskNotifier, TaskState>((ref) {
  return TaskNotifier();
});

// Filtered providers
final pendingTasksProvider = Provider<List<Task>>((ref) {
  final state = ref.watch(taskProvider);
  return state.tasks.where((task) => !task.completed).toList();
});

final completedTasksProvider = Provider<List<Task>>((ref) {
  final state = ref.watch(taskProvider);
  return state.tasks.where((task) => task.completed).toList();
});

// Loading state providers
final isCreatingTaskProvider = Provider<bool>((ref) {
  final state = ref.watch(taskProvider);
  return state.isLoading && state.currentOperation == TaskOperation.create;
});

final isUpdatingTaskProvider = Provider<bool>((ref) {
  final state = ref.watch(taskProvider);
  return state.isLoading && state.currentOperation == TaskOperation.update;
});

final isDeletingTaskProvider = Provider<bool>((ref) {
  final state = ref.watch(taskProvider);
  return state.isLoading && state.currentOperation == TaskOperation.delete;
});

final isTogglingTaskProvider = Provider<bool>((ref) {
  final state = ref.watch(taskProvider);
  return state.isLoading && state.currentOperation == TaskOperation.toggle;
});

// Refresh provider
final isRefreshingTasksProvider = Provider<bool>((ref) {
  final state = ref.watch(taskProvider);
  return state.isRefreshing;
});
