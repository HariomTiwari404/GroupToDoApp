import 'package:auto_size_text/auto_size_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../service/todo_service.dart';

class TaskCard extends StatelessWidget {
  final DocumentSnapshot todo;
  final TodoService todoService;

  const TaskCard({
    super.key,
    required this.todo,
    required this.todoService,
  });

  String _getRelativeDateLabel(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final yesterday = today.subtract(const Duration(days: 1));

    if (dateTime.isAfter(today) && dateTime.isBefore(tomorrow)) {
      return "Today";
    } else if (dateTime.isBefore(today) && dateTime.isAfter(yesterday)) {
      return "Yesterday";
    } else if (dateTime.isAfter(tomorrow)) {
      return "Tomorrow";
    } else {
      return DateFormat('dd/MM/yyyy').format(dateTime);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = todo.data() as Map<String, dynamic>?;
    final bool isCompleted = data?['completed'] ?? false;
    final String taskText = data?['text'] ?? 'No Description';

    Timestamp? startTimestamp = data?['startTime'];
    Timestamp? endTimestamp = data?['endTime'];

    DateTime? startTime = startTimestamp?.toDate();
    DateTime? endTime = endTimestamp?.toDate();

    final Color statusColor = isCompleted ? Colors.green : Colors.orange;

    String formattedStartTime = startTime != null
        ? "${_getRelativeDateLabel(startTime)} ${DateFormat('hh:mm a').format(startTime)}"
        : 'N/A';

    String formattedEndTime = endTime != null
        ? "${_getRelativeDateLabel(endTime)} ${DateFormat('hh:mm a').format(endTime)}"
        : 'N/A';

    return GestureDetector(
      onTap: () {},
      child: Card(
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                isCompleted ? Colors.green.shade100 : Colors.teal.shade50,
                isCompleted ? Colors.green.shade200 : Colors.teal.shade100,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 8,
                    height: 40,
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AutoSizeText(
                          taskText,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: isCompleted
                                ? Colors.grey.shade600
                                : Colors.black87,
                            decoration: isCompleted
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                          ),
                          maxLines: 2,
                          minFontSize: 14,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.play_arrow,
                                size: 16, color: Colors.grey.shade700),
                            const SizedBox(width: 4),
                            Expanded(
                              child: AutoSizeText(
                                formattedStartTime,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade700,
                                ),
                                maxLines: 1,
                                minFontSize: 10,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Icon(Icons.stop,
                                size: 16, color: Colors.grey.shade700),
                            const SizedBox(width: 4),
                            Expanded(
                              child: AutoSizeText(
                                formattedEndTime,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade700,
                                ),
                                maxLines: 1,
                                minFontSize: 10,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      isCompleted
                          ? Icons.check_circle_outline
                          : Icons.radio_button_unchecked,
                      color: isCompleted ? Colors.green : Colors.teal,
                      size: 28,
                    ),
                    onPressed: () {
                      todoService.toggleTodoCompletion(todo.id, isCompleted);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      _showDeleteConfirmation(context, todoService, todo.id);
                    },
                    icon: const Icon(Icons.delete, color: Colors.white),
                    label: const AutoSizeText(
                      'Delete',
                      maxLines: 1,
                      minFontSize: 12,
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Method to show a confirmation dialog before deleting a to-do
  Future<bool?> _showDeleteConfirmation(
      BuildContext context, TodoService service, String todoId) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey.shade800, // Dark background for dialog
          title: const Text(
            'Delete To-Do',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Are you sure you want to delete this to-do?',
            style: TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false), // Cancel
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white),
              ),
            ),
            TextButton(
              onPressed: () {
                service.deleteTodo(todoId);
                Navigator.of(context).pop(true); // Confirm deletion
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('To-Do deleted successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }
}
