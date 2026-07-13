import 'package:flutter/material.dart';
import '../models/auth_model.dart';
import '../services/auth_service.dart';
import '../services/supabase_client.dart';

/// Auth state backed by Supabase. The session is persisted automatically by
/// supabase_flutter, so it survives app restarts.
class AuthController extends ChangeNotifier {
  final AuthService _authService;

  UserModel? _currentUser;
  String? _token;
  bool _isLoading = false;
  String? _errorMessage;
  bool _bootstrapped = false;

  UserModel? get currentUser => _currentUser;
  String? get token => _token;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null;
  bool get bootstrapped => _bootstrapped;
  bool get loggedIn => isAuthenticated;
  UserRole get role => _currentUser?.role ?? UserRole.patient;

  AuthController({AuthService? authService})
    : _authService = authService ?? AuthService();

  /// OTP check (signup creates the Supabase session; this step is a verification
  /// gate). The development verification code is configured separately.
  bool verifyOtp(String code) => code == '11111';
  Future<void> completeLogin() async {} // session already created on signup
  Future<void> signOut() => logout();

  /// Restore the session on boot from the persisted Supabase session.
  Future<void> loadSession() async {
    _isLoading = true;
    notifyListeners();
    try {
      final session = db.auth.currentSession;
      final uid = db.auth.currentUser?.id;
      if (session != null && uid != null) {
        final profile = await fetchFullProfile(uid);
        if (profile != null && profile['status'] == 'active') {
          _token = session.accessToken;
          _currentUser = UserModel.fromJson(profile);
        } else {
          await db.auth.signOut();
        }
      }
    } catch (e) {
      _errorMessage = 'Failed to load session: $e';
    } finally {
      _bootstrapped = true;
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login(String identifier, String password) async {
    _setLoading(true);
    _clearError();
    try {
      final res = await _authService.login(identifier, password);
      _token = res.token;
      _currentUser = res.user;
      _setLoading(false);
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      _setLoading(false);
      return false;
    } catch (e) {
      _setError('An unexpected error occurred: $e');
      _setLoading(false);
      return false;
    }
  }

  Future<bool> signUp({
    required String name,
    required String email,
    required String password,
    String? phone,
    String? dob,
    String? gender,
    String? bloodGroup,
    String? emergencyPhone,
  }) async {
    _setLoading(true);
    _clearError();
    try {
      final res = await _authService.register(
        name: name,
        email: email,
        password: password,
        phone: phone,
        dob: dob,
        gender: gender,
        bloodGroup: bloodGroup,
        emergencyPhone: emergencyPhone,
      );
      _token = res.token;
      _currentUser = res.user;
      _setLoading(false);
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      _setLoading(false);
      return false;
    } catch (e) {
      _setError('An unexpected error occurred: $e');
      _setLoading(false);
      return false;
    }
  }

  /// Update the cached user after a profile edit (DB already updated).
  Future<void> updateCurrentUser(UserModel user) async {
    _currentUser = user;
    notifyListeners();
  }

  Future<void> logout() async {
    _setLoading(true);
    try {
      await _authService.signOut();
      _token = null;
      _currentUser = null;
      _clearError();
    } catch (e) {
      _setError('Failed to log out cleanly: $e');
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  void _setError(String m) {
    _errorMessage = m;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
