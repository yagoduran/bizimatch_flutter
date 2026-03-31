import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  static const String _lastLoginAtKey = 'last_login_at';
  static const int _sessionDays = 30;

  final FirebaseAuth _auth;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> login({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    await _markSessionLogin();
    return credential;
  }

  Future<UserCredential> register({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await _markSessionLogin();
    return credential;
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  Future<bool> hasSessionWithin30Days() async {
    final prefs = await SharedPreferences.getInstance();
    final lastLoginMs = prefs.getInt(_lastLoginAtKey);
    if (lastLoginMs == null) {
      return false;
    }

    final lastLogin = DateTime.fromMillisecondsSinceEpoch(lastLoginMs);
    final now = DateTime.now();
    return now.difference(lastLogin).inDays < _sessionDays;
  }

  Future<void> _markSessionLogin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastLoginAtKey, DateTime.now().millisecondsSinceEpoch);
  }
}
