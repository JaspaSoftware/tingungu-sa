import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'config/app_config.dart';
import 'services/account_profile_provisioner.dart';
import 'widgets/auth_state_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const TingunguApp());
}

class TingunguApp extends StatelessWidget {
  const TingunguApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3b0d11),
          primary: const Color(0xFF3b0d11),
          secondary: const Color(0xFFFB8B24),
          brightness: Brightness.light,
        ),
        primaryColor: const Color(0xFF3b0d11),
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'Rubik',
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFB8B24),
            foregroundColor: Colors.white,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: const Color(0xFFFB8B24)),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFFB8B24),
            side: const BorderSide(color: Color(0xFFFB8B24)),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF3b0d11),
          foregroundColor: Colors.white,
        ),
      ),
      home: AppConfig.apiBaseUrl.trim().isEmpty
          ? const _BootstrapError(error: 'API_BASE_URL must be configured.')
          : const _AuthBootstrapGate(),
    );
  }
}

class _AuthBootstrapGate extends StatefulWidget {
  const _AuthBootstrapGate();

  @override
  State<_AuthBootstrapGate> createState() => _AuthBootstrapGateState();
}

class _AuthBootstrapGateState extends State<_AuthBootstrapGate> {
  late final Future<bool> _firstLaunch = _loadFirstLaunch();
  bool? _firstLaunchOverride;

  Future<bool> _loadFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isFirstLaunch') ?? true;
  }

  void _onboardingCompleted() {
    setState(() => _firstLaunchOverride = false);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _firstLaunch,
      builder: (context, preferenceSnapshot) {
        if (preferenceSnapshot.hasError) {
          return _BootstrapError(error: preferenceSnapshot.error!);
        }
        if (!preferenceSnapshot.hasData) {
          return const _BootstrapLoading();
        }

        final isFirstLaunch =
            _firstLaunchOverride ?? preferenceSnapshot.data!;
        return AuthStateGate(
          authStateChanges: FirebaseAuth.instance.authStateChanges(),
          currentUser: FirebaseAuth.instance.currentUser,
          signedOut: isFirstLaunch
              ? OnboardingScreen(onCompleted: _onboardingCompleted)
              : const LoginScreen(),
          authenticated: const HomeScreen(),
          provisionProfile: (user) =>
              AccountProfileProvisioner.instance.ensureProfile(
                uid: user.uid,
                email: user.email,
                displayName: user.displayName,
                photoUrl: user.photoURL,
              ),
          errorBuilder: (error) => _BootstrapError(error: error),
        );
      },
    );
  }
}

class _BootstrapError extends StatelessWidget {
  const _BootstrapError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text('Unable to start Tingungu: $error'),
      ),
    ),
  );
}

class _BootstrapLoading extends StatelessWidget {
  const _BootstrapLoading();

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(child: CircularProgressIndicator()),
  );
}
