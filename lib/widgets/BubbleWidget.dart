import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class BubbleWidget extends StatelessWidget {
  final String senderName;
  final String message;
  final Timestamp? timestamp;
  final bool isCurrentUser;
  final Color userColor;
  final VoidCallback onDelete;
  final VoidCallback onLongPress;
  final Map<String, dynamic>? replyTo;
  final bool deleteInProgress; // New parameter for delete progress

  const BubbleWidget({
    super.key,
    required this.senderName,
    required this.message,
    this.timestamp,
    required this.isCurrentUser,
    required this.userColor,
    required this.onDelete,
    required this.onLongPress,
    this.replyTo,
    this.deleteInProgress = false, // Default value set to false
  });

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'N/A';
    return DateFormat('hh:mm a').format(timestamp.toDate());
  }

  // Helper function to generate a color from a string
  Color _getColorFromString(String str) {
    int hash = str.hashCode;
    int r = (hash & 0xFF0000) >> 16;
    int g = (hash & 0x00FF00) >> 8;
    int b = hash & 0x0000FF;

    // Ensure the color is dark
    r = (r * 0.7).toInt();
    g = (g * 0.7).toInt();
    b = (b * 0.7).toInt();

    return Color.fromRGBO(r, g, b, 1);
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: IntrinsicWidth(
          // Wrap the entire content with IntrinsicWidth
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: isCurrentUser
                    ? [Colors.tealAccent.shade400, Colors.teal.shade700]
                    : [
                        _getColorFromString(senderName).withOpacity(0.6),
                        _getColorFromString(senderName)
                      ],
                center: Alignment.topRight,
                radius: 2.0,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(5),
                bottomRight: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  blurRadius: 5,
                  offset: const Offset(2, 3),
                ),
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(4, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (replyTo != null) _buildReplyPreview(),
                _buildMessageContent(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          senderName,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          message,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _formatTimestamp(timestamp),
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black54,
              ),
            ),
            if (isCurrentUser)
              IconButton(
                icon: const Icon(Icons.delete, size: 20, color: Colors.black54),
                onPressed: onDelete,
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildReplyPreview() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reply to: ${replyTo!['senderName'] ?? 'Unknown'}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            replyTo!['message'] ?? '',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
    );
  }
}
