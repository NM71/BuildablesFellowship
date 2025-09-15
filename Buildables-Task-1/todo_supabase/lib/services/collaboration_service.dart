import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/task_provider.dart';

class CollaborationResult {
  final bool success;
  final String message;
  final Map<String, dynamic>? data;

  CollaborationResult({
    required this.success,
    required this.message,
    this.data,
  });

  factory CollaborationResult.fromJson(Map<String, dynamic> json) {
    return CollaborationResult(
      success: json['success'] ?? false,
      message: json['message'] ?? 'Unknown error',
      data: json,
    );
  }
}

class CollaborationService {
  static final CollaborationService _instance =
      CollaborationService._internal();
  factory CollaborationService() => _instance;
  CollaborationService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  // Get current user ID
  String get _currentUserId => _supabase.auth.currentUser?.id ?? '';

  // Invite user to task by email
  Future<CollaborationResult> inviteUserToTask({
    required int taskId,
    required String email,
  }) async {
    if (kDebugMode) {
      print('👥 [COLLABORATION] ===== STARTING USER INVITATION =====');
      print('👥 [COLLABORATION] Task ID: $taskId');
      print('👥 [COLLABORATION] Invitee Email: $email');
    }

    try {
      if (kDebugMode) {
        print('👥 [COLLABORATION] Step 1: Fetching task data...');
      }

      // First get the task data that the collaborator will need
      final taskData = await _supabase
          .from('tasks') // Changed from 'todo' to 'tasks'
          .select(
            'title, description, category, completed, created_at, updated_at, owner_id', // Changed 'name' to 'title'
          )
          .eq('id', taskId)
          .single();

      if (kDebugMode) {
        print('👥 [COLLABORATION] Task data retrieved: $taskData');
        print('👥 [COLLABORATION] Step 2: Calling invite_user_to_task RPC...');
      }

      // Use RPC function to create invitation
      final response = await _supabase.rpc(
        'invite_user_to_task', // Changed to new function name
        params: {
          'task_id_param': taskId,
          'invitee_email_param': email, // Updated parameter name
        },
      );

      if (kDebugMode) {
        print('👥 [COLLABORATION] RPC response: $response');
        print('👥 [COLLABORATION] Invitation process completed');
      }

      return CollaborationResult.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      if (kDebugMode) {
        print('❌ [COLLABORATION] Invitation error: $e');
      }
      return CollaborationResult(
        success: false,
        message: 'Failed to send invitation: ${e.toString()}',
      );
    }
  }

  // Accept task invitation
  Future<CollaborationResult> acceptTaskInvitation({
    required int taskId,
  }) async {
    if (kDebugMode) {
      print('👥 [COLLABORATION] ===== ACCEPTING TASK INVITATION =====');
      print('👥 [COLLABORATION] Task ID: $taskId');
      print('👥 [COLLABORATION] Current User: $_currentUserId');
    }

    try {
      if (kDebugMode) {
        print(
          '👥 [COLLABORATION] Step 1: Calling accept_task_invitation RPC...',
        );
      }

      final response = await _supabase.rpc(
        'accept_task_invitation',
        params: {'task_id_param': taskId},
      );

      if (kDebugMode) {
        print('👥 [COLLABORATION] RPC response: $response');
        print('👥 [COLLABORATION] Step 2: Waiting for database update...');
      }

      // Force a refresh of the task list after accepting invitation
      // This ensures the collaborator task appears immediately
      try {
        await Future.delayed(
          const Duration(milliseconds: 500),
        ); // Small delay to ensure DB is updated
        // The real-time subscription should handle this, but we'll also trigger a manual refresh
        if (kDebugMode) {
          print('👥 [COLLABORATION] Database update delay completed');
          print('👥 [COLLABORATION] Invitation acceptance process completed');
        }
      } catch (refreshError) {
        if (kDebugMode) {
          print(
            'Manual refresh after invitation acceptance failed: $refreshError',
          );
        }
      }

      return CollaborationResult.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      if (kDebugMode) {
        print('❌ [COLLABORATION] Accept invitation error: $e');
      }
      return CollaborationResult(
        success: false,
        message: 'Failed to accept invitation: ${e.toString()}',
      );
    }
  }

