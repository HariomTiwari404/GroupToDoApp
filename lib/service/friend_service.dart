import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:getitdone/push_notifications/push_notification_service.dart';

class FriendService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User user = FirebaseAuth.instance.currentUser!;

  /// Send a friend request only if not already friends and no request exists
  /// Send a friend request only if not already friends and no request exists
  Future<String> sendFriendRequest(String friendEmailOrUsername) async {
    try {
      // Find the friend by email or username
      var friendSnapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: friendEmailOrUsername)
          .get();

      if (friendSnapshot.docs.isEmpty) {
        friendSnapshot = await _firestore
            .collection('users')
            .where('username', isEqualTo: friendEmailOrUsername)
            .get();

        if (friendSnapshot.docs.isEmpty) {
          throw 'User not found.';
        }
      }

      String friendId = friendSnapshot.docs.first.id;

      // Check if they are already friends
      bool alreadyFriends = await areFriends(user.uid, friendId);
      if (alreadyFriends) {
        throw 'You are already friends with this user.';
      }

      // Check if there is a pending request from this user to the friend
      var sentRequest = await _firestore
          .collection('friend_requests')
          .where('from', isEqualTo: user.uid)
          .where('to', isEqualTo: friendId)
          .get();

      if (sentRequest.docs.isNotEmpty) {
        throw 'You have already sent a friend request to this user.';
      }

      // Check if there is a pending request from the friend to this user
      var receivedRequest = await _firestore
          .collection('friend_requests')
          .where('from', isEqualTo: friendId)
          .where('to', isEqualTo: user.uid)
          .get();

      if (receivedRequest.docs.isNotEmpty) {
        throw 'This user has already sent you a friend request. Accept it instead.';
      }

      // Create the friend request with 'pending' status
      await _firestore.collection('friend_requests').add({
        'from': user.uid,
        'to': friendId,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Send notification to the recipient
      await _sendNotification(
        friendId,
        '📩 New Friend Request!',
        'You have a new friend request from ${user.email}.',
      );

      // Return the friendId after successful request creation
      return friendId;
    } catch (e) {
      rethrow;
    }
  }

  /// Get friends and their details
  Stream<QuerySnapshot> getFriendsList() {
    return _firestore
        .collection('friends')
        .where('user1', isEqualTo: user.uid)
        .snapshots();
  }

  /// Accept a friend request and establish mutual friendship
  Future<void> acceptFriendRequest(String requestId, String fromUserId) async {
    try {
      // Create mutual friendships
      await _firestore.collection('friends').add({
        'user1': user.uid,
        'user2': fromUserId,
      });

      await _firestore.collection('friends').add({
        'user1': fromUserId,
        'user2': user.uid,
      });

      // Delete the friend request
      await _firestore.collection('friend_requests').doc(requestId).delete();

      // Send notification to the sender
      await _sendNotification(
        fromUserId,
        '✅ Friend Request Accepted!',
        'Your friend request was accepted by ${user.email}.',
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Reject a friend request
  Future<void> rejectFriendRequest(String requestId, String fromUserId) async {
    try {
      await _firestore.collection('friend_requests').doc(requestId).delete();

      // Send notification to the sender
      await _sendNotification(
        fromUserId,
        '❌ Friend Request Rejected',
        'Your friend request was rejected by ${user.email}.',
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Send push notification to a specific user
  Future<void> _sendNotification(
      String userId, String title, String body) async {
    try {
      QuerySnapshot tokensSnapshot = await _firestore
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

  /// Check if two users are friends (in either direction)
  Future<bool> areFriends(String userId1, String userId2) async {
    var friendsSnapshot = await _firestore
        .collection('friends')
        .where('user1', isEqualTo: userId1)
        .where('user2', isEqualTo: userId2)
        .get();

    if (friendsSnapshot.docs.isEmpty) {
      var reverseSnapshot = await _firestore
          .collection('friends')
          .where('user1', isEqualTo: userId2)
          .where('user2', isEqualTo: userId1)
          .get();
      return reverseSnapshot.docs.isNotEmpty;
    }
    return true;
  }

  /// Fetch user details by user ID
  Future<Map<String, dynamic>?> getUserDetails(String userId) async {
    var userSnapshot = await _firestore.collection('users').doc(userId).get();
    return userSnapshot.data();
  }

  /// Get friend requests the current user has received
  Stream<QuerySnapshot> getReceivedFriendRequests() {
    return _firestore
        .collection('friend_requests')
        .where('to', isEqualTo: user.uid)
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  /// Get friend requests the current user has sent
  Stream<QuerySnapshot> getSentFriendRequests() {
    return _firestore
        .collection('friend_requests')
        .where('from', isEqualTo: user.uid)
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  /// Search users by username
  Stream<QuerySnapshot> searchUsersByUsername(String username) {
    return _firestore
        .collection('users')
        .where('username', isGreaterThanOrEqualTo: username)
        .where('username', isLessThanOrEqualTo: '$username\uf8ff')
        .snapshots();
  }

  /// Delete a friend relationship from both users
  Future<void> deleteFriend(String friendId) async {
    // Delete the friendship entry from both directions
    var friendsSnapshot1 = await _firestore
        .collection('friends')
        .where('user1', isEqualTo: user.uid)
        .where('user2', isEqualTo: friendId)
        .get();

    if (friendsSnapshot1.docs.isNotEmpty) {
      await friendsSnapshot1.docs.first.reference.delete();
    }

    var friendsSnapshot2 = await _firestore
        .collection('friends')
        .where('user1', isEqualTo: friendId)
        .where('user2', isEqualTo: user.uid)
        .get();

    if (friendsSnapshot2.docs.isNotEmpty) {
      await friendsSnapshot2.docs.first.reference.delete();
    }
  }
}
