import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/task_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/invite_user_dialog.dart';
import '../services/collaboration_service.dart';
import '../widgets/file_attachment_widget.dart';
import '../widgets/file_thumbnail.dart';
import '../services/file_service.dart';
import 'collaborator_map_screen.dart';

class TaskDetailPage extends ConsumerStatefulWidget {
  final Task task;

  const TaskDetailPage({super.key, required this.task});

  @override
  ConsumerState<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends ConsumerState<TaskDetailPage> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _categoryController = TextEditingController();
  bool _isCompleted = false;
  bool _isEditing = false;
  List<Collaborator> _collaborators = [];
  bool _isLoadingCollaborators = false;
  bool _attachmentsLoaded = false;

  // Predefined categories
  final List<String> categories = [
    'Personal',
    'Work',
    'Shopping',
    'Health',
    'Education',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      print('📱 [TASK_DETAIL] ===== INIT STATE =====');
      print('📱 [TASK_DETAIL] Task ID: ${widget.task.id}');
      print('📱 [TASK_DETAIL] Task Name: ${widget.task.name}');
      print(
        '📱 [TASK_DETAIL] Initial attachments: ${widget.task.attachments.length}',
      );
      print(
        '📱 [TASK_DETAIL] Collaborators: ${widget.task.collaborators.length}',
      );
    }

