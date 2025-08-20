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

  /*
  CREATE: Add a new task
  */
  final textController = TextEditingController();

  void addNewTask() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: TextField(controller: textController),
        actions: [
          // save button
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

  final Stream<List<Map<String, dynamic>>> _tasksStream = Supabase
      .instance
      .client
      .from('todo')
      .stream(primaryKey: ['id'])
      .order('id', ascending: true);

  /*
  UPDATE: Update an existing task
  */

  /*
  DELETE: Remove a task
  */
  void deleteTask(int id) async {
    await Supabase.instance.client.from('todo').delete().eq('id', id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Center(child: Text('Task deleted'))),
      );
    }
  }

  // dispose of controllers
  @override
  void dispose() {
    super.dispose();
    textController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // custom appbar
            CustomAppbar(),

            // body content fills the rest
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _tasksStream,
                builder: (context, snapshot) {
                  // loading...
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  // if no task found
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

                  // loaded
                  final tasks = snapshot.data!;

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: tasks.length,
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      final taskName = task['name'];

                      return Dismissible(
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
                        key: Key(task['id'].toString()),
                        direction: DismissDirection.endToStart,
                        onDismissed: (direction) {
                          deleteTask(task['id'] as int);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Task deleted: $taskName')),
                          );
                        },
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
                            trailing: IconButton(
                              onPressed: () {
                                deleteTask(task['id'] as int);
                              },
                              icon: const Icon(
                                Icons.delete,
                                color: Color(0xffe3664d),
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
        onPressed: addNewTask,
        child: const Icon(Icons.add),
      ),
    );
  }
}
