// lib/pages/sharedTodo/groups_page.dart

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:getitdone/pages/sharedTodo/create_group_page.dart';
import 'package:getitdone/pages/sharedTodo/friends_page.dart';
import 'package:getitdone/pages/sharedTodo/group_management_page.dart';
import 'package:getitdone/pages/sharedTodo/group_todos_page.dart';
import 'package:getitdone/service/friend_service.dart';

class GroupsPage extends StatefulWidget {
  const GroupsPage({super.key});

  @override
  State<GroupsPage> createState() => _GroupsPageState();
}

class _GroupsPageState extends State<GroupsPage> {
  bool _hasPendingFriendRequests = false;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late final String _currentUserId;
  final FriendService _friendService =
      FriendService(); // Instantiate FriendService

  @override
  void initState() {
    super.initState();
    _currentUserId = _auth.currentUser!.uid;
    _listenForPendingFriendRequests();
  }

  /// Listens for any pending friend requests directed to the current user.
  void _listenForPendingFriendRequests() {
    FirebaseFirestore.instance
        .collection('friend_requests')
        .where('to', isEqualTo: _currentUserId)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _hasPendingFriendRequests = snapshot.docs.isNotEmpty;
        });
      }
    });
  }

  /// Fetches the list of friend user documents for the current user.
  Future<List<Map<String, dynamic>>> _getFriendUsers() async {
    List<Map<String, dynamic>> friendsList = [];

    // Listen to the friends stream
    await for (var friendsSnapshot in _friendService.getFriendsList()) {
      // For each friendship, get the friendId (user2)
      List<String> friendIds =
          friendsSnapshot.docs.map((doc) => doc['user2'] as String).toList();

      if (friendIds.isEmpty) return friendsList;

      // Fetch user details for each friendId
      for (String friendId in friendIds) {
        var userDetails = await _friendService.getUserDetails(friendId);
        if (userDetails != null) {
          friendsList.add(userDetails);
        }
      }

      break; // Exit after the first snapshot to prevent infinite loop
    }

    return friendsList;
  }

  /// Checks if a specific group has any unseen comments.
  /// Returns `true` if at least one comment in any task within the group is unseen.
  Future<bool> _hasGroupUnseenComments(String groupId) async {
    try {
      // Fetch all tasks in the group
      QuerySnapshot tasksSnapshot = await FirebaseFirestore.instance
          .collection('group_todos')
          .where('groupId', isEqualTo: groupId)
          .get();

      if (tasksSnapshot.docs.isEmpty) return false;

      // Fetch user document to get lastViewedComments
      DocumentSnapshot userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .get();

      if (!userSnapshot.exists) return false;

      Map<String, dynamic>? lastViewedMap =
          userSnapshot.get('lastViewedComments') as Map<String, dynamic>?;

      // Iterate through each task to check for unseen comments
      for (var task in tasksSnapshot.docs) {
        String taskId = task.id;
        Timestamp? lastViewedTimestamp;
        if (lastViewedMap != null && lastViewedMap.containsKey(taskId)) {
          lastViewedTimestamp = lastViewedMap[taskId] as Timestamp;
        }

        // Fetch the latest comment in the task
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

        // If there's no record of last viewed or the latest comment is newer
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

  /// Navigates to the GroupTodosPage and refreshes the state upon return.
  void _navigateToGroupTodos(String groupId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GroupTodosPage(groupId: groupId),
      ),
    ).then((_) {
      // Refresh the state when returning from GroupTodosPage
      setState(() {});
    });
  }

  /// Adds a member to the specified group.
  Future<void> _addMemberToGroup(String groupId, String userId) async {
    try {
      await FirebaseFirestore.instance
          .collection('groups')
          .doc(groupId)
          .update({
        'members': FieldValue.arrayUnion([userId]),
      });
      print('✅ Added user $userId to group $groupId');
    } catch (e) {
      print('🚨 Error adding member: $e');
    }
  }

  /// Displays a dialog to add members to the group.
  void _showAddMembersDialog(
      BuildContext context, String groupId, List<dynamic> currentMembers) {
    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'Add Members',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _getFriendUsers(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (snapshot.hasError) {
                    return const Center(
                      child: Text(
                        'Error loading friends.',
                        style: TextStyle(color: Colors.red, fontSize: 18),
                      ),
                    );
                  }

                  List<Map<String, dynamic>> friendUsers = snapshot.data ?? [];

                  if (friendUsers.isEmpty) {
                    return const Center(
                      child: Text(
                        'You have no friends to add.',
                        style: TextStyle(color: Colors.grey, fontSize: 18),
                      ),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: friendUsers.length,
                    itemBuilder: (context, index) {
                      var user = friendUsers[index];
                      String userId = user[
                          'uid']; // Ensure 'uid' is stored in user document
                      String username = user['username'];
                      String email = user['email'];

                      bool isMember = currentMembers.contains(userId);

                      return Card(
                        elevation: 4,
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.teal.withOpacity(1),
                                Colors.teal.shade100,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.teal.shade300,
                              child: const Icon(
                                Icons.person,
                                color: Colors.white,
                              ),
                            ),
                            title: Text(
                              username,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Colors.black87,
                              ),
                            ),
                            subtitle: Text(
                              email,
                              style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 14,
                              ),
                            ),
                            trailing: isMember
                                ? const Icon(
                                    Icons.check,
                                    color: Colors.green,
                                  )
                                : IconButton(
                                    icon: const Icon(
                                      Icons.add,
                                      color: Colors.teal,
                                    ),
                                    onPressed: () async {
                                      await _addMemberToGroup(groupId, userId);
                                      Navigator.pop(
                                          context); // Close the dialog after adding
                                    },
                                  ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          );
        });
  }

  /// Handles the logic for a user leaving a group.
  void _leaveGroup(BuildContext context, String groupId, String userId) async {
    // Show confirmation dialog
    bool? confirm = await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Leave Group'),
          content: const Text(
              'Are you sure you want to leave this group? You will no longer have access to its tasks.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false); // Cancel and close dialog
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context, true); // Confirm and proceed
              },
              child: const Text('Leave', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    // If the user confirmed, proceed to leave the group
    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('groups')
            .doc(groupId)
            .update({
          'members': FieldValue.arrayRemove([userId]),
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You have left the group.'),
            backgroundColor: Colors.red,
          ),
        );
        print('✅ User $userId left group $groupId');
      } catch (e) {
        print('🚨 Error leaving group: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error leaving the group.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Builder(
          builder: (context) {
            // Get the screen width using MediaQuery
            double adaptiveFontSize = MediaQuery.of(context).size.width *
                0.06; // 6% of the screen width

            return Text(
              'Groups',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: adaptiveFontSize.clamp(
                    1, 30), // Clamping font size between 20 and 30
              ),
            );
          },
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
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            icon: const Icon(Icons.group_add, color: Colors.white, size: 28),
            label:
                const Text('Add Group', style: TextStyle(color: Colors.white)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CreateGroupPage(),
                ),
              ).then((_) {
                setState(() {});
              });
            },
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal.shade700,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            icon: Stack(
              children: [
                const Icon(Icons.people, color: Colors.white, size: 28),
                if (_hasPendingFriendRequests)
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
            label: const Text('Friends', style: TextStyle(color: Colors.white)),
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
            colors: [Colors.teal.shade800, Colors.teal.shade400],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('groups')
                .where('members', arrayContains: _currentUserId)
                .snapshots(),
            builder: (context, groupSnapshot) {
              if (groupSnapshot.hasError) {
                return const Center(
                  child: Text(
                    'Error loading groups.',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                );
              }
              if (groupSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                );
              }

              final groups = groupSnapshot.data?.docs ?? [];

              if (groups.isEmpty) {
                return const Center(
                  child: Text(
                    'No groups available.',
                    style: TextStyle(color: Colors.white70, fontSize: 18),
                  ),
                );
              }

              return ListView.builder(
                itemCount: groups.length,
                itemBuilder: (context, index) {
                  var group = groups[index];
                  String groupId = group.id;

                  return FutureBuilder<bool>(
                    future: _hasGroupUnseenComments(groupId),
                    builder: (context, snapshot) {
                      bool hasUnseenComments = snapshot.data ?? false;
                      return GestureDetector(
                        onTap: () {
                          _navigateToGroupTodos(groupId);
                        },
                        child: Stack(
                          children: [
                            Card(
                              elevation: 8,
                              margin: const EdgeInsets.symmetric(
                                  vertical: 10, horizontal: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.teal.shade300,
                                      Colors.teal.shade100,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 30,
                                      backgroundColor: Colors.teal.shade600,
                                      child: const Icon(
                                        Icons.group,
                                        color: Colors.white,
                                        size: 28,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          LayoutBuilder(
                                            builder: (context, constraints) {
                                              // Calculate font size based on screen width or available space
                                              double adaptiveFontSize =
                                                  constraints.maxWidth *
                                                      0.06; // 6% of width

                                              return Text(
                                                group['name'],
                                                style: TextStyle(
                                                  fontSize: adaptiveFontSize.clamp(
                                                      12,
                                                      50), // Adaptive size, within limits
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black87,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              );
                                            },
                                          ),
                                          const SizedBox(height: 8),
                                          LayoutBuilder(
                                            builder: (context, constraints) {
                                              double adaptiveSubtitleSize =
                                                  constraints.maxWidth *
                                                      0.04; // 4% of width

                                              return Text(
                                                'Tap to view group tasks',
                                                style: TextStyle(
                                                  fontSize: adaptiveSubtitleSize
                                                      .clamp(5,
                                                          18), // Adaptive size, within limits
                                                  color: Colors.grey.shade700,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.person_add,
                                        color: Colors.teal,
                                      ),
                                      onPressed: () {
                                        _showAddMembersDialog(
                                          context,
                                          groupId,
                                          group['members'],
                                        );
                                      },
                                    ),
                                    // Manage Group Button
                                    IconButton(
                                      icon: const Icon(Icons.settings,
                                          color: Colors.teal),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                GroupManagementPage(
                                                    groupId: groupId),
                                          ),
                                        ).then((_) {
                                          // Refresh the state when returning from GroupManagementPage
                                          setState(() {});
                                        });
                                      },
                                      tooltip: 'Manage Group',
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.exit_to_app,
                                        color: Colors.red,
                                      ),
                                      onPressed: () {
                                        _leaveGroup(
                                            context, groupId, _currentUserId);
                                      },
                                      tooltip: 'Leave Group',
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Red Dot if group has unseen comments
                            if (hasUnseenComments)
                              Positioned(
                                top: 12,
                                right: 12,
                                child: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
