import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'terms_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  static const id = "registerScreen";

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final FocusNode _emailFocusNode = FocusNode();

  bool _agreedToTerms = false;
  bool _isLoading = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _emailFocusNode.dispose();
    super.dispose();
  }

  Future<void> _registerUser() async {
    if (_formKey.currentState!.validate()) {
      if (!_agreedToTerms) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please agree to the terms to continue")),
        );
        return;
      }

      setState(() {
        _isLoading = true;
      });

      try {

        UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: "tempPassword",
        );

        final uid = userCredential.user?.uid;

        await _firestore.collection('users').doc(uid).set({
          'displayname': _nameController.text.trim().isEmpty ? 'New User' : _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'cellnumber': '',
          'avatar': '',
          'society': '',
          'dob': '',
          'profile_completed': false,
        });


        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("✅ Account created successfully!"),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      } on FirebaseAuthException catch (e) {
        setState(() => _isLoading = false);

        if (e.code == 'email-already-in-use') {
          final email = _emailController.text.trim();
          if (mounted) {
            _showEmailAlreadyExistsDialog(email);
          }
          return;
        }

        String message = "Something went wrong";
        if (e.code == 'invalid-email') {
          message = "Please enter a valid email address.";
        } else if (e.code == 'weak-password') {
          message = "The password provided is too weak.";
        } else if (e.message != null) {
          message = e.message!;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showEmailAlreadyExistsDialog(String email) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFB8B24).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.mark_email_read_outlined, color: Color(0xFFFB8B24), size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                "Account Exists",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3B0D11),
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "The email $email is already registered with Tingungu.",
              style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.4),
            ),
            const SizedBox(height: 8),
            const Text(
              "Would you like to sign in to access your existing account?",
              style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _emailFocusNode.requestFocus();
              if (_emailController.text.isNotEmpty) {
                _emailController.selection = TextSelection(
                  baseOffset: 0,
                  extentOffset: _emailController.text.length,
                );
              }
            },
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => LoginScreen(initialEmail: email),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B0D11),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text("Sign In Now"),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 30),
                  const Text(
                    "Create Your Account",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Join Tingungu and connect with your society.",
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 30),

                  /// ✅ FORM
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        /// Full Name
                        TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: "Full Name",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          validator: (value) =>
                          value!.isEmpty ? "Please enter your name" : null,
                        ),
                        const SizedBox(height: 20),

                        /// Email
                        TextFormField(
                          controller: _emailController,
                          focusNode: _emailFocusNode,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: "Email Address",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          validator: (value) =>
                          value!.contains("@") ? null : "Enter a valid email",
                        ),
                        const SizedBox(height: 20),

                        /// ✅ Terms & Conditions Checkbox
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Checkbox(
                              value: _agreedToTerms,
                              onChanged: (value) {
                                setState(() => _agreedToTerms = value!);
                              },
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const TermsScreen(),
                                    ),
                                  );
                                },
                                child: RichText(
                                  text: const TextSpan(
                                    text: "By creating an account, you agree to our ",
                                    style: TextStyle(fontSize: 12, color: Colors.black87),
                                    children: [
                                      TextSpan(
                                        text: "Terms of Service, Data Privacy Policy & POPIA.",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFFFB8B24),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  /// ✅ REGISTER BUTTON
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _registerUser,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text("Continue with Email", style: TextStyle(fontSize: 16)),
                    ),
                  ),

                  const SizedBox(height: 15),

                  /// ✅ ALREADY HAVE ACCOUNT?
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const LoginScreen()),
                      );
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("Already have an account? "),
                          Text(
                            "Login",
                            style: TextStyle(
                              color: Color(0xFFFB8B24),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  /// ✅ FOOTER
                  const Text(
                    "Developed by Jaspa\n© 2026",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),

            /// ✅ SPINKIT LOADER OVERLAY
            if (_isLoading)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SpinKitFadingCircle(
                        color: Colors.white,
                        size: 60.0,
                      ),
                      SizedBox(height: 20),
                      Text(
                        "Creating your account...",
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
