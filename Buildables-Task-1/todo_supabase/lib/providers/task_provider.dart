import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Collaborator model
class Collaborator {
  final String userId;
  final String email;
  final String role;
  final DateTime? invitedAt;
  final DateTime? acceptedAt;

  Collaborator({
    required this.userId,
    required this.email,
    required this.role,
    this.invitedAt,
    this.acceptedAt,
  });

  factory Collaborator.fromJson(Map<String, dynamic> json) {
    return Collaborator(
      userId: json['user_id'] as String,
      email: json['email'] as String,
      role: json['role'] as String? ?? 'collaborator',
      invitedAt: json['invited_at'] != null
          ? DateTime.parse(json['invited_at'] as String)
          : null,
      acceptedAt: json['accepted_at'] != null
          ? DateTime.parse(json['accepted_at'] as String)
          : null,
    );
  }

  bool get hasAccepted => acceptedAt != null;
  bool get isPending => acceptedAt == null;
}

// Task model - Updated for new database schema
class Task {
  final int id;
  final String title; // Changed from 'name' to 'title'
  final String? description;
  final String category;
  final bool completed;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String ownerId;
  final String? ownerEmail;
  final List<Collaborator> collaborators;

  Task({
    required this.id,
    required this.title, // Changed from 'name' to 'title'
    this.description,
    required this.category,
    required this.completed,
    required this.createdAt,
    this.updatedAt,
    required this.ownerId,
    this.ownerEmail,
    this.collaborators = const [],
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    // Parse collaborators from JSON array (if present)
    List<Collaborator> collaboratorsList = [];
    if (json['collaborators'] != null) {
      final collabData = json['collaborators'] as List;
      collaboratorsList = collabData
          .map(
            (collab) => Collaborator.fromJson(collab as Map<String, dynamic>),
          )
          .toList();
    }

    return Task(
      id: json['id'] as int,
      title: json['title'] as String, // Changed from 'name' to 'title'
      description: json['description'] as String?,
      category: json['category'] as String? ?? 'Other',
      completed: json['completed'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      ownerId: json['owner_id'] as String,
      ownerEmail: json['owner_email'] as String?, // May be null
      collaborators: collaboratorsList,
    );
  }

  Task copyWith({
    int? id,
    String? title, // Changed from 'name' to 'title'
    String? description,
    String? category,
    bool? completed,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? ownerId,
    String? ownerEmail,
    List<Collaborator>? collaborators,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title, // Changed from 'name' to 'title'
      description: description ?? this.description,
      category: category ?? this.category,
      completed: completed ?? this.completed,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      ownerId: ownerId ?? this.ownerId,
      ownerEmail: ownerEmail ?? this.ownerEmail,
      collaborators: collaborators ?? this.collaborators,
    );
  }

  // Helper methods
  bool isOwnedBy(String userId) => ownerId == userId;
  bool isCollaborator(String userId) =>
      collaborators.any((c) => c.userId == userId && c.hasAccepted);
  bool canEdit(String userId) => isOwnedBy(userId) || isCollaborator(userId);
  int get collaboratorCount => collaborators.where((c) => c.hasAccepted).length;
  int get pendingInvitations => collaborators.where((c) => c.isPending).length;

  // Getter for backward compatibility
  String get name => title;
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

  String get _currentUserId => _supabase.auth.currentUser?.id ?? '';
  bool _mounted = true;

  void _loadTasks() {
    // Load initial tasks from Supabase
    _fetchTasks();

    // DISABLE REAL-TIME SUBSCRIPTIONS to avoid RLS recursion
    // Real-time will be re-enabled once RLS policies are fixed
    if (kDebugMode) {
      print('⚠️  Real-time subscriptions DISABLED to prevent RLS recursion');
      print('💡 To re-enable: Fix RLS policies in Supabase dashboard');
    }
  }

  Future<void> _fetchTasks() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      if (kDebugMode) {
        print('=== FETCHING TASKS FOR USER: $_currentUserId ===');
      }

      // TEMPORARY WORKAROUND: Use direct queries with simple RLS policies
      // This avoids complex RLS recursion while we fix the policies

      // STEP 1: Fetch owned tasks (should work with simple policy)
      final ownedTasksResponse = await _supabase
          .from('tasks')
          .select()
          .eq('owner_id', _currentUserId)
          .order('created_at', ascending: false);

      if (kDebugMode) {
        print('✅ Owned tasks: ${ownedTasksResponse.length}');
      }

      final allTasks = <Task>[];

      // Add owned tasks
      for (final taskJson in ownedTasksResponse) {
        try {
          allTasks.add(Task.fromJson(taskJson));
        } catch (e) {
          if (kDebugMode) {
            print('❌ Error parsing owned task: $e');
          }
        }
      }

      // STEP 2: Fetch collaborated tasks using RPC function
      final collabTasksResponse = await _supabase.rpc(
        'get_user_collaborated_tasks',
      );

      if (kDebugMode) {
        print('✅ Collaborated tasks: ${collabTasksResponse.length}');
      }

      // Add collaborated tasks
      for (final taskJson in collabTasksResponse) {
        try {
          allTasks.add(Task.fromJson(taskJson));
        } catch (e) {
          if (kDebugMode) {
            print('❌ Error parsing collaborated task: $e');
          }
        }
      }

      // Sort by creation date
      allTasks.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (kDebugMode) {
        print('📈 FINAL RESULTS:');
        print('   - Owned tasks: ${ownedTasksResponse.length}');
        print('   - Collaborated tasks: ${collabTasksResponse.length}');
        print('   - Total tasks: ${allTasks.length}');
        print('🎉 TASK LIST:');
        for (final task in allTasks) {
          final isOwned = task.ownerId == _currentUserId;
          print(
            '   - ${task.title} (ID: ${task.id}, ${isOwned ? 'OWNER' : 'COLLAB'})',
          );
        }
      }

      state = state.copyWith(tasks: allTasks, isLoading: false);
    } catch (e) {
      if (kDebugMode) {
        print(' CRITICAL ERROR in _fetchTasks: $e');
      }
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  // Refresh tasks manually
  Future<void> refreshTasks() async {
    state = state.copyWith(isRefreshing: true, error: null);
    try {
      await _fetchTasks();
      state = state.copyWith(isRefreshing: false);
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
          .from('tasks') // Changed from 'todo' to 'tasks'
          .insert({
            'title': name, // Changed from 'name' to 'title'
            'description': description,
            'category': category,
            'completed': false,
            'owner_id': _currentUserId,
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
          .from('tasks') // Changed from 'todo' to 'tasks'
          .update({
            'title': name, // Changed from 'name' to 'title'
            'description': description,
            'category': category,
            'completed': completed,
          })
          .eq('id', id);

      final updatedTask = Task(
        id: id,
        title: name, // Changed from 'name' to 'title'
        description: description,
        category: category,
        completed: completed,
        createdAt: DateTime.now(),
        ownerId: _currentUserId,
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
          .from('tasks') // Changed from 'todo' to 'tasks'
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
      await _supabase
          .from('tasks')
          .delete()
          .eq('id', id); // Changed from 'todo' to 'tasks'

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
