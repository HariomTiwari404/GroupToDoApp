import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:getitdone/push_notifications/push_notification_service.dart';
import 'package:getitdone/service/friend_service.dart';

class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});

  @override
  _FriendsPageState createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  final FriendService _friendService = FriendService();
  final TextEditingController _friendEmailController = TextEditingController();
  int _currentTabIndex = 0;
  bool _isLoading = false; // Loading state
  String? _processingRequestId; // State to track processing request
  bool _hasPendingRequests = false; // Track pending requests

  @override
  void initState() {
    super.initState();
    _listenForPendingFriendRequests();
  }

  // Real-time listener to track pending friend requests
  void _listenForPendingFriendRequests() {
    FirebaseFirestore.instance
        .collection('friend_requests')
        .where('to', isEqualTo: FirebaseAuth.instance.currentUser!.uid)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _hasPendingRequests = snapshot.docs.isNotEmpty;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Friends'),
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
              _buildSendFriendRequestSection(context),
              const SizedBox(height: 16),
              _buildTabBar(),
              const SizedBox(height: 16),
              Expanded(child: _buildCurrentTabContent()),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _removeFriendship(String userId1, String userId2) async {
    try {
      // Query for both possible friendship documents (user1-user2 or user2-user1).
      var querySnapshot = await FirebaseFirestore.instance
          .collection('friends')
          .where('user1', whereIn: [userId1, userId2]).where('user2',
              whereIn: [userId1, userId2]).get();

      for (var doc in querySnapshot.docs) {
        await doc.reference.delete(); // Delete the friendship document.
      }
    } catch (e) {
      _showSnackBar(context, 'Error: $e', Colors.red);
    }
  }

  Widget _buildSendFriendRequestSection(BuildContext context) {
    return Card(
      color: Colors.teal.shade50, // Explicitly set a light teal background

      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _friendEmailController,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                ),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.person, color: Colors.teal),
                  labelText: 'Friend\'s Email or Username',
                  labelStyle: const TextStyle(
                    color: Colors.teal,
                    fontWeight: FontWeight.bold,
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
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
                  hintText: 'Enter username or email',
                  hintStyle: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            _isLoading
                ? const CircularProgressIndicator() // Show the indicator when loading
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onPressed: () async {
                      String input = _friendEmailController.text.trim();
                      if (input.isEmpty) {
                        _showSnackBar(context,
                            'Please enter a username or email.', Colors.orange);
                        return;
                      }

                      setState(() => _isLoading = true); // Start loading

                      try {
                        String recipientId =
                            await _friendService.sendFriendRequest(input);

                        await _notifyUser(
                          recipientId,
                          '📩 New Friend Request!',
                          'You have a new friend request from ${FirebaseAuth.instance.currentUser?.email}.',
                        );

                        _showSnackBar(
                            context, 'Friend request sent!', Colors.green);
                        _friendEmailController.clear();
                      } catch (e) {
                        _showSnackBar(context, 'Error: $e', Colors.red);
                      } finally {
                        setState(() => _isLoading = false); // Stop loading
                      }
                    },
                    child: const Icon(Icons.send),
                  ),
          ],
        ),
      ),
    );
  }

  Future<String> sendFriendRequest(String input) async {
    QuerySnapshot userSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: input)
        .get();

    if (userSnapshot.docs.isEmpty) {
      throw Exception('User not found.');
    }

    String recipientId = userSnapshot.docs.first.id;

    // Create the friend request
    await FirebaseFirestore.instance.collection('friend_requests').add({
      'from': FirebaseAuth.instance.currentUser!.uid,
      'to': recipientId,
      'timestamp': FieldValue.serverTimestamp(),
    });

    return recipientId; // Return the recipient ID
  }

