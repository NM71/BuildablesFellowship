import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:todo_supabase/utils/custom_appbar.dart';

class TaskPage extends StatefulWidget {
  const TaskPage({super.key});

  @override
  State<TaskPage> createState() => _TaskPageState();
}

class _TaskPageState extends State<TaskPage> {
  final textController = TextEditingController();
  final descController = TextEditingController();

  /* 
  CRUD Operations
  */

  // add a new task
  void addNewTask() {
    textController.clear();
    descController.clear();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Add New Task"),
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
              decoration: const InputDecoration(
                labelText: "Description (optional)",
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(onPressed: () => saveTask(), child: const Text("Save")),
        ],
      ),
    );
  }

  Future<void> saveTask() async {
    if (textController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Task name cannot be empty")),
      );
      return;
    }

    await Supabase.instance.client.from('todo').insert({
      'name': textController.text.trim(),
      'description': descController.text.trim().isNotEmpty
          ? descController.text.trim()
          : null,
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Center(child: Text('Task added: ${textController.text}')),
        ),
      );
      textController.clear();
      descController.clear();
      Navigator.pop(context);
    }
  }

  // Fetching all tasks
  final _tasksStream = Supabase.instance.client
      .from('todo')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false)
      .map((rows) => rows.cast<Map<String, dynamic>>());

  void updateExistingTask(int id, String currentName, String? currentDesc) {
    textController.text = currentName;
    descController.text = currentDesc ?? "";

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              if (textController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Task name cannot be empty")),
                );
                return;
              }
              await updateTask(
                id,
                textController.text.trim(),
                descController.text.trim(),
              );
              if (mounted) Navigator.pop(context);
            },
            child: const Text("Update"),
          ),
        ],
      ),
    );
  }

  Future<void> updateTask(int id, String newName, String newDesc) async {
    await Supabase.instance.client
        .from('todo')
        .update({
          'name': newName,
          'description': newDesc.isNotEmpty ? newDesc : null,
        })
        .eq('id', id);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Center(child: Text('Task updated to: $newName'))),
      );
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

  // deleting task
  Future<void> deleteTask(int id, String taskName) async {
    await Supabase.instance.client.from('todo').delete().eq('id', id);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Task deleted: $taskName')));
    }
  }

  @override
  void dispose() {
    textController.dispose();
    descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            CustomAppbar(),
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _tasksStream,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.data!.isEmpty) {
                    return const Center(
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
                    );
                  }

                  final tasks = snapshot.data!;

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: tasks.length,
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      final taskName = task['name'] ?? "";
                      final taskDesc = task['description'] ?? "";

                      return Dismissible(
                        key: Key(task['id'].toString()),
                        direction: DismissDirection.endToStart,
                        confirmDismiss: (direction) async {
                          await confirmAndDelete(task['id'] as int, taskName);
                          return false;
                        },
                        background: Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            color: const Color(0xffe3664d),
                          ),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(
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
                                color: Theme.of(context).colorScheme.primary,
                                width: 0.5,
                              ),
                            ),
                            title: Text(
                              taskName,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: taskDesc.isNotEmpty
                                ? Text(
                                    taskDesc,
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onPrimary
                                          .withValues(alpha: 0.7),
                                    ),
                                  )
                                : null,
                            trailing: IconButton(
                              onPressed: () {
                                updateExistingTask(
                                  task['id'] as int,
                                  taskName,
                                  taskDesc,
                                );
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
  }
}
