import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/file_service.dart';

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
  final List<FileAttachment> attachments;

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
    this.attachments = const [],
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    if (kDebugMode) {
      print('🔍 [TASK] Parsing task JSON: $json');
    }

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

    // Parse attachments from JSON array (if present)
    List<FileAttachment> attachmentsList = [];
    if (json['attachments'] != null) {
      final attachmentsData = json['attachments'] as List;
      attachmentsList = attachmentsData
          .map(
            (attachment) =>
                FileAttachment.fromJson(attachment as Map<String, dynamic>),
          )
          .toList();
    }

    // Handle null values safely
    final title = json['title'] as String? ?? 'Untitled Task';
    final createdAtString = json['created_at'] as String?;
    final ownerIdString = json['owner_id'] as String?;

    if (createdAtString == null) {
      if (kDebugMode) {
        print('❌ [TASK] created_at is null for task ${json['id']}');
      }
      throw Exception('Task created_at cannot be null');
    }

    if (ownerIdString == null) {
      if (kDebugMode) {
        print('❌ [TASK] owner_id is null for task ${json['id']}');
      }
      throw Exception('Task owner_id cannot be null');
    }

    return Task(
      id: json['id'] as int,
      title: title,
      description: json['description'] as String?,
      category: json['category'] as String? ?? 'Other',
      completed: json['completed'] as bool? ?? false,
      createdAt: DateTime.parse(createdAtString),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      ownerId: ownerIdString,
      ownerEmail: json['owner_email'] as String?,
      collaborators: collaboratorsList,
      attachments: attachmentsList,
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
    List<FileAttachment>? attachments,
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
      attachments: attachments ?? this.attachments,
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
        print(
          '🔍 Current auth state: ${Supabase.instance.client.auth.currentUser}',
        );
        print(
          '🔍 Current session: ${Supabase.instance.client.auth.currentSession}',
        );
      }

      // TEMPORARY WORKAROUND: Use direct queries with simple RLS policies
      // This avoids complex RLS recursion while we fix the policies

      // STEP 1: Fetch owned tasks with attachments (should work with simple policy)
      final ownedTasksResponse = await _supabase
          .from('tasks')
          .select('''
            *,
            task_attachments (
              id,
              filename,
              file_path,
              file_size,
              content_type,
              uploaded_by,
              uploaded_at
            )
          ''')
          .eq('owner_id', _currentUserId)
          .order('created_at', ascending: false);

      if (kDebugMode) {
        print('✅ Owned tasks: ${ownedTasksResponse.length}');
      }

      final allTasks = <Task>[];

      // Add owned tasks with attachments
      for (final taskJson in ownedTasksResponse) {
        try {
          allTasks.add(Task.fromJson(taskJson));
        } catch (e) {
          if (kDebugMode) {
            print('❌ Error parsing owned task: $e');
          }
        }
      }

      // STEP 2: Fetch collaborated tasks with attachments using RPC function
      final collabTasksResponse = await _supabase.rpc(
        'get_user_collaborated_tasks',
      );

      if (kDebugMode) {
        print('✅ Collaborated tasks: ${collabTasksResponse.length}');
      }

      // Add collaborated tasks with attachments
      for (final taskJson in collabTasksResponse) {
        try {
          // For collaborated tasks, we need to load attachments separately
          final taskId = taskJson['id'] as int;
          final attachmentsResponse = await _supabase
              .from('task_attachments')
              .select()
              .eq('task_id', taskId);

          final attachments = (attachmentsResponse as List)
              .map((json) => FileAttachment.fromJson(json))
              .toList();

          // Add attachments to task JSON
          final taskWithAttachments = {
            ...(taskJson as Map<String, dynamic>),
            'attachments': attachments
                .map((a) => a.toJson())
                .cast<Map<String, dynamic>>()
                .toList(),
          };

          allTasks.add(Task.fromJson(taskWithAttachments));
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
    if (kDebugMode) {
      print(
        '📝 [TASK_PROVIDER] Creating task: name="$name", desc="$description", category="$category"',
      );
    }

    state = state.copyWith(
      isLoading: true,
      currentOperation: TaskOperation.create,
      error: null,
    );

    try {
      final taskData = {
        'title': name, // Changed from 'name' to 'title'
        'description': description,
        'category': category,
        'completed': false,
        'owner_id': _currentUserId,
      };

      if (kDebugMode) {
        print('📝 [TASK_PROVIDER] Inserting task data: $taskData');
      }

      final response = await _supabase
          .from('tasks') // Changed from 'todo' to 'tasks'
          .insert(taskData)
          .select()
          .single();

      if (kDebugMode) {
        print('📝 [TASK_PROVIDER] Task created successfully: $response');
      }

      final newTask = Task.fromJson(response);
      final updatedTasks = [newTask, ...state.tasks];
      state = state.copyWith(
        tasks: updatedTasks,
        isLoading: false,
        currentOperation: null,
      );

      if (kDebugMode) {
        print(
          '📝 [TASK_PROVIDER] Task added to state. Total tasks: ${updatedTasks.length}',
        );
      }

      return 'Task "${newTask.name}" added successfully';
    } catch (e) {
      if (kDebugMode) {
        print('❌ [TASK_PROVIDER] Failed to create task: $e');
      }

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
    if (kDebugMode) {
      print('📝 [TASK_PROVIDER] Updating task ID: $id');
      print(
        '📝 [TASK_PROVIDER] New values: name="$name", desc="$description", category="$category", completed=$completed',
      );
    }

    state = state.copyWith(
      isLoading: true,
      currentOperation: TaskOperation.update,
      error: null,
    );

    try {
      final updateData = {
        'title': name, // Changed from 'name' to 'title'
        'description': description,
        'category': category,
        'completed': completed,
      };

      if (kDebugMode) {
        print('📝 [TASK_PROVIDER] Update data: $updateData');
      }

      final response = await _supabase
          .from('tasks') // Changed from 'todo' to 'tasks'
          .update(updateData)
          .eq('id', id)
          .select()
          .single();

      if (kDebugMode) {
        print('📝 [TASK_PROVIDER] Task updated successfully: $response');
      }

      final updatedTask = Task.fromJson(response);
      final updatedTasks = state.tasks.map((task) {
        return task.id == id ? updatedTask : task;
      }).toList();

      state = state.copyWith(
        tasks: updatedTasks,
        isLoading: false,
        currentOperation: null,
      );

      if (kDebugMode) {
        print(
          '📝 [TASK_PROVIDER] Task updated in state. Total tasks: ${updatedTasks.length}',
        );
      }

      return 'Task updated to "$name"';
    } catch (e) {
      if (kDebugMode) {
        print('❌ [TASK_PROVIDER] Failed to update task: $e');
      }

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
    if (kDebugMode) {
      print(
        '📝 [TASK_PROVIDER] Toggling task completion: ID=$id, completed=$completed',
      );
    }

    state = state.copyWith(
      isLoading: true,
      currentOperation: TaskOperation.toggle,
      error: null,
    );

    try {
      final updateData = {'completed': completed};

      if (kDebugMode) {
        print('📝 [TASK_PROVIDER] Toggle update data: $updateData');
      }

      final response = await _supabase
          .from('tasks') // Changed from 'todo' to 'tasks'
          .update(updateData)
          .eq('id', id)
          .select()
          .single();

      if (kDebugMode) {
        print(
          '📝 [TASK_PROVIDER] Task completion toggled successfully: $response',
        );
      }

      final updatedTask = Task.fromJson(response);
      final updatedTasks = state.tasks.map((task) {
        return task.id == id ? updatedTask : task;
      }).toList();

      state = state.copyWith(
        tasks: updatedTasks,
        isLoading: false,
        currentOperation: null,
      );

      if (kDebugMode) {
        print('📝 [TASK_PROVIDER] Task completion updated in state');
      }

      return completed ? 'Task marked as completed' : 'Task marked as pending';
    } catch (e) {
      if (kDebugMode) {
        print('❌ [TASK_PROVIDER] Failed to toggle task completion: $e');
      }

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
    if (kDebugMode) {
      print('📝 [TASK_PROVIDER] Deleting task ID: $id');
    }

    // Find task name for feedback
    final taskToDelete = state.tasks.firstWhere((task) => task.id == id);
    final taskName = taskToDelete.name;

    if (kDebugMode) {
      print('📝 [TASK_PROVIDER] Task to delete: "$taskName"');
    }

    state = state.copyWith(
      isLoading: true,
      currentOperation: TaskOperation.delete,
      error: null,
    );

    try {
      if (kDebugMode) {
        print('📝 [TASK_PROVIDER] Executing delete query for task ID: $id');
      }

      final response = await _supabase
          .from('tasks')
          .delete()
          .eq('id', id)
          .select();

      if (kDebugMode) {
        print('📝 [TASK_PROVIDER] Delete response: $response');
        print('📝 [TASK_PROVIDER] Task deleted successfully');
      }

      final updatedTasks = state.tasks.where((task) => task.id != id).toList();
      state = state.copyWith(
        tasks: updatedTasks,
        isLoading: false,
        currentOperation: null,
      );

      if (kDebugMode) {
        print(
          '📝 [TASK_PROVIDER] Task removed from state. Remaining tasks: ${updatedTasks.length}',
        );
      }

      return 'Task "$taskName" deleted successfully';
    } catch (e) {
      if (kDebugMode) {
        print('❌ [TASK_PROVIDER] Failed to delete task: $e');
      }

      state = state.copyWith(
        isLoading: false,
        currentOperation: null,
        error: e.toString(),
      );
      return 'Failed to delete task: ${e.toString()}';
    }
  }

  // Add attachment to task
  Future<String> addAttachment(int taskId, FileAttachment attachment) async {
    try {
      // Update the task in state with the new attachment
      final updatedTasks = state.tasks.map((task) {
        if (task.id == taskId) {
          final updatedAttachments = [...task.attachments, attachment];
          return task.copyWith(attachments: updatedAttachments);
        }
        return task;
      }).toList();

      state = state.copyWith(tasks: updatedTasks);
      return 'Attachment added successfully';
    } catch (e) {
      return 'Failed to add attachment: ${e.toString()}';
    }
  }

  // Remove attachment from task
  Future<String> removeAttachment(int taskId, String attachmentId) async {
    try {
      // Update the task in state by removing the attachment
      final updatedTasks = state.tasks.map((task) {
        if (task.id == taskId) {
          final updatedAttachments = task.attachments
              .where((attachment) => attachment.id != attachmentId)
              .toList();
          return task.copyWith(attachments: updatedAttachments);
        }
        return task;
      }).toList();

      state = state.copyWith(tasks: updatedTasks);
      return 'Attachment removed successfully';
    } catch (e) {
      return 'Failed to remove attachment: ${e.toString()}';
    }
  }

  // Load attachments for a specific task
  Future<void> loadTaskAttachments(int taskId) async {
    try {
      final attachmentsResponse = await _supabase
          .from('task_attachments')
          .select()
          .eq('task_id', taskId);

      final attachments = (attachmentsResponse as List)
          .map((json) => FileAttachment.fromJson(json))
          .toList();

      // Update the task in state with loaded attachments
      final updatedTasks = state.tasks.map((task) {
        if (task.id == taskId) {
          return task.copyWith(attachments: attachments);
        }
        return task;
      }).toList();

      state = state.copyWith(tasks: updatedTasks);
    } catch (e) {
      if (kDebugMode) {
        print('Error loading attachments for task $taskId: $e');
      }
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
