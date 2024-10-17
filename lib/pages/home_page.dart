import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:getitdone/pages/profile.dart';
import 'package:getitdone/pages/sharedTodo/groups_page.dart';
import 'package:getitdone/service/auth_service.dart';
import 'package:getitdone/service/todo_service.dart';
import 'package:getitdone/widgets/todo_card.dart';
import 'package:intl/intl.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  DashboardPageState createState() => DashboardPageState();
}

class DashboardPageState extends State<DashboardPage> {
  final AuthService _authService = AuthService();
  final TextEditingController _todoController = TextEditingController();
  final TextEditingController _startTimeController = TextEditingController();
  final TextEditingController _endTimeController = TextEditingController();
  late User user;
  late TodoService _todoService;
  bool _hasPendingFriendRequests = false; // Track pending friend requests
  bool _hasUnseenComments = false; // Track unseen comments
  DateTime? _selectedStartTime;
  DateTime? _selectedEndTime;

  bool _isDisposed = false; // To track whether the widget is disposed
  // Maintain a list of current groups
  List<QueryDocumentSnapshot> _currentGroups = [];
  @override
  void initState() {
    super.initState();

    // Access the user from FirebaseAuth
    user = FirebaseAuth.instance.currentUser!;
    _todoService = TodoService(user);

    // Listen for pending friend requests
    FirebaseFirestore.instance
        .collection('friend_requests')
        .where('to', isEqualTo: user.uid)
        .snapshots()
        .listen((snapshot) {
      setState(() {
        _hasPendingFriendRequests = snapshot.docs.isNotEmpty;
      });
    });

    // Listen for changes in groups and check for unseen comments
    FirebaseFirestore.instance
        .collection('groups')
        .where('members', arrayContains: user.uid)
        .snapshots()
        .listen((groupsSnapshot) {
      if (!_isDisposed) {
        setState(() {
          _currentGroups = groupsSnapshot.docs;
        });
        _updateUnseenCommentsStatus(_currentGroups);
      }
    });

    // Listen for changes in the user's document (specifically lastViewedComments)
    FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((userSnapshot) {
      if (!_isDisposed && userSnapshot.exists) {
        _updateUnseenCommentsStatus(_currentGroups);
      }
    });
  }

  /// Checks if any group has unseen comments
  Future<void> _updateUnseenCommentsStatus(
      List<QueryDocumentSnapshot> groups) async {
    bool anyGroupHasUnseen = false;
    for (var group in groups) {
      String groupId = group.id;
      bool hasUnseen = await _hasGroupUnseenComments(groupId);
      if (hasUnseen) {
        anyGroupHasUnseen = true;
        break;
      }
    }

    if (!_isDisposed) {
      setState(() {
        _hasUnseenComments = anyGroupHasUnseen;
      });
    }
  }

  /// Checks if a specific group has any unseen comments.
  Future<bool> _hasGroupUnseenComments(String groupId) async {
    String currentUserId = user.uid;

    try {
      // Fetch all tasks in the group
      QuerySnapshot tasksSnapshot = await FirebaseFirestore.instance
          .collection('group_todos')
          .where('groupId', isEqualTo: groupId)
          .get();

      if (tasksSnapshot.docs.isEmpty) return false;

      // Fetch user document
      DocumentSnapshot userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .get();

      if (!userSnapshot.exists) return false;

      Map<String, dynamic>? lastViewedMap =
          userSnapshot.get('lastViewedComments') as Map<String, dynamic>?;

      for (var task in tasksSnapshot.docs) {
        String taskId = task.id;
        Timestamp? lastViewedTimestamp;
        if (lastViewedMap != null && lastViewedMap.containsKey(taskId)) {
          lastViewedTimestamp = lastViewedMap[taskId] as Timestamp;
        }

        // Fetch latest comment
        QuerySnapshot latestCommentSnapshot = await FirebaseFirestore.instance
            .collection('group_todos')
            .doc(taskId)
            .collection('comments')
            .orderBy('timestamp', descending: true)
            .limit(1)
            .get();

        if (latestCommentSnapshot.docs.isEmpty) continue;

        Timestamp latestCommentTimestamp =
            latestCommentSnapshot.docs.first['timestamp'] as Timestamp;

        if (lastViewedTimestamp == null ||
            latestCommentTimestamp
                .toDate()
                .isAfter(lastViewedTimestamp.toDate())) {
          return true; // Unseen comment found
        }
      }

      return false; // No unseen comments
    } catch (e) {
      print('Error checking unseen comments for group $groupId: $e');
      return false;
    }
  }

  @override
  void dispose() {
    _isDisposed = true; // Mark the widget as disposed
    _todoController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    super.dispose();
  }

