import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(HomePage());
}

class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Task Manager',
      home: TaskPage(),
    );
  }
}

class Task {
  String id;
  String title;
  String description;
  DateTime deadline;
  Duration expectedDuration;
  bool isComplete;

  Task({
    required this.id,
    required this.title,
    required this.description,
    required this.deadline,
    required this.expectedDuration,
    required this.isComplete,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'deadline': deadline.toIso8601String(),
      'expectedDuration': expectedDuration.inMinutes,
      'isComplete': isComplete,
    };
  }

  static Task fromMap(String id, Map<String, dynamic> map) {
    return Task(
      id: id,
      title: map['title'],
      description: map['description'],
      deadline: DateTime.parse(map['deadline']),
      expectedDuration: Duration(minutes: map['expectedDuration']),
      isComplete: map['isComplete'],
    );
  }
}

class TaskPage extends StatefulWidget {
  @override
  _TaskPageState createState() => _TaskPageState();
}

class _TaskPageState extends State<TaskPage> {
  final CollectionReference taskCollection =
      FirebaseFirestore.instance.collection('tasks');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Task Manager'),
      ),
      body: StreamBuilder(
        stream: taskCollection.snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          final tasks = snapshot.data!.docs.map((doc) {
            return Task.fromMap(doc.id, doc.data() as Map<String, dynamic>);
          }).toList();

          return ListView.builder(
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final task = tasks[index];
              return ListTile(
                title: Text(task.title),
                subtitle: Text(task.description),
                trailing: Checkbox(
                  value: task.isComplete,
                  onChanged: (bool? value) {
                    setState(() {
                      task.isComplete = value ?? false;
                      updateTask(task);
                    });
                  },
                ),
                onLongPress: () => deleteTask(task.id),
                onTap: () => showTaskDialog(context, task),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showTaskDialog(context, null),
        icon: Icon(Icons.add),
        label: Text("Add Task"),
      ),
    );
  }

  Future<void> createTask(Task task) async {
    await taskCollection.add(task.toMap());
  }

  Future<void> updateTask(Task task) async {
    await taskCollection.doc(task.id).update(task.toMap());
  }

  Future<void> deleteTask(String id) async {
    await taskCollection.doc(id).delete();
  }

  void showTaskDialog(BuildContext context, Task? task) {
    final titleController = TextEditingController(text: task?.title);
    final descriptionController = TextEditingController(text: task?.description);
    final deadlineController = TextEditingController(text: task?.deadline.toIso8601String());
    final durationController = TextEditingController(text: task?.expectedDuration.inMinutes.toString());

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(task == null ? 'New Task' : 'Edit Task'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: InputDecoration(labelText: 'Title'),
              ),
              TextField(
                controller: descriptionController,
                decoration: InputDecoration(labelText: 'Description'),
              ),
              TextField(
                controller: deadlineController,
                decoration: InputDecoration(labelText: 'Deadline (YYYY-MM-DD HH:MM:SS)'),
              ),
              TextField(
                controller: durationController,
                decoration: InputDecoration(labelText: 'Expected Duration (in minutes)'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final newTask = Task(
                  id: task?.id ?? '',
                  title: titleController.text,
                  description: descriptionController.text,
                  deadline: DateTime.parse(deadlineController.text),
                  expectedDuration: Duration(minutes: int.parse(durationController.text)),
                  isComplete: task?.isComplete ?? false,
                );

                if (task == null) {
                  createTask(newTask);
                } else {
                  updateTask(newTask);
                }

                Navigator.of(context).pop();
              },
              child: Text(task == null ? 'Create' : 'Update'),
            ),
          ],
        );
      },
    );
  }
}
