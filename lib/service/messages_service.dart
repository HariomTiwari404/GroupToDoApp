import 'package:cloud_firestore/cloud_firestore.dart';

class MessagesService {
  final String taskId;

  MessagesService(this.taskId);

  Future<void> sendMessage(
      String message, String senderId, String senderName) async {
    final messageData = {
      'message': message,
      'senderId': senderId,
      'senderName': senderName,
      'timestamp': FieldValue.serverTimestamp(),
    };

    await FirebaseFirestore.instance
        .collection('group_todos') // Use group_todos collection
        .doc(taskId)
        .collection('comments')
        .add(messageData);
  }

  Future<void> editMessage(String messageId, String newMessage) async {
    await FirebaseFirestore.instance
        .collection('group_todos') // Use 'group_todos'
        .doc(taskId)
        .collection('comments')
        .doc(messageId)
        .update({'message': newMessage});
  }

  Future<void> deleteMessage(String messageId) async {
    await FirebaseFirestore.instance
        .collection('group_todos') // Use 'group_todos'
        .doc(taskId)
        .collection('comments')
        .doc(messageId)
        .delete();
  }
}
