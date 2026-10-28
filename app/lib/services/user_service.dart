import 'package:firebase_auth/firebase_auth.dart';

class UserService {
  static Future<void> signOutUser() {
    return FirebaseAuth.instance.signOut();
  }
}
