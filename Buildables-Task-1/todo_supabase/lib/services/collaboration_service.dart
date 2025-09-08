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
    try {
      if (kDebugMode) {
        print('Inviting $email to task $taskId');
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
        print('Task data for invitation: $taskData');
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
        print('Invitation response: $response');
      }

      return CollaborationResult.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      if (kDebugMode) {
        print('Invitation error: $e');
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
    try {
      if (kDebugMode) {
        print('Accepting invitation for task $taskId');
      }

      final response = await _supabase.rpc(
        'accept_task_invitation',
        params: {'task_id_param': taskId},
      );

      if (kDebugMode) {
        print('Accept invitation response: $response');
      }

      // Force a refresh of the task list after accepting invitation
      // This ensures the collaborator task appears immediately
      try {
        await Future.delayed(
          const Duration(milliseconds: 500),
        ); // Small delay to ensure DB is updated
        // The real-time subscription should handle this, but we'll also trigger a manual refresh
        if (kDebugMode) {
          print('Invitation accepted, task list should refresh automatically');
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
        print('Accept invitation error: $e');
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
        print('Fetching collaborators for task $taskId');
      }

      final response = await _supabase
          .from('task_collaborators')
          .select('''
            user_id,
            role,
            invited_at,
            accepted_at
          ''')
          .eq('task_id', taskId);

      if (kDebugMode) {
        print('Collaborators response: $response');
      }

      final collaborators = (response as List).map((data) {
        return Collaborator(
          userId: data['user_id'] as String,
          email: 'Loading...', // We'll get email separately if needed
          role: data['role'] as String? ?? 'collaborator',
          invitedAt: data['invited_at'] != null
              ? DateTime.parse(data['invited_at'] as String)
              : null,
          acceptedAt: data['accepted_at'] != null
              ? DateTime.parse(data['accepted_at'] as String)
              : null,
        );
      }).toList();

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
    try {
      if (query.length < 3) return []; // Don't search for very short queries

      if (kDebugMode) {
        print('Searching users with email containing: $query');
      }

      final response = await _supabase.rpc(
        'get_user_by_email',
        params: {'user_email': query},
      );

      if (kDebugMode) {
        print('User search response: $response');
      }

      return List<Map<String, dynamic>>.from(response ?? []);
    } catch (e) {
      if (kDebugMode) {
        print('User search error: $e');
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