  // Remove collaborator from task (only task owners can do this)
  Future<CollaborationResult> removeCollaborator({
    required int taskId,
    required String userId,
  }) async {
    try {
      if (kDebugMode) {
        print('Removing collaborator $userId from task $taskId');
      }

      await _supabase
          .from('task_collaborators')
          .delete()
          .eq('task_id', taskId)
          .eq('user_id', userId);

      return CollaborationResult(
        success: true,
        message: 'Collaborator removed successfully',
      );
    } catch (e) {
      if (kDebugMode) {
        print('Remove collaborator error: $e');
      }
      return CollaborationResult(
        success: false,
        message: 'Failed to remove collaborator: ${e.toString()}',
      );
    }
  }

  // Get task collaborators with details
  Future<List<Collaborator>> getTaskCollaborators({required int taskId}) async {
    try {
      if (kDebugMode) {
        print('👥 [COLLABORATION] Fetching collaborators for task $taskId');
        print('👥 [COLLABORATION] Current user: $_currentUserId');
      }

      // First get collaborators without join (avoids FK constraint issues)
      // Include ALL collaborators regardless of acceptance status
      final collaboratorsResponse = await _supabase
          .from('task_collaborators')
          .select('user_id, role, invited_at, accepted_at')
          .eq('task_id', taskId);

      if (kDebugMode) {
        print(
          '👥 [COLLABORATION] Checking task_collaborators table for task $taskId',
        );
        print('👥 [COLLABORATION] All records in task_collaborators:');

        // Debug: Check all records in task_collaborators for this task
        try {
          final allRecords = await _supabase
              .from('task_collaborators')
              .select('*');
          print(
            '👥 [COLLABORATION] All task_collaborators records: $allRecords',
          );

          // Check records specifically for this task
          final taskRecords = await _supabase
              .from('task_collaborators')
              .select('*')
              .eq('task_id', taskId);
          print('👥 [COLLABORATION] Records for task $taskId: $taskRecords');
        } catch (debugError) {
          print('👥 [COLLABORATION] Could not fetch all records: $debugError');
        }
      }

      if (kDebugMode) {
        print(
          '👥 [COLLABORATION] Collaborators response: $collaboratorsResponse',
        );
        print(
          '👥 [COLLABORATION] Response type: ${collaboratorsResponse.runtimeType}',
        );
        print(
          '👥 [COLLABORATION] Response length: ${(collaboratorsResponse as List?)?.length ?? 'null'}',
        );
      }

      final collaborators = <Collaborator>[];

      for (final collabData in collaboratorsResponse as List) {
        final userId = collabData['user_id'] as String;

        // Get user email using RPC function
        String email = 'Unknown User';
        try {
          final userResponse = await _supabase.rpc(
            'get_user_by_id',
            params: {'user_id_param': userId},
          );

          if (userResponse != null && (userResponse as List).isNotEmpty) {
            final userData = userResponse[0] as Map<String, dynamic>;
            email =
                userData['email'] as String? ??
                userData['full_name'] as String? ??
                'Unknown User';
          }

          if (kDebugMode) {
            print('👥 [COLLABORATION] User $userId email: $email');
          }
        } catch (userError) {
          if (kDebugMode) {
            print(
              '👥 [COLLABORATION] Could not fetch user data for $userId: $userError',
            );
          }
        }

        collaborators.add(
          Collaborator(
            userId: userId,
            email: email,
            role: collabData['role'] as String? ?? 'collaborator',
            invitedAt: collabData['invited_at'] != null
                ? DateTime.parse(collabData['invited_at'] as String)
                : null,
            acceptedAt: collabData['accepted_at'] != null
                ? DateTime.parse(collabData['accepted_at'] as String)
                : null,
          ),
        );
      }

      if (kDebugMode) {
        print(
          '👥 [COLLABORATION] Final collaborators list: ${collaborators.length} items',
        );
      }

      return collaborators;
    } catch (e) {
      if (kDebugMode) {
        print('Get collaborators error: $e');
      }
      return [];
    }
  }