    _initializeFields();
    _loadCollaborators();
    _loadAttachments();
  }

  void _initializeFields() {
    _nameController.text = widget.task.name;
    _descriptionController.text = widget.task.description ?? '';
    _categoryController.text = widget.task.category;
    _isCompleted = widget.task.completed;
  }

  Future<void> _loadCollaborators() async {
    if (!mounted) return;

    // Check if collaborators are already loaded and cached
    if (_collaborators.isNotEmpty) {
      if (kDebugMode) {
        print(
          '👥 [TASK_DETAIL] Collaborators already cached (${_collaborators.length} items), skipping reload',
        );
      }
      return;
    }

    if (kDebugMode) {
      print(
        '👥 [TASK_DETAIL] Loading collaborators for task ${widget.task.id}',
      );
    }

    setState(() {
      _isLoadingCollaborators = true;
    });

    try {
      final collaborators = await CollaborationService().getTaskCollaborators(
        taskId: widget.task.id,
      );

      if (kDebugMode) {
        print('👥 [TASK_DETAIL] Loaded ${collaborators.length} collaborators');
      }

      if (mounted) {
        setState(() {
          _collaborators = collaborators;
          _isLoadingCollaborators = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [TASK_DETAIL] Error loading collaborators: $e');
      }

      if (mounted) {
        setState(() {
          _isLoadingCollaborators = false;
        });
      }
    }
  }

  Future<void> _loadAttachments() async {
    // Check if attachments are already loaded and cached
    if (_attachmentsLoaded) {
      if (kDebugMode) {
        print('📎 [TASK_DETAIL] Attachments already cached, skipping reload');
      }
      return;
    }

    if (kDebugMode) {
      print('📎 [TASK_DETAIL] Loading attachments for task ${widget.task.id}');
      print(
        '📎 [TASK_DETAIL] Current task attachments before load: ${widget.task.attachments.length}',
      );
    }

    await ref.read(taskProvider.notifier).loadTaskAttachments(widget.task.id);

    if (kDebugMode) {
      print('📎 [TASK_DETAIL] Attachment loading completed');
    }

    // Mark attachments as loaded to prevent re-loading
    if (mounted) {
      setState(() {
        _attachmentsLoaded = true;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _saveTask() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Task name cannot be empty")),
      );
      return;
    }

    final message = await ref
        .read(taskProvider.notifier)
        .updateTask(
          id: widget.task.id,
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim().isNotEmpty
              ? _descriptionController.text.trim()
              : null,
          category: _categoryController.text.trim().isNotEmpty
              ? _categoryController.text.trim()
              : 'Other',
          completed: _isCompleted,
        );

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));

      if (!message.contains('Failed')) {
        setState(() {
          _isEditing = false;
        });
      }
    }
  }

  Future<void> _toggleCompletion() async {
    final newStatus = !_isCompleted;
    final message = await ref
        .read(taskProvider.notifier)
        .toggleTaskCompletion(widget.task.id, newStatus);

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));

      if (!message.contains('Failed')) {
        setState(() {
          _isCompleted = newStatus;
        });
      }
    }
  }

  Future<void> _deleteTask() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Task"),
        content: Text(
          "Are you sure you want to delete \"${widget.task.name}\"?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      final message = await ref
          .read(taskProvider.notifier)
          .deleteTask(widget.task.id);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));

        if (!message.contains('Failed')) {
          Navigator.pop(context); // Go back to task list
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) {
      print('📱 [TASK_DETAIL] ===== BUILD METHOD =====');
      print('📱 [TASK_DETAIL] Building UI for task ${widget.task.id}');
    }

    final currentUser = ref.watch(currentUserProvider);
    final taskState = ref.watch(taskProvider);

    if (kDebugMode) {
      print('📱 [TASK_DETAIL] Current user: ${currentUser?.id}');
      print('📱 [TASK_DETAIL] Task state has ${taskState.tasks.length} tasks');
    }

    // Find the current task from the provider state (for real-time updates)
    final currentTask = taskState.tasks.firstWhere(
      (t) => t.id == widget.task.id,
      orElse: () => widget.task, // Fallback to original task if not found
    );

    if (kDebugMode) {
      print('📱 [TASK_DETAIL] Current task found: ${currentTask.id}');
      print(
        '📱 [TASK_DETAIL] Current task attachments: ${currentTask.attachments.length}',
      );
      print(
        '📱 [TASK_DETAIL] Widget task attachments: ${widget.task.attachments.length}',
      );
      print(
        '📱 [TASK_DETAIL] Using ${currentTask == widget.task ? 'widget.task' : 'provider task'}',
      );
      print('📱 [TASK_DETAIL] Attachments loaded flag: $_attachmentsLoaded');
    }

    final isOwner = currentUser?.id == currentTask.ownerId;
    final canEdit = currentTask.canEdit(currentUser?.id ?? '');

    if (kDebugMode) {
      print(
        '📱 [TASK_DETAIL] User permissions - Owner: $isOwner, Can Edit: $canEdit',
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        title: Text(
          _isEditing ? 'Edit Task' : 'Task Details',
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (canEdit && !_isEditing)
            IconButton(
              onPressed: () => setState(() => _isEditing = true),
              icon: const Icon(Icons.edit, color: Colors.white),
              tooltip: 'Edit Task',
            ),
          if (_isEditing) ...[
            IconButton(
              onPressed: () {
                _initializeFields(); // Reset fields
                setState(() => _isEditing = false);
              },
              icon: const Icon(Icons.close, color: Colors.white),
              tooltip: 'Cancel',
            ),
            IconButton(
              onPressed: _saveTask,
              icon: const Icon(Icons.check, color: Color(0xff38b17d)),
              tooltip: 'Save',
            ),
          ],
          if (isOwner)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (value) {
                switch (value) {
                  case 'delete':
                    _deleteTask();
                    break;
                  case 'invite':
                    showDialog(
                      context: context,
                      builder: (context) => InviteUserDialog(task: widget.task),
                    );
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'invite',
                  child: Row(
                    children: [
                      Icon(Icons.person_add, size: 18),
                      SizedBox(width: 8),
                      Text('Invite Collaborator'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red, size: 18),
                      SizedBox(width: 8),
                      Text('Delete Task', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Task Status Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: currentTask.completed
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: currentTask.completed
                      ? Colors.green.withValues(alpha: 0.3)
                      : Colors.orange.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: canEdit ? _toggleCompletion : null,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isCompleted ? Colors.green : Colors.transparent,
                        border: Border.all(
                          color: _isCompleted ? Colors.green : Colors.orange,
                          width: 2,
                        ),
                      ),
                      child: _isCompleted
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 16,
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      currentTask.completed ? 'Task Completed' : 'Task Pending',
                      style: TextStyle(
                        color: currentTask.completed
                            ? Colors.green
                            : Colors.orange,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  if (canEdit)
                    Text(
                      'Tap to ${currentTask.completed ? 'mark pending' : 'complete'}',
                      style: TextStyle(
                        color:
                            (currentTask.completed
                                    ? Colors.green
                                    : Colors.orange)
                                .withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Task Name
            _buildFieldSection(
              label: 'Task Name',
              child: _isEditing
                  ? TextField(
                      controller: _nameController,
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                      decoration: InputDecoration(
                        hintText: 'Enter task name',
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Colors.white30),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Colors.white30),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    )
                  : Text(
                      currentTask.name,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        decoration: currentTask.completed
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
            ),

            const SizedBox(height: 20),

            // Description
            _buildFieldSection(
              label: 'Description',
              child: _isEditing
                  ? TextField(
                      controller: _descriptionController,
                      style: const TextStyle(color: Colors.white),
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Add a description (optional)',
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Colors.white30),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Colors.white30),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    )
                  : Text(
                      widget.task.description?.isNotEmpty == true
                          ? widget.task.description!
                          : 'No description provided',
                      style: TextStyle(
                        color: widget.task.description?.isNotEmpty == true
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.5),
                        fontSize: 16,
                        decoration: _isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
            ),

            const SizedBox(height: 20),

            // Category
            _buildFieldSection(
              label: 'Category',
              child: _isEditing
                  ? DropdownButtonFormField<String>(
                      value: _categoryController.text.isEmpty
                          ? null
                          : _categoryController.text,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Select category',
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Colors.white30),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Colors.white30),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                      dropdownColor: Colors.grey[800],
                      items: categories.map((category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Text(
                            category,
                            style: const TextStyle(color: Colors.white),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        _categoryController.text = value ?? '';
                      },
                    )
                  : Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        widget.task.category,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
            ),

            const SizedBox(height: 24),

            // Task Info
            _buildInfoSection(),

            const SizedBox(height: 24),

            // Collaborators Section - Always show for owners, show for others if there are collaborators
            if (isOwner || _collaborators.isNotEmpty)
              _buildCollaboratorsSection(),

            const SizedBox(height: 24),

            // File Attachments Section
            _buildAttachmentsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldSection({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _buildInfoSection() {
    final currentUser = ref.watch(currentUserProvider);
    final isOwner = currentUser?.id == widget.task.ownerId;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Task Information',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          _buildInfoRow('Created', _formatDateTime(widget.task.createdAt)),
          if (widget.task.updatedAt != null)
            _buildInfoRow(
              'Last Updated',
              _formatDateTime(widget.task.updatedAt!),
            ),
          _buildInfoRow(
            'Owner',
            isOwner ? 'You' : (widget.task.ownerEmail ?? 'Unknown'),
          ),
          _buildInfoRow(
            'Status',
            widget.task.completed ? 'Completed' : 'Pending',
          ),
          if (widget.task.collaboratorCount > 0)
            _buildInfoRow(
              'Collaborators',
              '${widget.task.collaboratorCount} users',
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollaboratorsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Collaborators',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Row(
                children: [
                  // View on Map button
                  TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CollaboratorMapScreen(
                            taskId: widget.task.id.toString(),
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.map, size: 16),
                    label: const Text('View Map'),
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  if (widget.task.isOwnedBy(
                    ref.watch(currentUserProvider)?.id ?? '',
                  ))
                    TextButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) =>
                              InviteUserDialog(task: widget.task),
                        );
                      },
                      icon: const Icon(Icons.person_add, size: 16),
                      label: const Text('Invite'),
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_collaborators.isEmpty)
            Text(
              'No collaborators yet',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 14,
              ),
            )
          else
            ..._collaborators.map((collaborator) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      collaborator.hasAccepted
                          ? Icons.check_circle
                          : Icons.access_time,
                      color: collaborator.hasAccepted
                          ? Colors.green
                          : Colors.orange,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        collaborator.email,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Text(
                      collaborator.hasAccepted ? 'Active' : 'Pending',
                      style: TextStyle(
                        color: collaborator.hasAccepted
                            ? Colors.green
                            : Colors.orange,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildAttachmentsSection() {
    final currentUser = ref.watch(currentUserProvider);
    final canEdit = widget.task.canEdit(currentUser?.id ?? '');
    final attachments = widget.task.attachments;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Attachments',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              if (canEdit)
                Text(
                  '${attachments.length}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (attachments.isEmpty)
            Column(
              children: [
                Text(
                  'No attachments yet',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                if (canEdit)
                  FileAttachmentWidget(
                    onFileSelected: _onFileAttached,
                    taskId: widget.task.id.toString(),
                  ),
              ],
            )
          else
            Column(
              children: [
                // Display existing attachments
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: attachments.map((attachment) {
                    return FileThumbnail(
                      attachment: attachment,
                      onDelete: canEdit
                          ? () => _deleteAttachment(attachment)
                          : null,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                if (canEdit)
                  FileAttachmentWidget(
                    onFileSelected: _onFileAttached,
                    taskId: widget.task.id.toString(),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  void _onFileAttached(FileAttachment attachment) {
    if (kDebugMode) {
      print(
        '📎 [ATTACHMENT] File attached to task ${widget.task.id}: ${attachment.fileName}',
      );
      print(
        '📎 [ATTACHMENT] Attachment details: ID=${attachment.id}, URL=${attachment.fileUrl}',
      );
    }

    // Add attachment to the task provider
    ref.read(taskProvider.notifier).addAttachment(widget.task.id, attachment);

    if (kDebugMode) {
      print('📎 [ATTACHMENT] Task state updated with new attachment');
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('File "${attachment.fileName}" attached successfully'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _deleteAttachment(FileAttachment attachment) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(
          'Delete Attachment',
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to delete "${attachment.fileName}"?',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      final success = await FileService.instance.deleteFile(
        attachment.fileUrl,
        attachmentId: attachment.id,
      );
      if (success) {
        // Remove attachment from the task provider state
        ref
            .read(taskProvider.notifier)
            .removeAttachment(widget.task.id, attachment.id);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Attachment "${attachment.fileName}" deleted'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete attachment'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return 'Today ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}
