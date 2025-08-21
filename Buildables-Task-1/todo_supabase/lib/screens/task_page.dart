import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:todo_supabase/utils/custom_appbar.dart';

class TaskPage extends StatefulWidget {
  const TaskPage({super.key});

  @override
  State<TaskPage> createState() => _TaskPageState();
}

class _TaskPageState extends State<TaskPage> {
  // Basic CRUD Operations

  final textController = TextEditingController();

  void addNewTask() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: TextField(controller: textController),
        actions: [
          TextButton(
            onPressed: () {
              saveTask();
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  // Save task in db
  void saveTask() async {
    await Supabase.instance.client.from('todo').insert({
      'name': textController.text,
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Center(child: Text('Task added: ${textController.text}')),
        ),
      );
      textController.clear();
    }
    if (!mounted) return;
    Navigator.pop(context);
  }

  /*
  READ: Fetch all tasks
  */
  final _tasksStream = Supabase.instance.client
      .from('todo')
      .stream(primaryKey: ['id'])
      .order('id', ascending: true)
      .map((rows) => rows.cast<Map<String, dynamic>>());

  /*
  UPDATE: Update an existing task
  */
  void updateExistingTask(int id, String currentName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: TextField(controller: textController..text = currentName),
        actions: [
          TextButton(
            onPressed: () {
              updateTask(id, textController.text);
              Navigator.pop(context);
            },
            child: const Text("Update"),
          ),
        ],
      ),
    );
  }

  void updateTask(int id, String newName) async {
    await Supabase.instance.client
        .from('todo')
        .update({'name': newName})
        .eq('id', id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Center(child: Text('Task updated to: $newName'))),
      );
    }
  }

  /*
  DELETE: Remove a task with confirmation
  */
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
    await Supabase.instance.client.from('todo').delete().eq('id', id);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Task deleted: $taskName')));
    }
  }

  // dispose of controllers
  @override
  void dispose() {
    textController.dispose();
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
                      final taskName = task['name'];

                      return Dismissible(
                        key: Key(task['id'].toString()),
                        direction: DismissDirection.endToStart,
                        confirmDismiss: (direction) async {
                          await confirmAndDelete(task['id'] as int, taskName);
                          return false;
                        },
                        background: Container(
                          color: const Color(0xffe3664d),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(
                            Icons.delete,
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
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  onPressed: () {
                                    updateExistingTask(
                                      task['id'] as int,
                                      taskName,
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    color: Color(0xff38b17d),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                IconButton(
                                  onPressed: () {
                                    confirmAndDelete(
                                      task['id'] as int,
                                      taskName,
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Color(0xffe3664d),
                                  ),
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
      floatingActionButton: FloatingActionButton(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        onPressed: addNewTask,
        child: const Icon(Icons.create_outlined),
      ),
    );
  }
}
