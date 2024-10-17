import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:getitdone/push_notifications/push_notification_service.dart';

class CreateGroupPage extends StatefulWidget {
  const CreateGroupPage({super.key});

  @override
  _CreateGroupPageState createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends State<CreateGroupPage> {
  final TextEditingController _groupNameController = TextEditingController();
  final List<String> _selectedFriends = [];
  final User currentUser = FirebaseAuth.instance.currentUser!;
  bool _isCreatingGroup = false; // Track the creation status

  @override
  void dispose() {
    _groupNameController.dispose();
    super.dispose();
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      _fetchFriends() async {
    var snapshot = await FirebaseFirestore.instance
        .collection('friends')
        .where('user1', isEqualTo: currentUser.uid)
        .get();
    return snapshot.docs;
  }

  Future<Map<String, dynamic>?> _getUserDetails(String userId) async {
    var userSnapshot =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();
    return userSnapshot.data();
  }

  Future<void> _createGroup() async {
    String groupName = _groupNameController.text.trim();
    if (groupName.isEmpty || _selectedFriends.isEmpty) {
      _showSnackBar('Enter a group name and select members', Colors.orange);
      return;
    }
    setState(() {
      _isCreatingGroup = true; // Show progress indicator
    });

    _selectedFriends.add(currentUser.uid);

    try {
      // Create the group in Firestore
      var groupDoc = await FirebaseFirestore.instance.collection('groups').add({
        'name': groupName,
        'members': _selectedFriends,
        'creator': currentUser.uid,
        'admins': [currentUser.uid],
      });

      // Notify all selected members
      await _notifyMembers(_selectedFriends, groupName);

      Navigator.pop(context);
    } catch (e) {
      _showSnackBar('Failed to create group. Please try again.', Colors.red);
    } finally {
      setState(() {
        _isCreatingGroup = false; // Hide progress indicator
      });
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
  }

  Future<void> _notifyMembers(List<String> members, String groupName) async {
    for (String memberId in members) {
      if (memberId != currentUser.uid) {
        // Skip notifying the creator
        await _sendNotification(
          memberId,
          '🎉 Added to a New Group!',
          'You have been added to the group: $groupName',
        );
      }
    }
  }

  Future<void> _sendNotification(
      String userId, String title, String body) async {
    try {
      QuerySnapshot tokensSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('tokens')
          .get();

      List<String> tokens =
          tokensSnapshot.docs.map((doc) => doc['token'] as String).toList();

      for (String token in tokens) {
        await PushNotificationService.sendNotificationToUser(
            token, title, body);
      }

      print('📲 Notification sent to user: $userId');
    } catch (e) {
      print('🚨 Error sending notification: $e');
    }
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.grey[100],
      contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: BorderSide.none,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Group'),
        backgroundColor: Colors.teal,
        elevation: 4,
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
          child: Column(
            children: [
              Center(
                child: Hero(
                  tag: 'group-icon',
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.teal.shade300,
                    child: const Icon(
                      Icons.group_add,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _groupNameController,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                ),
                decoration: _inputDecoration('Group Name'),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: FutureBuilder<
                    List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
                  future: _fetchFriends(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return const Center(
                        child: Text('Error loading friends.'),
                      );
                    }

                    final friends = snapshot.data ?? [];

                    if (friends.isEmpty) {
                      return const Center(
                        child: Text('No friends available to add.'),
                      );
                    }

                    return ListView.builder(
                      itemCount: friends.length,
                      itemBuilder: (context, index) {
                        var friend = friends[index].data();
                        String friendId = friend['user2'] ?? 'Unknown ID';

                        return FutureBuilder<Map<String, dynamic>?>(
                          future: _getUserDetails(friendId),
                          builder: (context, userSnapshot) {
                            if (userSnapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const ListTile(
                                title: Text('Loading...'),
                              );
                            }
                            if (!userSnapshot.hasData) {
                              return const ListTile(
                                title: Text('Error loading user.'),
                              );
                            }

                            final user = userSnapshot.data!;
                            String username = user['username'] ?? 'No Username';
                            String email = user['email'] ?? 'No Email';

                            return Card(
                              margin: const EdgeInsets.symmetric(
                                  vertical: 8, horizontal: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              elevation: 6,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.teal.shade300,
                                      Colors.teal.shade100
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 12, horizontal: 16),
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      double screenWidth =
                                          MediaQuery.of(context).size.width;
                                      double adaptiveTitleFontSize =
                                          screenWidth * 0.05; // 5% of width
                                      double adaptiveSubtitleFontSize =
                                          screenWidth * 0.04; // 4% of width

                                      return Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 30,
                                            backgroundColor:
                                                Colors.teal.shade600,
                                            child: Text(
                                              username.isNotEmpty
                                                  ? username[0].toUpperCase()
                                                  : '?',
                                              style: const TextStyle(
                                                fontSize: 24,
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  username,
                                                  style: TextStyle(
                                                    fontSize:
                                                        adaptiveTitleFontSize
                                                            .clamp(16, 24),
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.black87,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  email,
                                                  style: TextStyle(
                                                    fontSize:
                                                        adaptiveSubtitleFontSize
                                                            .clamp(12, 20),
                                                    color: Colors.grey.shade700,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Transform.scale(
                                            scale:
                                                1.5, // Make the checkbox larger
                                            child: Checkbox(
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              value: _selectedFriends
                                                  .contains(friendId),
                                              activeColor: Colors.teal
                                                  .shade900, // Darker tick color
                                              checkColor: Colors
                                                  .white, // White tick inside the checkbox
                                              onChanged: (bool? selected) {
                                                setState(() {
                                                  if (selected == true) {
                                                    _selectedFriends
                                                        .add(friendId);
                                                  } else {
                                                    _selectedFriends
                                                        .remove(friendId);
                                                  }
                                                });
                                              },
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _isCreatingGroup ? null : _createGroup,
                icon: const Icon(
                  Icons.group,
                  color: Colors.white,
                  size: 24, // Icon size
                ),
                label: const Text(
                  'Create Group',
                  style: TextStyle(
                    fontSize: 18, // Label text size
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isCreatingGroup
                      ? Colors.grey
                      : Colors.teal, // Change color based on state
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 24,
                  ), // Button padding
                  elevation: 6, // Elevated effect for better visibility
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
