import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:todo_supabase/providers/task_provider.dart';
import 'package:todo_supabase/providers/auth_provider.dart';
import 'package:todo_supabase/utils/custom_appbar.dart';
import 'package:todo_supabase/screens/task_detail_page.dart';
import 'package:todo_supabase/widgets/file_attachment_widget.dart';
import 'package:todo_supabase/services/file_service.dart';

class TaskPage extends ConsumerStatefulWidget {
  const TaskPage({super.key});

  @override
  ConsumerState<TaskPage> createState() => _TaskPageState();
}

class _TaskPageState extends ConsumerState<TaskPage> {
  final textController = TextEditingController();
  final descController = TextEditingController();
  final categoryController = TextEditingController();
  bool isCompleted = false;
  List<FileAttachment> _attachments = [];

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
  void dispose() {
    textController.dispose();
    descController.dispose();
    categoryController.dispose();
    super.dispose();
  }

  void addNewTask() {
    textController.clear();
    descController.clear();
    categoryController.clear();
    _attachments.clear();

    showDialog(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, child) {
          final isCreating = ref.watch(isCreatingTaskProvider);

          return AlertDialog(
            title: const Text("Add New Task"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: textController,
                    decoration: const InputDecoration(labelText: "Task name"),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: descController,
                    decoration: const InputDecoration(
                      labelText: "Description (optional)",
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: categoryController.text.isEmpty
                        ? null
                        : categoryController.text,
                    decoration: const InputDecoration(labelText: "Category"),
                    items: categories.map((category) {
                      return DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      );
                    }).toList(),
                    onChanged: (value) {
                      categoryController.text = value ?? '';
                    },
                  ),
                  const SizedBox(height: 16),
                  // File Attachments Section
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Attachments (${_attachments.length})',
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_attachments.isNotEmpty)
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _attachments.map((attachment) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue[100],
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      FileService.instance.getFileIcon(
                                        attachment.fileType,
                                      ),
                                      size: 16,
                                      color: Colors.blue[800],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      attachment.fileName.length > 20
                                          ? '${attachment.fileName.substring(0, 20)}...'
                                          : attachment.fileName,
                                      style: TextStyle(
                                        color: Colors.blue[800],
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _attachments.remove(attachment);
                                        });
                                      },
                                      child: Icon(
                                        Icons.close,
                                        size: 14,
                                        color: Colors.blue[800],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        const SizedBox(height: 8),
                        FileAttachmentWidget(
                          onFileSelected: _onFileAttached,
                          showProgress: false,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: isCreating ? null : () => saveTask(ref),
                child: isCreating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text("Save"),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> saveTask(WidgetRef ref) async {
    if (textController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Task name cannot be empty")),
      );
      return;
    }

    final message = await ref
        .read(taskProvider.notifier)
        .createTask(
          name: textController.text.trim(),
          description: descController.text.trim().isNotEmpty
              ? descController.text.trim()
              : null,
          category: categoryController.text.trim().isNotEmpty
              ? categoryController.text.trim()
              : 'Other',
        );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Center(child: Text(message)),
          action: message.contains('Failed')
              ? SnackBarAction(label: 'Retry', onPressed: () => saveTask(ref))
              : null,
        ),
      );

      if (!message.contains('Failed')) {
        textController.clear();
        descController.clear();
        categoryController.clear();
        Navigator.pop(context);
      }
    }
  }

  void updateExistingTask(Task task) {
    textController.text = task.name;
    descController.text = task.description ?? "";
    categoryController.text = task.category;
    isCompleted = task.completed;

    showDialog(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, child) {
          final isUpdating = ref.watch(isUpdatingTaskProvider);

          return AlertDialog(
            title: const Text("Update Task"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: textController,
                  decoration: const InputDecoration(labelText: "Task name"),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(labelText: "Description"),
                  maxLines: 2,
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: categoryController.text.isEmpty
                      ? null
                      : categoryController.text,
                  decoration: const InputDecoration(labelText: "Category"),
                  items: categories.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    );
                  }).toList(),
                  onChanged: (value) {
                    categoryController.text = value ?? '';
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Text("Completed:"),
                    const SizedBox(width: 10),
                    Switch(
                      value: isCompleted,
                      onChanged: (value) {
                        setState(() {
                          isCompleted = value;
                        });
                      },
                      activeColor: Theme.of(context).colorScheme.primary,
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: isUpdating ? null : () => updateTask(ref, task.id),
                child: isUpdating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text("Update"),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> updateTask(WidgetRef ref, int id) async {
    if (textController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Task name cannot be empty")),
      );
      return;
    }

    final message = await ref
        .read(taskProvider.notifier)
        .updateTask(
          id: id,
          name: textController.text.trim(),
          description: descController.text.trim().isNotEmpty
              ? descController.text.trim()
              : null,
          category: categoryController.text.trim().isNotEmpty
              ? categoryController.text.trim()
              : 'Other',
          completed: isCompleted,
        );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Center(child: Text(message)),
          action: message.contains('Failed')
              ? SnackBarAction(
                  label: 'Retry',
                  onPressed: () => updateTask(ref, id),
                )
              : null,
        ),
      );

      if (!message.contains('Failed')) {
        Navigator.pop(context);
      }
    }
  }

  Future<void> confirmAndDelete(int id, String taskName) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Task"),
        content: Text("Are you sure you want to delete \"$taskName\"?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      await deleteTask(id, taskName);
    }
  }

  Future<void> deleteTask(int id, String taskName) async {
    final message = await ref.read(taskProvider.notifier).deleteTask(id);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          action: message.contains('Failed')
              ? SnackBarAction(
                  label: 'Retry',
                  onPressed: () => deleteTask(id, taskName),
                )
              : null,
        ),
      );
    }
  }

  void _onFileAttached(FileAttachment attachment) {
    setState(() {
      _attachments.add(attachment);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('File "${attachment.fileName}" attached successfully'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final taskState = ref.watch(taskProvider);
        final tasks = taskState.tasks;

        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                const CustomAppbar(),
                Expanded(
                  child: taskState.error != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                size: 60,
                                color: Colors.red,
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'Error: ${taskState.error}',
                                style: const TextStyle(color: Colors.red),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton(
                                onPressed: () {
                                  ref.invalidate(taskProvider);
                                },
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : taskState.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : tasks.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.task_alt_outlined,
                                size: 60,
                                color: Colors.white,
                              ),
                              SizedBox(height: 20),
                              Text(
                                'No tasks found',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          itemCount: tasks.length,
                          itemBuilder: (context, index) {
                            final task = tasks[index];
                            final taskName = task.name;
                            final taskDesc = task.description ?? "";
                            final taskCategory = task.category;
                            final isTaskCompleted = task.completed;

                            return Consumer(
                              builder: (context, ref, child) {
                                final isDeleting = ref.watch(
                                  isDeletingTaskProvider,
                                );
                                return Dismissible(
                                  key: Key(task.id.toString()),
                                  direction: DismissDirection.endToStart,
                                  confirmDismiss: (direction) async {
                                    if (isDeleting) return false;
                                    await confirmAndDelete(task.id, taskName);
                                    return false;
                                  },
                                  background: Container(
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(6),
                                      color: isDeleting
                                          ? Colors.grey
                                          : const Color(0xffe3664d),
                                    ),
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.only(right: 20),
                                    child: isDeleting
                                        ? const SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.delete_outline,
                                            color: Colors.white,
                                            size: 30,
                                          ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 6,
                                    ),
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.all(15),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6),
                                        side: BorderSide(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                          width: 0.5,
                                        ),
                                      ),
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                TaskDetailPage(task: task),
                                          ),
                                        );
                                      },
                                      leading: Consumer(
                                        builder: (context, ref, child) {
                                          final isToggling = ref.watch(
                                            isTogglingTaskProvider,
                                          );
                                          return Checkbox(
                                            value: isTaskCompleted,
                                            onChanged: isToggling
                                                ? null
                                                : (value) async {
                                                    if (value != null) {
                                                      await ref
                                                          .read(
                                                            taskProvider
                                                                .notifier,
                                                          )
                                                          .toggleTaskCompletion(
                                                            task.id,
                                                            value,
                                                          );
                                                    }
                                                  },
                                            activeColor: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                          );
                                        },
                                      ),
                                      title: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              taskName,
                                              style: TextStyle(
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.onPrimary,
                                                fontWeight: FontWeight.bold,
                                                decoration: isTaskCompleted
                                                    ? TextDecoration.lineThrough
                                                    : null,
                                              ),
                                            ),
                                          ),
                                          if (isTaskCompleted)
                                            Icon(
                                              Icons.check_circle,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                              size: 20,
                                            ),
                                        ],
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (taskDesc.isNotEmpty)
                                            Text(
                                              taskDesc,
                                              style: TextStyle(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onPrimary
                                                    .withValues(alpha: 0.7),
                                                decoration: isTaskCompleted
                                                    ? TextDecoration.lineThrough
                                                    : null,
                                              ),
                                            ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .primary
                                                      .withValues(alpha: 0.2),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  taskCategory,
                                                  style: TextStyle(
                                                    color: Theme.of(
                                                      context,
                                                    ).colorScheme.primary,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),

                                              // Collaboration indicator
                                              if (task.collaboratorCount >
                                                  0) ...[
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.blue
                                                        .withValues(alpha: 0.2),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      const Icon(
                                                        Icons.people,
                                                        size: 10,
                                                        color: Colors.blue,
                                                      ),
                                                      const SizedBox(width: 2),
                                                      Text(
                                                        '${task.collaboratorCount}',
                                                        style: const TextStyle(
                                                          color: Colors.blue,
                                                          fontSize: 10,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                              ],

                                              Text(
                                                isTaskCompleted
                                                    ? "Completed"
                                                    : "Pending",
                                                style: TextStyle(
                                                  color: isTaskCompleted
                                                      ? Theme.of(
                                                          context,
                                                        ).colorScheme.primary
                                                      : Theme.of(context)
                                                            .colorScheme
                                                            .onPrimary
                                                            .withValues(
                                                              alpha: 0.6,
                                                            ),
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      trailing: IconButton(
                                        onPressed: () {
                                          updateExistingTask(task);
                                        },
                                        icon: const Icon(
                                          Icons.edit_outlined,
                                          color: Color(0xff38b17d),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            onPressed: addNewTask,
            child: const Icon(Icons.create_outlined),
          ),
        );
      },
    );
  }
}
