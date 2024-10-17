import 'dart:convert';

import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:http/http.dart' as http;

class PushNotificationService {
  // Firebase Cloud Messaging endpoint for sending notifications.
  static const String _fcmEndpoint =
      'https://fcm.googleapis.com/v1/projects/getitdone-f0686/messages:send';

  // Get the access token using the service account credentials.
  static Future<String?> getAccessToken() async {
    final serviceAccountJson = {
      "type": "service_account",
      "project_id": "getitdone-f0686",
      "private_key_id": "65bb28d0b32c8539469cf555672f9126938b913f",
      "private_key": "-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQCjrfWTUrr5GiuV\n"
          "TF2yNeaSKqybYYRzyMjQ3KtXwVtN72BObMtmx64KMhqEfMxedjDYMMw3RwdUf+AW\n"
          "CTHv6fUJJf324JKpIju0Eu5LdiP4ySN1mB/7aJcWE9Fhb32LFPF7zFuFyQvoY4Iq\n"
          "KJFu5w5gktn1sCrpEgcGTC38FmB68h3O0BD9kRIgsLz2GPgZ0sHNSq4g3i5zL9NF\n"
          "X7JrWOBotZpTqoEgVoFy0xkWWWqfOq+1vovv9Z4zCa8jVFeCsTXBVW22utFNU27c\n"
          "2hR2Nf1KJKJ8As8a9jVLLeTl+hDa6ugfse4MKggeu/kuwUOQpRv7DRWI3f+PKf/X\n"
          "gEQKmAylAgMBAAECggEAIPpQb3+caMqPS+wgN6L5Auuirca61Uo3va8sPYjZYM0x\n"
          "QfPVEm76X5cDNTzgv0qAYlqIlr2SmkGOcFona89fPZngPqC2I+ogDdK/nMgfjMVX\n"
          "xd5h2TlUMZBKIB/Cs2ZDlj4RFZYxdj+wTtawIKBgivAjhocZSi7F6Ayqui72/uYd\n"
          "Ka0X6BoSQWlZqB/lS2LziTU7jECti+Xhn6BkrIoDWzTusD62E+1vHyyspYcDIYQ+\n"
          "nOrkNs6Hv6CceoyZgkLTZCBuzyybRc09NDzGBXIFrEYaefDt6lp2GuoNFTOco4Qn\n"
          "wKpaMrQPtoOTLkqKRkIM32i+sfdhdfWMSSC5ZpKReQKBgQDXDjfzXIJQIDFwHw8S\n"
          "zWUyb+z9Q/Kse9GY4C5zrNnaXfKUwgW0nwEB8701MxNJHrWVe8a6BuwU2dpTpKVG\n"
          "uF/Pg534DGa8pf5n9InrPhG6eyZCqTUqlGLpSLd2ePjoCnmBSn8TgaCCkz9h66VQ\n"
          "03DCF9DIbxDPKNsJuvvMhl0oPQKBgQDC164TVxWVxirWGbx1PK4uQ2BchZzex0/t\n"
          "5Cq611t2uBUMXGIBvvjaXA+MjU+H5IshJ4aBiiOxvVW5Pa9hJ67Axxdxy6Dhl9Ob\n"
          "8O+tj3GP8Q6srOgyaLiAsXjq+icjX52MD4eDQHdgW5ksm7EvCKysaYMwtVBJBTDB\n"
          "ZJEY7sfUiQKBgHeXi5vFHR6r2HJOg1ZkbFtRDMyG5cPvk05dlNd1Dy01Q3pgL0YT\n"
          "ij7oqZaVEat+7WH0lD3NLaomwBf1noembnl66vUPCG7uLHzo622rdbZrV4qIiG1m\n"
          "WV77tjKm8VwwvwMcR3C0jGswsXWl0qgQ/UqibdOYmBNr1+sgVXiWW+XNAoGAbd1j\n"
          "4K/oEe4N1W/pnkm7BYckXMdSbyP/4+oWVgh9IHIoHDIzaTyf4bCra9t6juvFr8oz\n"
          "w/N6sQxLvAoWTDguB7G7fIUPkGUmAvZWj40kwb9xQNi2jUYTUy2/OvAXBZEyqvlO\n"
          "timxpnm/4zFfNWA0zXspaFu0i5gLp+DnGCH8N9ECgYEA1kVWavtrhONzTjXrAUoR\n"
          "2QzUnjQMwfVjLVGbt4t+ciVCYikh2rvY2flN2twzFC0HnakxgmYJM/vgalZtZKpX\n"
          "ksJ0q435ZmFcUWl9l6eWV2IVXz71oEUVyyAKGveHpQPIz5gFieiGgGOyYMa1KryQ\n"
          "yJlkQfOmsBq4f8erAX1ZMv8=\n-----END PRIVATE KEY-----\n",
      "client_email":
          "get-it-done-hariom@getitdone-f0686.iam.gserviceaccount.com",
      "client_id": "116584776162975984380",
    };

    List<String> scopes = [
      "https://www.googleapis.com/auth/firebase.messaging",
    ];

    try {
      var client = await auth.clientViaServiceAccount(
          auth.ServiceAccountCredentials.fromJson(serviceAccountJson), scopes);

      var credentials = await auth.obtainAccessCredentialsViaServiceAccount(
          auth.ServiceAccountCredentials.fromJson(serviceAccountJson),
          scopes,
          client);
      client.close();
      return credentials.accessToken.data;
    } catch (e) {
      print("Error getting access token: $e");
      return null;
    }
  }

// Send a notification with a custom title and body to a specific device token.
  static Future<void> sendNotificationToUser(
      String deviceToken, String title, String body) async {
    final String? accessToken = await getAccessToken();
    if (accessToken == null) return;

    final message = {
      'message': {
        'token': deviceToken,
        'notification': {
          'title': title,
          'body': body,
        },
      }
    };

    try {
      final response = await http.post(
        Uri.parse(_fcmEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(message),
      );

      if (response.statusCode == 200) {
        print('Notification sent successfully!');
      } else {
        print('Failed to send notification: ${response.body}');
      }
    } catch (e) {
      print('Error sending notification: $e');
    }
  }
}
