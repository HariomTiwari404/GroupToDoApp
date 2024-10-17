import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Register with email & password and save user details to Firestore
  Future<User?> registerWithEmailAndPassword(
      String email, String password, String username) async {
    try {
      // Check if the username already exists
      bool usernameExists = await _checkIfUsernameExists(username);
      if (usernameExists) {
        throw 'Username already taken. Please choose a different one.';
      }

      UserCredential result = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
      User? user = result.user;

      if (user != null) {
        // Save user information to Firestore
        await _firestore.collection('users').doc(user.uid).set({
          'email': email,
          'username': username,
          'uid': user.uid,
        });
      }
      return user;
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      throw Exception('Failed to register: $e');
    }
  }

  // Send a password reset email
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw e.message ?? 'An error occurred while resetting the password.';
    }
  }

  // Check if the username already exists in Firestore
  Future<bool> _checkIfUsernameExists(String username) async {
    var snapshot = await _firestore
        .collection('users')
        .where('username', isEqualTo: username)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  // Sign in with email or username & password
  Future<User?> signInWithEmailOrUsernameAndPassword(
      String input, String password) async {
    try {
      String email = input;

      // If the input is not an email, treat it as a username
      if (!input.contains('@')) {
        var snapshot = await _firestore
            .collection('users')
            .where('username', isEqualTo: input)
            .get();
        if (snapshot.docs.isEmpty) {
          throw 'Username not found.';
        }
        email = snapshot.docs.first['email'];
      }

      UserCredential result = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      return result.user;
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      throw Exception('Failed to login: $e');
    }
  }

  // Sign out
  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
    print('User signed out successfully.');
  }
}