  // Add a new to-do
  Future<void> _addTodo() async {
    if (_isDisposed) return; // Don't proceed if the widget is disposed

    String todoText = _todoController.text.trim();
    if (todoText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('To-Do text cannot be empty'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    if (_selectedStartTime != null &&
        _selectedEndTime != null &&
        _selectedEndTime!.isBefore(_selectedStartTime!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('End time should be after the start time'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    try {
      // Add the to-do to Firestore
      await _todoService.addTodo(todoText, true,
          startTime: _selectedStartTime, endTime: _selectedEndTime);

      _todoController.clear();
      _startTimeController.clear();
      _endTimeController.clear();
      setState(() {
        _selectedStartTime = null;
        _selectedEndTime = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('To-Do added successfully'),
            backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!_isDisposed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to add to-do: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  // Method to pick date and time for start or end
  Future<void> _pickDateTime(
      TextEditingController controller, bool isStart) async {
    DateTime initialDate = DateTime.now();

    // Set the initial date to the selected start or end time if already picked
    if (isStart && _selectedStartTime != null) {
      initialDate = _selectedStartTime!;
    } else if (!isStart && _selectedEndTime != null) {
      initialDate = _selectedEndTime!;
    }

    // Show Date Picker
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    if (pickedDate != null) {
      // Show Time Picker
      TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initialDate),
      );

      if (pickedTime != null) {
        DateTime fullDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );

        // Set the selected date and time
        setState(() {
          controller.text = DateFormat('dd/MM/yyyy HH:mm').format(fullDateTime);
          if (isStart) {
            _selectedStartTime = fullDateTime;
          } else {
            _selectedEndTime = fullDateTime;
          }
        });
      }
    }
  }

  Future<void> _signOut() async {
    await _authService.signOut();

    // After signing out, navigate to the login page and clear the navigation stack
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    Query todosQuery = FirebaseFirestore.instance
        .collection('todos')
        .where('uid', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'GET IT DONE',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.teal,
        elevation: 4,
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
                const Icon(Icons.group, color: Colors.white),
                if (_hasPendingFriendRequests || _hasUnseenComments)
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
            label: const Text('Groups', style: TextStyle(color: Colors.white)),
            onPressed: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const GroupsPage(),
                  )).then((_) {
                // Refresh the state when returning from GroupsPage
                if (!_isDisposed) {
                  setState(() {});
                }
              });
            },
          ),
          const SizedBox(width: 8),

          // Popup Menu for Less Important Options
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white, size: 28),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            color: Colors.white,
            elevation: 8,
            onSelected: (value) {
              if (value == 'Profile') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfilePage(user: user),
                  ),
                );
              } else if (value == 'About') {
                Navigator.pushNamed(context, '/about');
              } else if (value == 'Logout') {
                _signOut();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'Profile',
                child: ListTile(
                  leading: Icon(Icons.person, color: Colors.teal),
                  title: Text(
                    'Profile',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
              const PopupMenuItem(
                value: 'About',
                child: ListTile(
                  leading: Icon(Icons.info, color: Colors.blueAccent),
                  title: Text(
                    'About',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
              const PopupMenuItem(
                value: 'Logout',
                child: ListTile(
                  leading: Icon(Icons.logout, color: Colors.red),
                  title: Text(
                    'Logout',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.red,
                    ),
                  ),
                ),
              ),
            ],
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
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(2, 4),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _todoController,
                            decoration: InputDecoration(
                              prefixIcon: const Padding(
                                padding: EdgeInsets.only(left: 12, right: 8),
                                child: Icon(Icons.list,
                                    color: Colors.teal, size: 28),
                              ),
                              labelText: 'New To-Do',
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
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 18, horizontal: 16),
                              hintText: "Enter task...",
                              hintStyle: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 14,
                              ),
                            ),
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 16,
                            ),
                            onSubmitted: (value) => _addTodo(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12.0),
                      ElevatedButton(
                        onPressed: _addTodo,
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          backgroundColor: Colors.teal,
                          padding: const EdgeInsets.all(16),
                        ),
                        child: const Icon(Icons.add,
                            color: Colors.white, size: 28),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(2, 4),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _startTimeController,
                            decoration: InputDecoration(
                              prefixIcon: const Padding(
                                padding: EdgeInsets.only(left: 12, right: 8),
                                child: Icon(Icons.access_time,
                                    color: Colors.teal, size: 28),
                              ),
                              labelText: 'Start Time',
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
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 18, horizontal: 16),
                              hintText: "Pick start time...",
                              hintStyle: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 14,
                              ),
                            ),
                            readOnly: true,
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 16,
                            ),
                            onTap: () =>
                                _pickDateTime(_startTimeController, true),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(2, 4),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _endTimeController,
                            decoration: InputDecoration(
                              prefixIcon: const Padding(
                                padding: EdgeInsets.only(left: 12, right: 8),
                                child: Icon(Icons.access_time,
                                    color: Colors.teal, size: 28),
                              ),
                              labelText: 'End Time',
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
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 18, horizontal: 16),
                              hintText: "Pick end time...",
                              hintStyle: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 14,
                              ),
                            ),
                            readOnly: true,
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 16,
                            ),
                            onTap: () =>
                                _pickDateTime(_endTimeController, false),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: todosQuery.snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error fetching to-dos: ${snapshot.error}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    );
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final todos = snapshot.data!.docs;

                  if (todos.isEmpty) {
                    return Center(
                      child: Text(
                        'No to-dos yet!',
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 18),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: todos.length,
                    itemBuilder: (context, index) {
                      var todo = todos[index];
                      return TaskCard(
                        todo: todo,
                        todoService: _todoService,
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