// TabBar with red dot indicator logic on the "Received Requests" tab
  Widget _buildTabBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildTabButton('Friends', 0),
        _buildTabButton('Sent Requests', 1),
        _buildTabButton(
            _hasPendingRequests ? 'Received (1)' : 'Received Requests', 2),
      ],
    );
  }

  // Tab button builder
  Widget _buildTabButton(String title, int index) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _currentTabIndex = index;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: _currentTabIndex == index
                ? LinearGradient(
                    colors: [Colors.teal, Colors.teal.shade300],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : const LinearGradient(
                    colors: [Colors.white, Colors.grey],
                  ),
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                color: _currentTabIndex == index ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentTabContent() {
    switch (_currentTabIndex) {
      case 0:
        return _buildFriendsList();
      case 1:
        return _buildSentRequestsList();
      case 2:
        return _buildPendingRequestsList();
      default:
        return const SizedBox();
    }
  }

  Widget _buildFriendsList() {
    String currentUserId = FirebaseAuth.instance.currentUser!.uid;

    return StreamBuilder(
      stream: FirebaseFirestore.instance
          .collection('friends')
          .where('user1', isEqualTo: currentUserId)
          .snapshots(),
      builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Error loading friends.'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final friends = snapshot.data?.docs ?? [];

        if (friends.isEmpty) {
          return const Center(
            child: Text(
              'You have no friends.',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          );
        }

        return ListView.builder(
          itemCount: friends.length,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          itemBuilder: (context, index) {
            var friend = friends[index];
            String friendId = friend['user2'];

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(friendId)
                  .get(),
              builder: (context, AsyncSnapshot<DocumentSnapshot> userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const ListTile(
                    title: Text('Loading...'),
                    trailing: CircularProgressIndicator(),
                  );
                }

                if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                  return const ListTile(
                    title: Text('User not found'),
                  );
                }

                final userData =
                    userSnapshot.data!.data() as Map<String, dynamic>?;
                final username = userData?['username'] ?? 'Unknown';
                final email = userData?['email'] ?? 'No Email Provided';

                return Card(
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  margin:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.teal.withOpacity(1),
                          Colors.teal.shade200,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.teal.shade300,
                          child: const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                username,
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                email,
                                style: const TextStyle(
                                  color: Color.fromARGB(255, 10, 0, 0),
                                  fontSize: 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            await _removeFriendship(currentUserId, friendId);
                            _showSnackBar(
                              context,
                              'Friend removed.',
                              Colors.red,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSentRequestsList() {
    return StreamBuilder(
      stream: _friendService.getSentFriendRequests(),
      builder: (context, AsyncSnapshot snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Error loading sent requests.'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final requests = snapshot.data.docs;
        if (requests.isEmpty) {
          return const Center(
            child: Text(
              'No sent friend requests.',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          );
        }

        return ListView.builder(
          itemCount: requests.length,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          itemBuilder: (context, index) {
            var request = requests[index];
            String toUserId = request['to'];

            return FutureBuilder(
              future: _friendService.getUserDetails(toUserId),
              builder: (context, AsyncSnapshot userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const ListTile(
                    title: Text('Loading...'),
                    trailing: CircularProgressIndicator(),
                  );
                }

                final user = userSnapshot.data;
                final username = user?['username'] ?? 'Unknown';
                final email = user?['email'] ?? 'Unknown';

                return Card(
                  elevation: 6,
                  margin:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.teal.withOpacity(1),
                          Colors.teal.shade200,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.teal.shade300,
                          child: const Icon(
                            Icons.person_add,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Request sent to: $username',
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                email,
                                style: const TextStyle(
                                  color: Color.fromARGB(255, 0, 0, 0),
                                  fontSize: 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildPendingRequestsList() {
    return StreamBuilder(
      stream: _friendService.getReceivedFriendRequests(),
      builder: (context, AsyncSnapshot snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Error loading requests.'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final requests = snapshot.data.docs;
        if (requests.isEmpty) {
          return const Center(
            child: Text(
              'No pending requests.',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          );
        }

        return ListView.builder(
          itemCount: requests.length,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          itemBuilder: (context, index) {
            var request = requests[index];
            String requestId = request.id;
            String fromUserId = request['from'];

            return FutureBuilder(
              future: _friendService.getUserDetails(fromUserId),
              builder: (context, AsyncSnapshot userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const ListTile(
                    title: Text('Loading...'),
                    trailing: CircularProgressIndicator(),
                  );
                }

                final user = userSnapshot.data;
                final username = user?['username'] ?? 'Unknown';
                final email = user?['email'] ?? 'Unknown';

                return Card(
                  elevation: 6,
                  margin:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.teal.withOpacity(1),
                          Colors.teal.shade200,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.teal.shade300,
                          child: const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Request from: $username',
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                email,
                                style: const TextStyle(
                                  color: Color.fromARGB(255, 0, 0, 0),
                                  fontSize: 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildActionButtons(context, requestId, fromUserId),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _showSnackBar(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  Widget _buildActionButtons(
      BuildContext context, String requestId, String fromUserId) {
    final isProcessing = _processingRequestId == requestId;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        isProcessing
            ? const CircularProgressIndicator() // Show loading indicator
            : IconButton(
                icon: const Icon(Icons.check, color: Colors.green),
                onPressed: () async {
                  await _handleRequest(
                    requestId,
                    fromUserId,
                    isAccept: true,
                  );
                },
              ),
        const SizedBox(width: 8),
        isProcessing
            ? const SizedBox() // Placeholder to maintain alignment
            : IconButton(
                icon: const Icon(Icons.close, color: Colors.red),
                onPressed: () async {
                  await _handleRequest(
                    requestId,
                    fromUserId,
                    isAccept: false,
                  );
                },
              ),
      ],
    );
  }

  Future<void> _handleRequest(String requestId, String fromUserId,
      {required bool isAccept}) async {
    setState(() => _processingRequestId = requestId); // Start processing

    try {
      if (isAccept) {
        await _friendService.acceptFriendRequest(requestId, fromUserId);
        await _notifyUser(
          fromUserId,
          '✅ Friend Request Accepted!',
          'Your friend request was accepted!',
        );
        _showSnackBar(context, 'Friend request accepted!', Colors.green);
      } else {
        await _friendService.rejectFriendRequest(requestId, fromUserId);
        await _notifyUser(
          fromUserId,
          '❌ Friend Request Rejected',
          'Your friend request was rejected.',
        );
        _showSnackBar(context, 'Request rejected.', Colors.red);
      }
    } catch (e) {
      _showSnackBar(context, 'Error: $e', Colors.red);
    } finally {
      setState(() => _processingRequestId = null); // Stop processing
    }
  }

  Future<void> _notifyUser(String userId, String title, String body) async {
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
}
