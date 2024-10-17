import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:getitdone/pages/sharedTodo/friends_page.dart';
import 'package:getitdone/push_notifications/push_notification_service.dart';
import 'package:intl/intl.dart';

import 'group_task_card.dart'; // Import custom GroupTaskCard

class GroupTodosPage extends StatefulWidget {
  final String groupId;

  const GroupTodosPage({super.key, required this.groupId});

  @override
  _GroupTodosPageState createState() => _GroupTodosPageState();
}

class _GroupTodosPageState extends State<GroupTodosPage> {
  final TextEditingController taskController = TextEditingController();
  final TextEditingController startTimeController = TextEditingController();
  final TextEditingController endTimeController = TextEditingController();

  DateTime? _selectedStartTime;
  DateTime? _selectedEndTime;
  bool _hasPendingFriendRequests = false;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void dispose() {
    taskController.dispose();
    startTimeController.dispose();
    endTimeController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    // Listen for pending friend requests and update the state
    FirebaseFirestore.instance
        .collection('friend_requests')
        .where('to', isEqualTo: FirebaseAuth.instance.currentUser!.uid)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _hasPendingFriendRequests = snapshot.docs.isNotEmpty;
        });
      }
    });
  }

  // Format date/time based on conditions
  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return 'N/A';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    if (dateTime.isAfter(today) && dateTime.isBefore(tomorrow)) {
      return "Today ${DateFormat('hh:mm a').format(dateTime)}";
    } else if (dateTime.isAfter(tomorrow) &&
        dateTime.isBefore(tomorrow.add(const Duration(days: 1)))) {
      return "Tomorrow ${DateFormat('hh:mm a').format(dateTime)}";
    } else {
      return DateFormat('dd/MM/yyyy hh:mm a').format(dateTime);
    }
  }

  // Function to select Date and Time
  Future<void> _pickDateTime(
      TextEditingController controller, bool isStart) async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    if (pickedDate != null) {
      TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (pickedTime != null) {
        DateTime fullDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );

        setState(() {
          controller.text = _formatDateTime(fullDateTime);
          if (isStart) {
            _selectedStartTime = fullDateTime;
          } else {
            _selectedEndTime = fullDateTime;
          }
        });
      }
    }
  }

  // Function to add a new task
  Future<void> _addTask() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    // Fetch the user's username (who is adding the task)
    DocumentSnapshot userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();
    String creatorName = userDoc['username'] ?? 'Unknown User';

    String task = taskController.text.trim();
    if (task.isEmpty) return;

    try {
      await FirebaseFirestore.instance.collection('group_todos').add({
        'groupId': widget.groupId,
        'task': task,
        'creatorId': currentUser.uid,
        'creatorName': creatorName, // Store creator's name
        'startTime': _selectedStartTime != null
            ? Timestamp.fromDate(_selectedStartTime!)
            : null,
        'endTime': _selectedEndTime != null
            ? Timestamp.fromDate(_selectedEndTime!)
            : null,
        'completed': false,
        'tickedBy': null, // No one has marked it complete initially
        'timestamp': FieldValue.serverTimestamp(),
      });

      taskController.clear();
      startTimeController.clear();
      endTimeController.clear();

      // Notify group members with the creator's name
      await _notifyGroupMembers(task, creatorName);

      print('📋 Task added and group members notified!');
    } catch (e) {
      print('Error adding task: $e');
    }
  }

  Future<void> _notifyGroupMembers(String taskName, String creatorName) async {
    try {
      // Get group details to fetch members
      DocumentSnapshot groupSnapshot = await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .get();

      if (!groupSnapshot.exists) return;
      List<dynamic> members = groupSnapshot['members'];

      for (String memberId in members) {
        // Get each member's device tokens
        QuerySnapshot tokensSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(memberId)
            .collection('tokens')
            .get();

        List<String> tokens =
            tokensSnapshot.docs.map((doc) => doc['token'] as String).toList();

        // Send notification to all tokens
        for (String token in tokens) {
          await PushNotificationService.sendNotificationToUser(
            token,
            '📋 New Task from $creatorName!',
            '👀 Don’t forget: "$taskName" has been added to your group tasks!',
          );
        }
      }

      print('📲 Group members notified!');
    } catch (e) {
      print('🚨 Error notifying group members: $e');
    }
  }

  // Function to delete a task
  Future<void> _deleteTask(String taskId) async {
    await FirebaseFirestore.instance
        .collection('group_todos')
        .doc(taskId)
        .delete();
  }

  // Function to delete the group
  Future<void> _deleteGroup() async {
    await FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupId)
        .delete();
    Navigator.pop(context); // Return to groups list
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Group deleted successfully.')),
    );
  }

  Future<void> _toggleTaskCompletion(String taskId, bool isCompleted) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return; // Ensure user is logged in

    try {
      // Fetch the username of the current user
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      String username = userDoc['username'] ?? 'Unknown User';

      // Fetch the task from Firestore to get the task name
      final taskDoc = await FirebaseFirestore.instance
          .collection('group_todos')
          .doc(taskId)
          .get();
      String taskName = taskDoc['task'] ?? 'Unnamed Task';

      // Update the task completion status and tickedBy field
      await FirebaseFirestore.instance
          .collection('group_todos')
          .doc(taskId)
          .update({
        'completed': !isCompleted, // Toggle the completion status
        'tickedBy': !isCompleted ? username : null, // Update `tickedBy`
      });

      print(
          '✅ Task ${!isCompleted ? 'completed' : 'uncompleted'} by $username');

      // Optionally notify group members of the status change
      await _notifyTaskStatusChange(taskName, username, !isCompleted);
    } catch (e) {
      print('🚨 Error updating task status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating task status: $e')),
      );
    }
  }

  Widget _buildTaskCard(DocumentSnapshot task) {
    final taskData = task.data() as Map<String, dynamic>;
    final bool isCompleted = taskData['completed'] ?? false;
    final String? tickedBy = taskData['tickedBy'];

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        title: Text(
          taskData['task'] ?? 'Unnamed Task',
          style: TextStyle(
            decoration: isCompleted ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: isCompleted
            ? Text('Completed by: $tickedBy')
            : const Text('Pending'),
        trailing: Checkbox(
          value: isCompleted,
          onChanged: (value) async {
            await _toggleTaskCompletion(task.id, isCompleted);
          },
        ),
      ),
    );
  }

  Future<void> _notifyTaskStatusChange(
      String taskName, String username, bool isCompleted) async {
    try {
      String notificationTitle =
          isCompleted ? '✅ Task Completed!' : '⏳ Task Marked Incomplete';
      String notificationBody = isCompleted
          ? '🎉 "$username" completed the task "$taskName"!'
          : '⚠️ "$username" marked the task "$taskName" as incomplete.';

      // Get group members
      DocumentSnapshot groupSnapshot = await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .get();

      List<dynamic> members = groupSnapshot['members'];

      for (String memberId in members) {
        QuerySnapshot tokensSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(memberId)
            .collection('tokens')
            .get();

        List<String> tokens =
            tokensSnapshot.docs.map((doc) => doc['token'] as String).toList();

        for (String token in tokens) {
          await PushNotificationService.sendNotificationToUser(
            token,
            notificationTitle,
            notificationBody,
          );
        }
      }

      print('📲 Group members notified about task status change!');
    } catch (e) {
      print('🚨 Error notifying about task status change: $e');
    }
  }

  // Widget to build group info and member list
  // Widget to build group info and member list
  Widget _buildGroupInfo() {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return const Center(child: Text('Error loading group info.'));
        }

        final groupData = snapshot.data!.data() as Map<String, dynamic>;
        final members = groupData['members'] ?? [];
        final groupName = groupData['name'] ?? 'Unnamed Group';
        final creatorId = groupData['creator']; // Get creator ID
        final currentUserId = FirebaseAuth.instance.currentUser!.uid;

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Text(
                groupName,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text('${members.length} members'),
              Expanded(
                child: ListView.builder(
                  itemCount: members.length,
                  itemBuilder: (context, index) {
                    final memberId = members[index];

                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('users')
                          .doc(memberId)
                          .get(),
                      builder: (context, userSnapshot) {
                        if (userSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const ListTile(
                            title: Text('Loading...'),
                          );
                        }
                        if (userSnapshot.hasError ||
                            !userSnapshot.hasData ||
                            !userSnapshot.data!.exists) {
                          return const ListTile(
                            title: Text('User not found'),
                          );
                        }

                        final userData =
                            userSnapshot.data!.data() as Map<String, dynamic>;
                        final username = userData['username'] ?? 'Unknown User';

                        return ListTile(
                          title: Text(username),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              // Show Delete Group button only if the current user is the creator
              if (currentUserId == creatorId)
                ElevatedButton.icon(
                  onPressed: _deleteGroup,
                  icon: const Icon(Icons.delete, color: Colors.red),
                  label: const Text('Delete Group'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

// Text field decoration (to ensure consistency)
  InputDecoration _buildInputDecoration(String labelText) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: const TextStyle(
        color: Colors.teal,
        fontWeight: FontWeight.bold,
        fontSize: 16,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: const BorderSide(
          color: Colors.teal,
          width: 2,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      filled: true,
      fillColor: Colors.grey.shade100,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.teal,
        elevation: 4,
        title: FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('groups')
              .doc(widget.groupId)
              .get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return const Text('Error loading group name');
            }

            final groupData = snapshot.data!.data() as Map<String, dynamic>;
            final groupName = groupData['name'] ?? 'Unnamed Group';

            // Calculate adaptive font size based on screen width
            double adaptiveFontSize = MediaQuery.of(context).size.width * 0.05;

            return Text(
              groupName,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize:
                    adaptiveFontSize.clamp(18, 30), // Clamp size for balance
              ),
              overflow: TextOverflow.ellipsis, // Handle long names gracefully
            );
          },
        ),
        actions: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal.shade700,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: Stack(
              children: [
                const Icon(Icons.people, color: Colors.white, size: 28),
                if (_hasPendingFriendRequests) // Red dot indicator
                  const Positioned(
                    right: 0,
                    top: 0,
                    child: CircleAvatar(
                      radius: 5,
                      backgroundColor: Colors.red,
                    ),
                  ),
              ],
            ),
            label: Text(
              'Friends',
              style: TextStyle(
                fontSize: MediaQuery.of(context).size.width * 0.01,
                color: Colors.white,
              ),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FriendsPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.teal.shade700,
              Colors.teal.shade500,
              Colors.teal.shade300,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: taskController,
                      decoration: _buildInputDecoration('New Task'),
                      style: const TextStyle(
                        color: Colors.black, // Text color set to black
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _addTask,
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      backgroundColor: Colors.teal,
                      padding: const EdgeInsets.all(16),
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 28),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: startTimeController,
                      readOnly: true,
                      decoration: _buildInputDecoration('Start Time'),
                      style: const TextStyle(
                        color: Colors.black, // Text color set to black
                        fontSize: 16,
                      ),
                      onTap: () => _pickDateTime(startTimeController, true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: endTimeController,
                      readOnly: true,
                      decoration: _buildInputDecoration('End Time'),
                      style: const TextStyle(
                        color: Colors.black, // Text color set to black
                        fontSize: 16,
                      ),
                      onTap: () => _pickDateTime(endTimeController, false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('group_todos')
                    .where('groupId', isEqualTo: widget.groupId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return const Center(child: Text('Error loading tasks.'));
                  }

                  final tasks = snapshot.data?.docs ?? [];
                  if (tasks.isEmpty) {
                    return const Center(child: Text('No tasks available.'));
                  }

                  return ListView.builder(
                    itemCount: tasks.length,
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      return GroupTaskCard(
                        task: task,
                        onDelete: () {
                          FirebaseFirestore.instance
                              .collection('group_todos')
                              .doc(task.id)
                              .delete();
                        },
                        onToggleCompleted: (value) async {
                          final taskData = task.data() as Map<String, dynamic>;
                          final bool isCompleted =
                              taskData['completed'] ?? false;
                          await _toggleTaskCompletion(task.id, isCompleted);
                        },
                      );
                    },
                  );
                },
              )),
            ],
          ),
        ),
      ),
    );
  }
}
