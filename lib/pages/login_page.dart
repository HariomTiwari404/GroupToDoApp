import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:getitdone/pages/register_page.dart';
import 'package:getitdone/service/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();

  String email = '';
  String password = '';
  String error = '';
  bool loading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: loading
              ? const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.tealAccent),
                )
              : Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      const Text(
                        'Login',
                        style: TextStyle(
                          color: Colors.tealAccent,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 32.0),
                      _buildTextField(
                        label: 'Email or Username',
                        obscureText: false,
                        onChanged: (val) => setState(() => email = val.trim()),
                      ),
                      const SizedBox(height: 24.0),
                      _buildTextField(
                        label: 'Password',
                        obscureText: true,
                        onChanged: (val) =>
                            setState(() => password = val.trim()),
                      ),
                      const SizedBox(height: 32.0),
                      _buildFuturisticButton(
                        text: 'Login',
                        onPressed: _signIn,
                      ),
                      const SizedBox(height: 16.0),
                      _buildForgotPasswordText(),
                      if (error.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            error,
                            style: const TextStyle(
                                color: Colors.red, fontSize: 14.0),
                          ),
                        ),
                      const SizedBox(height: 16.0),
                      _buildFooterText(
                        context: context,
                        text: "Don't have an account?",
                        actionText: 'Register here',
                        onPressed: () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const RegisterPage()),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Future<void> _signIn() async {
    if (_formKey.currentState!.validate()) {
      setState(() => loading = true);
      try {
        User? user = await _authService.signInWithEmailOrUsernameAndPassword(
            email, password);

        if (user != null) {
          // Navigate to the dashboard and clear the back stack
          Navigator.pushNamedAndRemoveUntil(
              context, '/dashboard', (route) => false);
        }
      } catch (e) {
        setState(() {
          error = e.toString();
          loading = false;
        });
      }
    }
  }

  Widget _buildTextField({
    required String label,
    required bool obscureText,
    required Function(String) onChanged,
  }) {
    return TextFormField(
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.tealAccent),
        filled: true,
        fillColor: Colors.grey[800],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25),
          borderSide: const BorderSide(color: Colors.tealAccent),
        ),
      ),
      obscureText: obscureText,
      validator: (val) => val != null && val.isEmpty ? 'Enter $label' : null,
      onChanged: onChanged,
    );
  }

  Widget _buildFuturisticButton({
    required String text,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.tealAccent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
          elevation: 10,
        ),
        child: Text(
          text,
          style: const TextStyle(color: Colors.black, fontSize: 18),
        ),
      ),
    );
  }

  Widget _buildForgotPasswordText() {
    return TextButton(
      onPressed: _showForgotPasswordDialog,
      child: const Text(
        'Forgot Password?',
        style: TextStyle(color: Colors.tealAccent),
      ),
    );
  }

  void _showForgotPasswordDialog() {
    showDialog(
      context: context,
      builder: (context) {
        String resetEmail = '';
        return AlertDialog(
          title: const Text('Reset Password'),
          content: TextField(
            onChanged: (val) => resetEmail = val.trim(),
            decoration: const InputDecoration(
              hintText: 'Enter your registered email',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await _authService.resetPassword(resetEmail);
                  Navigator.pop(context);
                  _showSnackBar('Password reset link sent!', Colors.green);
                } catch (e) {
                  Navigator.pop(context);
                  _showSnackBar(e.toString(), Colors.red);
                }
              },
              child: const Text('Send Reset Link'),
            ),
          ],
        );
      },
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  Widget _buildFooterText({
    required BuildContext context,
    required String text,
    required String actionText,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(text, style: const TextStyle(color: Colors.white)),
          TextButton(
            onPressed: onPressed,
            child: Text(
              actionText,
              style: const TextStyle(color: Colors.tealAccent),
            ),
          ),
        ],
      ),
    );
  }
}
