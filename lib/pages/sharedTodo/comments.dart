import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:getitdone/push_notifications/push_notification_service.dart';
import 'package:getitdone/service/messages_service.dart';
import 'package:getitdone/widgets/BubbleWidget.dart';

class CommentsPage extends StatefulWidget {
  final String taskId;

  const CommentsPage({super.key, required this.taskId});

  @override
  _CommentsPageState createState() => _CommentsPageState();
}

class _CommentsPageState extends State<CommentsPage> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late MessagesService _messagesService;
  final Map<String, bool> _deletingMessages = {}; // Track deletion state
  final Map<String, Color> _userColors = {};
  bool _isSending = false; // Track send state
  bool _isEditing = false; // Track edit state

  String taskName = 'Loading...'; // Track task name

  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _messagesService = MessagesService(widget.taskId);
    _fetchTaskName(); // Fetch task name on init
    _updateLastViewed();

    // No longer mark messages as seen here
  }

  // Update the last viewed timestamp in the user's document
  Future<void> _updateLastViewed() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final userRef =
        FirebaseFirestore.instance.collection('users').doc(currentUser.uid);

    await userRef.update({
      'lastViewedComments.${widget.taskId}': FieldValue.serverTimestamp(),
    });

    print('✅ Updated lastViewedComments for task ${widget.taskId}');
  }

  // Fetch task name for display
  Future<void> _fetchTaskName() async {
    try {
      final taskDoc = await FirebaseFirestore.instance
          .collection('group_todos')
          .doc(widget.taskId)
          .get();

      if (taskDoc.exists) {
        setState(() {
          taskName = taskDoc['task'] ?? 'Unnamed Task';
        });
      }
    } catch (e) {
      print('Error fetching task name: $e');
    }
  }

  Color _getUserColor(String userId) {
    if (!_userColors.containsKey(userId)) {
      _userColors[userId] = Color.fromARGB(
        255,
        _random.nextInt(256),
        _random.nextInt(256),
        _random.nextInt(256),
      );
    }
    return _userColors[userId]!;
  }

  Future<String?> _getUsername() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .get();
      return userDoc.data()?['username'] ?? 'Anonymous';
    } catch (e) {
      return 'Anonymous';
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    setState(() {
      _isSending = true;
    });

    try {
      String? username = await _getUsername();
      String messageText = _messageController.text.trim();

      // Send message to Firestore
      await _messagesService.sendMessage(
        messageText,
        _auth.currentUser!.uid,
        username!,
      );

      _messageController.clear();

      // Notify group members about the new message
      await _notifyGroupMembers(messageText, username);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending message: $e')),
      );
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  Future<void> _notifyGroupMembers(String message, String senderName) async {
    try {
      // Fetch the task from 'group_todos' collection
      final taskDoc = await FirebaseFirestore.instance
          .collection('group_todos')
          .doc(widget.taskId)
          .get();

      if (!taskDoc.exists || taskDoc.data() == null) {
        print('🚨 Task not found for ID: ${widget.taskId}');
        return;
      }

      // Retrieve task name and groupId from the task document
      final String taskName = taskDoc['task'] ?? 'Unnamed Task';
      final String groupId = taskDoc['groupId'];

      // Fetch the group document
      final groupDoc = await FirebaseFirestore.instance
          .collection('groups')
          .doc(groupId)
          .get();

      if (!groupDoc.exists) {
        print('🚨 Group not found for ID: $groupId');
        return;
      }

      List<dynamic> members = groupDoc['members'];

      for (String memberId in members) {
        if (memberId == _auth.currentUser!.uid) continue; // Skip sender

        // Fetch the member's tokens
        QuerySnapshot tokensSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(memberId)
            .collection('tokens')
            .get();

        List<String> tokens =
            tokensSnapshot.docs.map((doc) => doc['token'] as String).toList();

        // Send notifications to all tokens
        for (String token in tokens) {
          await PushNotificationService.sendNotificationToUser(
            token,
            '💬 New Comment on "$taskName"!',
            '$senderName commented: "$message"',
          );
        }
      }

      print('📲 Notifications sent successfully!');
    } catch (e) {
      print('🚨 Error notifying group members: $e');
    }
  }

  Future<void> _sendNotificationToMember(String memberId, String memberUsername,
      String senderName, String message) async {
    try {
      // Fetch the member's tokens from Firestore
      QuerySnapshot tokensSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(memberId)
          .collection('tokens')
          .get();

      List<String> tokens =
          tokensSnapshot.docs.map((doc) => doc['token'] as String).toList();

      // Send a notification to each token
      for (String token in tokens) {
        await PushNotificationService.sendNotificationToUser(
          token,
          'New Comment from $senderName!',
          '$senderName: $message',
        );
      }

      print('📲 Notification sent to $memberUsername');
    } catch (e) {
      print('🚨 Error sending notification to $memberUsername: $e');
    }
  }

  Future<void> _deleteMessage(String messageId) async {
    setState(() {
      _deletingMessages[messageId] = true; // Start showing progress
    });

    try {
      await _messagesService.deleteMessage(messageId);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting message: $e')),
      );
    } finally {
      setState(() {
        _deletingMessages.remove(messageId); // Stop showing progress
      });
    }
  }

  void _showEditMessageDialog(String messageId, String currentMessage) {
    final TextEditingController editController =
        TextEditingController(text: currentMessage);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Message'),
        content: TextField(
          controller: editController,
          decoration: const InputDecoration(
            hintText: 'Update your message...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _isEditing
                ? null // Disable button if already editing
                : () async {
                    final updatedMessage = editController.text.trim();
                    if (updatedMessage.isNotEmpty) {
                      setState(() {
                        _isEditing = true; // Start showing progress
                      });

                      try {
                        await FirebaseFirestore.instance
                            .collection('group_todos') // Corrected collection
                            .doc(widget.taskId)
                            .collection('comments') // Corrected subcollection
                            .doc(messageId)
                            .update({'message': updatedMessage});
                        Navigator.of(context).pop(); // Close the dialog
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error updating message: $e')),
                        );
                      } finally {
                        setState(() {
                          _isEditing = false; // Stop showing progress
                        });
                      }
                    }
                  },
            child: _isEditing
                ? const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  )
                : const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comments'),
        backgroundColor: Colors.teal,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.teal.shade700, Colors.teal.shade300],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('group_todos') // Use correct collection
                    .doc(widget.taskId)
                    .collection('comments')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  final messages = snapshot.data?.docs ?? [];
                  if (messages.isEmpty) {
                    return const Center(
                      child: Text(
                        'No comments yet. Be the first to comment!',
                        style: TextStyle(color: Colors.white70),
                      ),
                    );
                  }

                  return ListView.builder(
                    reverse: true,
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message =
                          messages[index].data() as Map<String, dynamic>;
                      final messageId = messages[index].id;
                      final isCurrentUser =
                          message['senderId'] == _auth.currentUser?.uid;

                      return BubbleWidget(
                        senderName: message['senderName'] ?? 'Anonymous',
                        message: message['message'] ?? '',
                        timestamp: message['timestamp'],
                        isCurrentUser: isCurrentUser,
                        userColor: _getUserColor(message['senderId']),
                        onDelete: () => _deleteMessage(messageId),
                        onLongPress: isCurrentUser
                            ? () => _showEditMessageDialog(
                                messageId, message['message'] ?? '')
                            : () {},
                        deleteInProgress: _deletingMessages[messageId] ?? false,
                      );
                    },
                  );
                },
              ),
            ),
            _buildMessageInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              style: const TextStyle(color: Colors.black),
              decoration: InputDecoration(
                hintText: 'Enter your comment...',
                hintStyle: const TextStyle(color: Colors.black54),
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 25,
            backgroundColor: Colors.teal,
            child: _isSending
                ? const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  )
                : IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _sendMessage,
                  ),
          ),
        ],
      ),
    );
  }
}
