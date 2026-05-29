import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Auth zerbitzua: erabiltzailearen autentikazio kudeaketa egiten du.
///
/// Zer egiten duen:
/// - Firebase Auth bidez login, register eta logout funtzioak eskaintzen ditu.
/// - Azken saioaren markatzea SharedPreferences-en gordetzen du.
///
/// Gako kontzeptuak: `FirebaseAuth`, `UserCredential`, `SharedPreferences`.
class AuthService {
  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  static const String _lastLoginAtKey = 'last_login_at';
  static const int _sessionDays = 30;

  final FirebaseAuth _auth;

  /// Stream bitartez aplikazioak jarraitu dezake autentikazio egoeraren aldaketak.
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  /// Oraineko erabiltzailea (edo `null`), `FirebaseAuth`-etik hartua.
  User? get currentUser => _auth.currentUser;

  Future<UserCredential> login({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    // Saio markatzea: erabiltzailearen azken login unea gordetzen dugu.
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
    // Erregistro arrakastatsuaren ondoren saioaren markatzea egiten da.
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
    // Aurreko saioaren timestamp berreskuratu eta gaurkoarekin konparatzen dugu.
    final lastLogin = DateTime.fromMillisecondsSinceEpoch(lastLoginMs);
    final now = DateTime.now();
    // True itzultzen dugu azken saioa 30 egun baino gutxiagokoa bada.
    return now.difference(lastLogin).inDays < _sessionDays;
  }

  Future<void> _markSessionLogin() async {
    final prefs = await SharedPreferences.getInstance();
    // Uneko denbora milisekundotan gorde, saioak iraungitze egiaztapenetarako.
    await prefs.setInt(_lastLoginAtKey, DateTime.now().millisecondsSinceEpoch);
  }
}
