import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:getitdone/pages/home_page.dart';
import 'package:getitdone/pages/login_page.dart';
import 'package:getitdone/service/auth_service.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();

  String email = '';
  String password = '';
  String username = '';
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
                        'Register',
                        style: TextStyle(
                          color: Colors.tealAccent,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 32.0),
                      _buildTextField(
                        label: 'Username',
                        obscureText: false,
                        onChanged: (val) =>
                            setState(() => username = val.trim()),
                      ),
                      const SizedBox(height: 24.0),
                      _buildTextField(
                        label: 'Email',
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
                        text: 'Register',
                        onPressed: _register,
                      ),
                      const SizedBox(height: 16.0),
                      Text(
                        error,
                        style:
                            const TextStyle(color: Colors.red, fontSize: 14.0),
                      ),
                      _buildFooterText(
                        context: context,
                        text: "Already have an account?",
                        actionText: 'Login here',
                        onPressed: () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LoginPage(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Future<void> _register() async {
    if (_formKey.currentState!.validate()) {
      setState(() => loading = true);
      try {
        User? user = await _authService.registerWithEmailAndPassword(
          email,
          password,
          username,
        );

        if (user != null) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const DashboardPage()),
          );
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
