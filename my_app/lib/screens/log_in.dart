import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '/services/auth_service.dart';
import '/screens/sign_up.dart';
import '/screens/home.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthService _auth = AuthService();
  final _formKey = GlobalKey<FormState>();
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref("Users");

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// **Login with Email & Password**
  void _login() async {
    if (_formKey.currentState!.validate()) {
      try {
        User? user = await _auth.signIn(_emailController.text, _passwordController.text);
        if (user != null) {
          await _fetchUserData(user.uid);
          if (!mounted) return;
          _showSnackBar("✅ Login Successful: ${user.email}");
          _navigateToHome();
        }
      } catch (e) {
        if (!mounted) return;
        _showSnackBar("⚠️ Login Failed: $e");
      }
    }
  }

  /// **Login with Google & Fetch User Data**
  void _loginWithGoogle() async {
    try {
      User? user = await _auth.signInWithGoogle();
      if (user != null) {
        await _fetchUserData(user.uid);
        if (!mounted) return;
        _showSnackBar("✅ Google Login Successful: ${user.email}");
        _navigateToHome();
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar("⚠️ Google Login Failed: $e");
    }
  }

  /// **Fetch or Create User Data in Firebase**
  Future<void> _fetchUserData(String uid) async {
    DatabaseReference userRef = _dbRef.child(uid);
    DataSnapshot snapshot = await userRef.get();

    if (!snapshot.exists) {
      // **Create New User Entry if Not Found**
      await userRef.set({
        "email": FirebaseAuth.instance.currentUser!.email,
        "balance": 0.0, // Default balance
        "transactions": {}, // Empty transaction history
      });
    }
  }

  /// **Navigate to Home Screen**
  void _navigateToHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HomePage()),
    );
  }

  /// **Show Message**
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildEmailField(),
                const SizedBox(height: 20),
                _buildPasswordField(),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {}, // TODO: Implement Forgot Password Logic
                    child: const Text('Forgot Password?', style: TextStyle(color: Colors.grey)),
                  ),
                ),
                const SizedBox(height: 20),
                _buildSignInButtons(),
                const SizedBox(height: 30),
                _buildSocialLogin(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      decoration: InputDecoration(
        labelText: 'Email Address',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your email';
        } else if (!RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(value)) {
          return 'Enter a valid email';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: true,
      decoration: InputDecoration(
        labelText: 'Password',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your password';
        } else if (value.length < 6) {
          return 'Password must be at least 6 characters';
        }
        return null;
      },
    );
  }

  Widget _buildSignInButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton(
          onPressed: _login,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          child: const Text('Sign In'),
        ),
        const SizedBox(width: 20),
        OutlinedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SignUpScreen()),
            );
          },
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          child: const Text('Sign Up'),
        ),
      ],
    );
  }

  Widget _buildSocialLogin() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const FaIcon(FontAwesomeIcons.google, color: Colors.red),
          onPressed: _loginWithGoogle,
        ),
      ],
    );
  }
}
