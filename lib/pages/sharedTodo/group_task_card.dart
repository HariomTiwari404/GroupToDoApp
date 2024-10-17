import 'dart:async';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:getitdone/pages/sharedTodo/comments.dart';
import 'package:intl/intl.dart';

class GroupTaskCard extends StatefulWidget {
  final DocumentSnapshot task;
  final VoidCallback onDelete;
  final Function(bool?) onToggleCompleted;

  const GroupTaskCard({
    super.key,
    required this.task,
    required this.onDelete,
    required this.onToggleCompleted,
  });

  @override
  _GroupTaskCardState createState() => _GroupTaskCardState();
}

class _GroupTaskCardState extends State<GroupTaskCard> {
  bool _hasUnseenComments = false;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late StreamSubscription<QuerySnapshot> _commentsSubscription;
  late StreamSubscription<DocumentSnapshot> _userSubscription;

  DateTime? _lastViewed;

  @override
  void initState() {
    super.initState();
    _fetchLastViewed();
  }

  @override
  void dispose() {
    _commentsSubscription.cancel();
    _userSubscription.cancel();
    super.dispose();
  }

  // Fetch the last viewed timestamp from the user's document
  Future<void> _fetchLastViewed() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    // Listen to the user's document for changes in lastViewedComments
    _userSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .snapshots()
        .listen((userSnapshot) {
      if (userSnapshot.exists) {
        final userData = userSnapshot.data() as Map<String, dynamic>;
        final lastViewedMap =
            userData['lastViewedComments'] as Map<String, dynamic>?;

        setState(() {
          if (lastViewedMap != null &&
              lastViewedMap.containsKey(widget.task.id)) {
            _lastViewed = (lastViewedMap[widget.task.id] as Timestamp).toDate();
          } else {
            _lastViewed = null;
          }
        });

        _checkForUnseenComments();
        _listenForNewComments();
      }
    });
  }

  // Listen for new comments and update the red dot accordingly
  void _listenForNewComments() {
    final commentsQuery = FirebaseFirestore.instance
        .collection('group_todos')
        .doc(widget.task.id)
        .collection('comments')
        .orderBy('timestamp', descending: true)
        .limit(1); // Fetch the latest comment

    _commentsSubscription = commentsQuery.snapshots().listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        final latestComment = snapshot.docs.first;
        final commentTime = (latestComment['timestamp'] as Timestamp).toDate();

        setState(() {
          if (_lastViewed == null || commentTime.isAfter(_lastViewed!)) {
            _hasUnseenComments = true;
          } else {
            _hasUnseenComments = false;
          }
        });
      } else {
        setState(() {
          _hasUnseenComments = false;
        });
      }
    });
  }

  // Check if there are unseen comments based on lastViewed
  Future<void> _checkForUnseenComments() async {
    if (_lastViewed == null) {
      // If never viewed, check if any comments exist
      final commentsSnapshot = await FirebaseFirestore.instance
          .collection('group_todos')
          .doc(widget.task.id)
          .collection('comments')
          .limit(1)
          .get();

      setState(() {
        _hasUnseenComments = commentsSnapshot.docs.isNotEmpty;
      });
    } else {
      // Check if there are comments after lastViewed
      final unseenComments = await FirebaseFirestore.instance
          .collection('group_todos')
          .doc(widget.task.id)
          .collection('comments')
          .where('timestamp', isGreaterThan: Timestamp.fromDate(_lastViewed!))
          .limit(1)
          .get();

      setState(() {
        _hasUnseenComments = unseenComments.docs.isNotEmpty;
      });
    }
  }

  // Navigate to Comments Page and update lastViewed
  Future<void> _navigateToComments() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CommentsPage(taskId: widget.task.id),
      ),
    );
    await _updateLastViewed();
  }

  Future<void> _updateLastViewed() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final userRef =
        FirebaseFirestore.instance.collection('users').doc(currentUser.uid);

    await userRef.update({
      'lastViewedComments.${widget.task.id}': FieldValue.serverTimestamp(),
    });

    print('✅ Updated lastViewedComments for task ${widget.task.id}');

    // Fetch the updated lastViewedComments to verify
    DocumentSnapshot updatedUser = await userRef.get();
    Map<String, dynamic>? updatedMap =
        updatedUser.get('lastViewedComments') as Map<String, dynamic>?;

    if (updatedMap != null && updatedMap.containsKey(widget.task.id)) {
      Timestamp updatedTimestamp = updatedMap[widget.task.id];
      print(
          '🔍 New lastViewed timestamp for ${widget.task.id}: ${updatedTimestamp.toDate()}');
    } else {
      print(
          '🚨 Failed to update lastViewedComments for task ${widget.task.id}');
    }
  }

  // Format date and time with "Today" and "Tomorrow" logic
  String _formatDateTime(Timestamp? timestamp) {
    if (timestamp == null) return 'N/A';

    DateTime date = timestamp.toDate();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    if (date.isAfter(today) && date.isBefore(tomorrow)) {
      return "Today ${DateFormat('hh:mm a').format(date)}";
    } else if (date.isAfter(tomorrow) &&
        date.isBefore(tomorrow.add(const Duration(days: 1)))) {
      return "Tomorrow ${DateFormat('hh:mm a').format(date)}";
    } else {
      return DateFormat('dd/MM/yyyy hh:mm a').format(date);
    }
  }

  // Fetch the username from Firestore using the user ID
  Future<String> _fetchUsername(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      return userDoc.data()?['username'] ?? 'Unknown';
    } catch (e) {
      return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.task.data() as Map<String, dynamic>?;
    final String taskName = data?['task'] ?? 'No Task Name';
    final String creatorId = data?['creatorId'] ?? 'Unknown';
    final bool isCompleted = data?['completed'] ?? false;
    final String? tickedBy = data?['tickedBy'];
    final startTime = _formatDateTime(data?['startTime']);
    final endTime = _formatDateTime(data?['endTime']);
    final Color completedColor = Colors.green.shade100;
    final Color pendingColor = Colors.teal.shade50;

    return FutureBuilder<String>(
        future: _fetchUsername(creatorId),
        builder: (context, snapshot) {
          final creatorUsername = snapshot.data ?? 'Loading...';
          return Card(
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    isCompleted ? completedColor : pendingColor,
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
                  // Task Title and Completion Icon
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Task Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AutoSizeText(
                              taskName,
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
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            AutoSizeText(
                              'Added by: $creatorUsername',
                              style: TextStyle(
                                  fontSize: 14, color: Colors.grey.shade600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (isCompleted && tickedBy != null) ...[
                              const SizedBox(height: 4),
                              AutoSizeText(
                                'Completed by: $tickedBy',
                                style: TextStyle(
                                    fontSize: 14, color: Colors.green.shade700),
                              ),
                            ],
                          ],
                        ),
                      ),
                      // Completion Icon
                      IconButton(
                        icon: Icon(
                          isCompleted
                              ? Icons.check_circle_outline
                              : Icons.radio_button_unchecked,
                          color: isCompleted ? Colors.green : Colors.teal,
                          size: 28,
                        ),
                        onPressed: () async {
                          // Determine the new completion status
                          bool newStatus = !isCompleted;

                          // Invoke the callback with the new status
                          widget.onToggleCompleted(newStatus);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Start and End Time
                  Row(
                    children: [
                      Icon(Icons.play_arrow,
                          size: 16, color: Colors.grey.shade700),
                      const SizedBox(width: 4),
                      Expanded(
                        child: AutoSizeText(
                          'Start: $startTime',
                          style: TextStyle(
                              fontSize: 14, color: Colors.grey.shade700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(Icons.stop, size: 16, color: Colors.grey.shade700),
                      const SizedBox(width: 4),
                      Expanded(
                        child: AutoSizeText(
                          'End: $endTime',
                          style: TextStyle(
                              fontSize: 14, color: Colors.grey.shade700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Action Buttons: Delete and Comments
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Delete Button
                      ElevatedButton.icon(
                        onPressed: widget.onDelete,
                        icon: const Icon(Icons.delete, color: Colors.white),
                        label: const Text('Delete'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Comments Button with Red Dot Indicator
                      ElevatedButton.icon(
                        onPressed: _navigateToComments,
                        icon: Stack(
                          children: [
                            const Icon(Icons.comment, color: Colors.white),
                            if (_hasUnseenComments)
                              const Positioned(
                                right: 0,
                                top: 0,
                                child: CircleAvatar(
                                  radius: 6,
                                  backgroundColor: Colors.red,
                                ),
                              ),
                          ],
                        ),
                        label: const Text('Comments'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
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
          );
        });
  }
}
