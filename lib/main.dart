import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:flutter/material.dart';
import 'package:getitdone/about_page.dart';
import 'package:getitdone/pages/home_page.dart';
import 'package:getitdone/pages/login_page.dart';
import 'package:getitdone/pages/register_page.dart';
import 'package:getitdone/pages/sharedTodo/friends_page.dart';
import 'package:getitdone/push_notifications/save_device_token.dart';
import 'package:provider/provider.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'firebase_options.dart';

/// Global navigator key to allow navigation from outside the widget tree
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Background message handler must be a top-level function
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase to ensure it's available in the background
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  print('Handling a background message: ${message.messageId}');

  // Handle the background message (e.g., display a notification)
  // Note: On web, background messages are handled by the service worker
}

/// Entry point of the application
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize timezone data
  tz.initializeTimeZones();
  tz.setLocalLocation(
      tz.getLocation('America/New_York')); // Set to your timezone

  // Initialize Firebase Messaging
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  // Set the background messaging handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Initialize Notification Service

  // Request notification permissions (for mobile and web)
  await requestNotificationPermission(messaging);

  runApp(const TodoApp());
}

/// Request notification permissions for both mobile and web
Future<void> requestNotificationPermission(FirebaseMessaging messaging) async {
  try {
    // For web, the permission request is handled differently
    if (kIsWeb) {
      // Request permission for web
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('User granted notification permission (Web)');
      } else {
        print('User denied or has not accepted notification permission (Web)');
      }
    } else {
      // Request permission for mobile
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('User granted notification permission (Mobile)');
      } else {
        print(
            'User denied or has not accepted notification permission (Mobile)');
      }
    }
  } catch (e) {
    print('Error requesting notification permission: $e');
  }
}

/// The root widget of the application
class TodoApp extends StatelessWidget {
  const TodoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamProvider<User?>.value(
      value: FirebaseAuth.instance.authStateChanges(),
      initialData: null,
      child: MaterialApp(
        navigatorKey: navigatorKey, // Assign the global navigatorKey
        title: 'Futuristic To-Do App',
        theme: ThemeData(
          brightness: Brightness.dark,
          primarySwatch: Colors.teal,
          scaffoldBackgroundColor: Colors.black,
          appBarTheme: const AppBarTheme(color: Colors.teal),
          textTheme: const TextTheme(
            bodyLarge: TextStyle(color: Colors.white),
            bodyMedium: TextStyle(color: Colors.white70),
          ),
        ),
        home: const AuthenticationWrapper(),
        routes: {
          '/login': (context) => const LoginPage(),
          '/register': (context) => const RegisterPage(),
          '/dashboard': (context) => const DashboardPage(),
          '/about': (context) => const AboutPage(),

          '/friends': (context) =>
              const FriendsPage(), // Add the Friends page route
        },
      ),
    );
  }
}

/// Wrapper to handle authentication state and navigate accordingly
class AuthenticationWrapper extends StatefulWidget {
  const AuthenticationWrapper({super.key});

  @override
  _AuthenticationWrapperState createState() => _AuthenticationWrapperState();
}

class _AuthenticationWrapperState extends State<AuthenticationWrapper> {
  late StreamSubscription<User?> _authSubscription;

  @override
  void initState() {
    super.initState();

    // Listen to auth state changes
    _authSubscription =
        FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null) {
        // Save device token when user is logged in
        saveDeviceToken(user.uid);
      }
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<User?>(context);

    if (user != null) {
      return const DashboardPage(); // If logged in, show dashboard
    }
    return const LoginPage(); // Otherwise, show login page
  }
}
