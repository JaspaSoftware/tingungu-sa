import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/account_profile_provisioner.dart';
import '../utils/auth_error_messages.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  final String? initialEmail;
  final Future<bool> Function(String email, String password)? emailSignIn;
  final Future<RegistrationAccount?> Function()? googleSignIn;
  final Future<void> Function(String email)? passwordReset;
  final AccountProfileProvisioner? profileProvisioner;

  const LoginScreen({
    super.key,
    this.initialEmail,
    this.emailSignIn,
    this.googleSignIn,
    this.passwordReset,
    this.profileProvisioner,
  });
  static const String id = "loginScreen";

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;

  FirebaseAuth get _auth => FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail ?? '');
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loginUser() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final email = _emailController.text.trim();
        final password = _passwordController.text;
        final signedIn = widget.emailSignIn != null
            ? await widget.emailSignIn!(email, password)
            : (await _auth.signInWithEmailAndPassword(
                    email: email,
                    password: password,
                  )).user !=
                  null;

        if (!mounted) return;
        setState(() => _isLoading = false);
        if (signedIn) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("✅ Login successful!"),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } on FirebaseAuthException catch (e) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        final message = loginErrorMessage(e);
        if (message != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message), backgroundColor: Colors.red),
          );
        }
      } catch (e) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        final message = loginErrorMessage(e);
        if (message != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      if (widget.googleSignIn != null) {
        final account = await widget.googleSignIn!();
        if (!mounted) return;
        if (account != null) {
          await _ensureProfile(account);
          if (!mounted) return;
        }
        setState(() => _isLoading = false);
        return;
      }

      await _completeGoogleSignIn();
      if (mounted) setState(() => _isLoading = false);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      final message = loginErrorMessage(error);
      if (message != null) {
        if (kDebugMode) {
          final category = error is FirebaseAuthException
              ? error.code
              : error is PlatformException
              ? error.code
              : error.runtimeType;
          debugPrint('Google sign-in failed ($category).');
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _completeGoogleSignIn() async {
    final GoogleSignIn googleSignIn = GoogleSignIn(
      serverClientId:
          '226294099341-d6n78vt0atgifcgmignq528bvfhq9t0u.apps.googleusercontent.com',
    );

    // Force sign-out first to ensure account picker dialog pops up and clear stale tokens
    try {
      await googleSignIn.signOut();
    } catch (_) {}

    final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
    if (googleUser == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

    if (googleAuth.idToken == null) {
      throw Exception(
        "Google ID Token is missing. Please ensure your SHA-1 fingerprint is registered in Firebase Console.",
      );
    }

    final OAuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final UserCredential userCredential = await _auth.signInWithCredential(
      credential,
    );
    final User? user = userCredential.user;

    if (user != null) {
      // Save user_id to SharedPreferences for app services
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_id', user.uid);

      await _ensureProfile(
        RegistrationAccount(
          uid: user.uid,
          email: user.email,
          displayName: user.displayName,
          photoUrl: user.photoURL,
        ),
      );
    }
  }

  Future<void> _ensureProfile(RegistrationAccount account) {
    return (widget.profileProvisioner ?? AccountProfileProvisioner.instance)
        .ensureProfile(
          uid: account.uid,
          email: account.email,
          displayName: account.displayName,
          photoUrl: account.photoUrl,
        );
  }

  Future<void> _forgotPassword() async {
    final TextEditingController resetEmailController = TextEditingController(
      text: _emailController.text,
    );
    final screenContext = context;
    showDialog(
      context: screenContext,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          "Reset Password",
          style: TextStyle(color: Color(0xFF3B0D11)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Enter your email address and we'll send you a password reset link.",
            ),
            const SizedBox(height: 15),
            TextField(
              controller: resetEmailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: "Email Address",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B0D11),
            ),
            onPressed: () async {
              final email = resetEmailController.text.trim();
              if (email.isEmpty || !email.contains("@")) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text("Please enter a valid email address"),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              Navigator.pop(dialogContext);
              try {
                final sendReset = widget.passwordReset;
                if (sendReset != null) {
                  await sendReset(email);
                } else {
                  await _auth.sendPasswordResetEmail(email: email);
                }
                if (screenContext.mounted) {
                  final messenger = ScaffoldMessenger.of(screenContext);
                  messenger.clearSnackBars();
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text(
                        "Password reset email sent! Check your inbox.",
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (screenContext.mounted) {
                  final messenger = ScaffoldMessenger.of(screenContext);
                  messenger.clearSnackBars();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(passwordResetErrorMessage(e)),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text("Send Reset Link"),
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

                  // App Logo / Title
                  Image.asset(
                    'lib/assets/images/logo.png',
                    height: 90,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.church,
                      size: 80,
                      color: Color(0xFF3B0D11),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Welcome Back",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3B0D11),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Sign in to access your Tingungu account",
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 30),

                  // Form
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // Email Field
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: "Email Address",
                            prefixIcon: const Icon(
                              Icons.email_outlined,
                              color: Color(0xFFFB8B24),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return "Please enter your email";
                            }
                            if (!value.contains("@")) {
                              return "Please enter a valid email address";
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        // Password Field
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: "Password",
                            prefixIcon: const Icon(
                              Icons.lock_outline,
                              color: Color(0xFFFB8B24),
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: Colors.grey,
                              ),
                              onPressed: () {
                                setState(
                                  () => _obscurePassword = !_obscurePassword,
                                );
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return "Please enter your password";
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 10),

                        // Forgot Password
                        Align(
                          alignment: Alignment.centerRight,
                          child: GestureDetector(
                            onTap: _forgotPassword,
                            child: const Text(
                              "Forgot Password?",
                              style: TextStyle(
                                color: Color(0xFFFB8B24),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Login Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _loginUser,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B0D11),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        "Sign In",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                  const Text("OR", style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 20),

                  // Google Sign In Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : _signInWithGoogle,
                      icon: const Icon(
                        Icons.g_mobiledata,
                        size: 28,
                        color: Color(0xFFFB8B24),
                      ),
                      label: const Text(
                        "Continue with Google",
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFFFB8B24),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: Color(0xFFFB8B24)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Don't have an account? Register
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const RegisterScreen(),
                        ),
                      );
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: 8.0,
                        horizontal: 16.0,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("Don't have an account? "),
                          Text(
                            "Register",
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

                  // Footer
                  const Text(
                    "Developed by Jaspa\n© 2026 Tingungu",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),

            // Loading Overlay
            if (_isLoading)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SpinKitFadingCircle(color: Colors.white, size: 60.0),
                      SizedBox(height: 20),
                      Text(
                        "Signing in...",
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
