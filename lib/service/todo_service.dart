import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:getitdone/push_notifications/push_notification_service.dart';

class TodoService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User user;
  Timer? _reminderTimer;
  Timer? _noTimeTaskReminderTimer;

  // Constructor to initialize Firestore and start reminders
  TodoService(this.user) {
    _firestore.settings = const Settings(persistenceEnabled: true);
    _startReminderCheck(); // Start periodic reminders
    _startNoTimeTaskReminder(); // Start no-time task reminders
  }

  // Add a new to-do with optional start and end times
  Future<void> addTodo(String todoText, bool isOnline,
      {DateTime? startTime, DateTime? endTime}) async {
    if (todoText.isEmpty) {
      throw Exception('✨ Oops! Enter something for your task ✨');
    }

    if ((startTime != null && endTime == null) ||
        (startTime == null && endTime != null)) {
      throw Exception('⏰ Please provide both start and end times, bestie!');
    }

    if (startTime != null && endTime != null && endTime.isBefore(startTime)) {
      throw Exception('🛑 End time can’t come before the start time. Chill 😎');
    }

    try {
      Map<String, dynamic> todoData = {
        'text': todoText,
        'uid': user.uid,
        'completed': false,
        'createdAt': Timestamp.now(),
        'isSynced': isOnline,
        'notifiedExpired': false, // Track expired notification status
      };

      if (startTime != null)
        todoData['startTime'] = Timestamp.fromDate(startTime);
      if (endTime != null) todoData['endTime'] = Timestamp.fromDate(endTime);

      await _firestore.collection('todos').add(todoData);
      await _sendNewTaskNotification(todoText);
      print('📋 Task added and notification sent! ✔️');
    } catch (e) {
      throw Exception('❌ Couldn’t add task: $e');
    }
  }

  // Send a notification about the new task
  Future<void> _sendNewTaskNotification(String taskName) async {
    try {
      QuerySnapshot tokensSnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('tokens')
          .get();

      List<String> tokens =
          tokensSnapshot.docs.map((doc) => doc['token'] as String).toList();

      if (tokens.isEmpty) {
        print('⚠️ No device tokens found for user.');
        return;
      }

      for (String token in tokens) {
        await PushNotificationService.sendNotificationToUser(
          token,
          '🔥 New Task Alert!',
          '👀 Don’t forget: "$taskName" has been added to your list!',
        );
      }

      print('📲 Notifications sent successfully!');
    } catch (e) {
      print('🚨 Error sending notifications: $e');
    }
  }

  // Start periodic reminders to check tasks with start and end times
  void _startReminderCheck() {
    _reminderTimer = Timer.periodic(const Duration(minutes: 1), (timer) async {
      await _checkForReminders();
    });
  }

  // Start periodic reminders for tasks without any time set
  void _startNoTimeTaskReminder() {
    _noTimeTaskReminderTimer =
        Timer.periodic(const Duration(hours: 2), (timer) async {
      await _sendNoTimeTaskReminders();
    });
  }

  // Check for tasks that need reminders (start, end, or expired notifications)
  Future<void> _checkForReminders() async {
    final now = DateTime.now();
    final fiveMinutesFromNow = now.add(const Duration(minutes: 5));

    try {
      QuerySnapshot tasksSnapshot = await _firestore
          .collection('todos')
          .where('uid', isEqualTo: user.uid)
          .where('completed', isEqualTo: false)
          .get();

      for (var doc in tasksSnapshot.docs) {
        var task = doc.data() as Map<String, dynamic>;
        String taskName = task['text'];
        Timestamp? startTime = task['startTime'];
        Timestamp? endTime = task['endTime'];
        bool notifiedExpired = task['notifiedExpired'] ?? false;

        if (startTime == null && endTime == null) continue;

        if (startTime != null &&
            startTime.toDate().isAfter(now) &&
            startTime.toDate().isBefore(fiveMinutesFromNow)) {
          await _sendTaskStartNotification(taskName);
        }

        if (endTime != null &&
            endTime.toDate().isAfter(now) &&
            endTime.toDate().isBefore(fiveMinutesFromNow)) {
          await _sendTaskEndNotification(taskName);
        }

        if (endTime != null && endTime.toDate().isBefore(now)) {
          if (!notifiedExpired || _shouldResendExpiredNotification(endTime)) {
            await _sendTaskExpiredNotification(taskName, doc.id);
          }
        }
      }
    } catch (e) {
      print('⚠️ Error checking for reminders: $e');
    }
  }

  bool _shouldResendExpiredNotification(Timestamp endTime) {
    final twoHoursAgo = DateTime.now().subtract(const Duration(hours: 2));
    return endTime.toDate().isBefore(twoHoursAgo);
  }

  Future<void> _sendTaskExpiredNotification(
      String taskName, String docId) async {
    try {
      String deviceToken = await _getUserDeviceToken();
      await PushNotificationService.sendNotificationToUser(
        deviceToken,
        '❌ Task Expired!',
        '😢 Oops! You missed completing "$taskName" in time.',
      );

      await _firestore.collection('todos').doc(docId).update({
        'notifiedExpired': true,
      });

      print('⏰ Expired task notification sent for task: $taskName');
    } catch (e) {
      print('⚠️ Error sending expired task notification: $e');
    }
  }

  Future<void> _sendNoTimeTaskReminders() async {
    try {
      QuerySnapshot tasksSnapshot = await _firestore
          .collection('todos')
          .where('uid', isEqualTo: user.uid)
          .where('completed', isEqualTo: false)
          .where('startTime', isNull: true)
          .where('endTime', isNull: true)
          .get();

      for (var doc in tasksSnapshot.docs) {
        var task = doc.data() as Map<String, dynamic>;
        String taskName = task['text'];

        String deviceToken = await _getUserDeviceToken();
        await PushNotificationService.sendNotificationToUser(
          deviceToken,
          '🧐 What’s the Plan?',
          '🤔 When are you planning to do "$taskName"?',
        );
        print('⏰ No-time task reminder sent for task: $taskName');
      }
    } catch (e) {
      print('⚠️ Error sending no-time task reminders: $e');
    }
  }

  Future<void> _sendTaskStartNotification(String taskName) async {
    try {
      String deviceToken = await _getUserDeviceToken();
      await PushNotificationService.sendNotificationToUser(
        deviceToken,
        '⏳ Your Task is Starting Soon!',
        '💪 Let’s get going! "$taskName" starts soon!',
      );
      print('⏰ Start time notification sent for task: $taskName');
    } catch (e) {
      print('⚠️ Error sending start time notification: $e');
    }
  }

  Future<void> _sendTaskEndNotification(String taskName) async {
    try {
      String deviceToken = await _getUserDeviceToken();
      await PushNotificationService.sendNotificationToUser(
        deviceToken,
        '⏳ Time’s Ticking!',
        '⚡ Hurry up! "$taskName" is about to end!',
      );
      print('⏰ End time notification sent for task: $taskName');
    } catch (e) {
      print('⚠️ Error sending end time notification: $e');
    }
  }

  Future<String> _getUserDeviceToken() async {
    var snapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('tokens')
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      return snapshot.docs.first['token'];
    } else {
      throw Exception('❌ No device token found.');
    }
  }

  void stopReminderCheck() {
    _reminderTimer?.cancel();
    _noTimeTaskReminderTimer?.cancel();
    print('⏹️ Reminder checks stopped.');
  }

  Future<void> toggleTodoCompletion(String docId, bool currentStatus) async {
    try {
      await _firestore.collection('todos').doc(docId).update({
        'completed': !currentStatus,
      });

      if (!currentStatus) {
        var todoSnapshot =
            await _firestore.collection('todos').doc(docId).get();
        var todoData = todoSnapshot.data();

        if (todoData != null && todoData['text'] != null) {
          String todoText = todoData['text'];
          await PushNotificationService.sendNotificationToUser(
            await _getUserDeviceToken(),
            '✅ Task Completed!',
            '🎉 Great job! You completed "$todoText".',
          );
        }
      }
    } catch (e) {
      throw Exception('❌ Failed to update task status: $e');
    }
  }

  Future<void> deleteTodo(String docId) async {
    try {
      await _firestore.collection('todos').doc(docId).delete();
      print('🗑️ Task deleted.');
    } catch (e) {
      throw Exception('❌ Failed to delete task: $e');
    }
  }

  Stream<QuerySnapshot> getUserTodos() {
    return _firestore
        .collection('todos')
        .where('uid', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<DocumentSnapshot> getTodoById(String docId) async {
    return await _firestore.collection('todos').doc(docId).get();
  }

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
    print('👋 Signed out successfully.');
  }
}