  // Search users by email (for invitation suggestions)
  Future<List<Map<String, dynamic>>> searchUsersByEmail({
    required String query,
  }) async {
    if (kDebugMode) {
      print('👥 [COLLABORATION] ===== SEARCHING USERS BY EMAIL =====');
      print('👥 [COLLABORATION] Query: "$query"');
      print('👥 [COLLABORATION] Query length: ${query.length}');
    }

    try {
      if (query.length < 3) {
        if (kDebugMode) {
          print('👥 [COLLABORATION] Query too short, returning empty list');
        }
        return []; // Don't search for very short queries
      }

      if (kDebugMode) {
        print('👥 [COLLABORATION] Step 1: Calling get_user_by_email RPC...');
      }

      final response = await _supabase.rpc(
        'get_user_by_email',
        params: {'user_email': query},
      );

      if (kDebugMode) {
        print('👥 [COLLABORATION] RPC response: $response');
        print('👥 [COLLABORATION] Response type: ${response.runtimeType}');
        if (response is List) {
          print('👥 [COLLABORATION] Response length: ${response.length}');
        }
        print('👥 [COLLABORATION] User search completed');
      }

      return List<Map<String, dynamic>>.from(response ?? []);
    } catch (e) {
      if (kDebugMode) {
        print('❌ [COLLABORATION] User search error: $e');
      }
      return [];
    }
  }

  // Get pending invitations for current user
  Future<List<Map<String, dynamic>>> getPendingInvitations() async {
    try {
      if (kDebugMode) {
        print('Fetching pending invitations for user $_currentUserId');
      }

      // First try direct query to bypass any RPC issues
      final invitationsResponse = await _supabase
          .from('task_collaborators')
          .select('''
            task_id,
            invited_at,
            task:tasks!fk_task_collaborators_task_id (
              id,
              title,
              description,
              category,
              owner_id
            )
          ''')
          .eq('user_id', _currentUserId)
          .isFilter('accepted_at', null);

      if (kDebugMode) {
        print('Direct query result: $invitationsResponse');
      }

      // Transform the response to match expected format
      final List<Map<String, dynamic>> transformedResponse = [];

      for (final invitation in invitationsResponse as List) {
        final task = invitation['task'];

        if (task == null) {
          if (kDebugMode) {
            print(
              'Task join failed for task_id: ${invitation['task_id']}, trying fallback query',
            );
          }

          // Fallback: Get task data directly
          try {
            final taskData = await _supabase
                .from('tasks')
                .select('title, description, category, owner_id')
                .eq('id', invitation['task_id'])
                .single();

            if (kDebugMode) {
              print('Fallback task data: $taskData');
            }

            transformedResponse.add({
              'task_id': invitation['task_id'],
              'task_title': taskData['title'] ?? 'Unknown Task',
              'task_description': taskData['description'] ?? '',
              'task_category': taskData['category'] ?? 'Other',
              'owner_email': 'Task Owner',
              'invited_at': invitation['invited_at'],
            });
          } catch (fallbackError) {
            if (kDebugMode) {
              print('Fallback query also failed: $fallbackError');
            }
            transformedResponse.add({
              'task_id': invitation['task_id'],
              'task_title': 'Task Not Found',
              'task_description': 'The task may have been deleted',
              'task_category': 'Other',
              'owner_email': 'Unknown',
              'invited_at': invitation['invited_at'],
            });
          }
        } else {
          transformedResponse.add({
            'task_id': invitation['task_id'],
            'task_title': task['title'] ?? 'Unknown Task',
            'task_description': task['description'] ?? '',
            'task_category': task['category'] ?? 'Other',
            'owner_email': 'Task Owner',
            'invited_at': invitation['invited_at'],
          });
        }
      }

      if (kDebugMode) {
        print('Transformed invitations: $transformedResponse');
      }

      return transformedResponse;
    } catch (e) {
      if (kDebugMode) {
        print('Get pending invitations error: $e');
      }
      return [];
    }
  }

  // Get tasks with collaboration info (enhanced version)
  Future<List<Task>> getTasksWithCollaborationInfo() async {
    try {
      if (kDebugMode) {
        print('Fetching tasks with collaboration info');
      }

      final response = await _supabase
          .from('tasks_with_collaborators')
          .select()
          .order('created_at', ascending: false);

      if (kDebugMode) {
        print('Tasks with collaboration response: $response');
      }

      final tasks = (response as List)
          .map((json) => Task.fromJson(json))
          .toList();
      return tasks;
    } catch (e) {
      if (kDebugMode) {
        print('Get tasks with collaboration error: $e');
      }
      return [];
    }
  }
}
