import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

Future<void> saveDeviceToken(String uid) async {
  try {
    String? token = await FirebaseMessaging.instance.getToken();

    if (token != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('tokens')
          .doc(token)
          .set({
        'token': token,
        'createdAt': FieldValue.serverTimestamp(),
      });
      print('Device token saved successfully!');
    } else {
      print('Unable to get device token.');
    }
  } catch (e) {
    print('Error saving device token: $e');
  }
}
