import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/task_provider.dart';
import '../utils/custom_appbar.dart';
import 'task_detail_page.dart';

class CompletedTasksPage extends ConsumerWidget {
  const CompletedTasksPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completedTasks = ref.watch(completedTasksProvider);
    final taskState = ref.watch(taskProvider);

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
                  : completedTasks.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: 60,
                            color: Colors.white,
                          ),
                          SizedBox(height: 20),
                          Text(
                            'No completed tasks yet',
                            style: TextStyle(color: Colors.white),
                          ),
                          SizedBox(height: 10),
                          Text(
                            'Complete some tasks to see them here',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      itemCount: completedTasks.length,
                      itemBuilder: (context, index) {
                        final task = completedTasks[index];
                        final taskName = task.name;
                        final taskDesc = task.description ?? "";
                        final taskCategory = task.category;

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
                                final shouldDelete = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text("Delete Task"),
                                    content: Text(
                                      "Are you sure you want to delete \"$taskName\"?",
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text("Cancel"),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        child: const Text("Delete"),
                                      ),
                                    ],
                                  ),
                                );

                                if (shouldDelete == true) {
                                  final message = await ref
                                      .read(taskProvider.notifier)
                                      .deleteTask(task.id);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(message),
                                        action: message.contains('Failed')
                                            ? SnackBarAction(
                                                label: 'Retry',
                                                onPressed: () => ref
                                                    .read(taskProvider.notifier)
                                                    .deleteTask(task.id),
                                              )
                                            : null,
                                      ),
                                    );
                                  }
                                }
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
                                        builder: (context) => TaskDetailPage(task: task),
                                      ),
                                    );
                                  },
                                  leading: Consumer(
                                    builder: (context, ref, child) {
                                      final isToggling = ref.watch(
                                        isTogglingTaskProvider,
                                      );
                                      return Checkbox(
                                        value:
                                            true, // Always true for completed tasks
                                        onChanged: isToggling
                                            ? null
                                            : (value) async {
                                                if (value != null && !value) {
                                                  final message = await ref
                                                      .read(
                                                        taskProvider.notifier,
                                                      )
                                                      .toggleTaskCompletion(
                                                        task.id,
                                                        false,
                                                      );
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      SnackBar(
                                                        content: Text(message),
                                                      ),
                                                    );
                                                  }
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
                                            decoration:
                                                TextDecoration.lineThrough,
                                          ),
                                        ),
                                      ),
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
                                            decoration:
                                                TextDecoration.lineThrough,
                                          ),
                                        ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
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
                                           if (task.collaboratorCount > 0) ...[
                                             Container(
                                               padding: const EdgeInsets.symmetric(
                                                 horizontal: 6,
                                                 vertical: 2,
                                               ),
                                               decoration: BoxDecoration(
                                                 color: Colors.blue.withValues(alpha: 0.2),
                                                 borderRadius: BorderRadius.circular(10),
                                               ),
                                               child: Row(
                                                 mainAxisSize: MainAxisSize.min,
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
                                                       fontWeight: FontWeight.w500,
                                                     ),
                                                   ),
                                                 ],
                                               ),
                                             ),
                                             const SizedBox(width: 8),
                                           ],
                                           
                                           Text(
                                             "Completed",
                                            style: TextStyle(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
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
    );
  }
}
