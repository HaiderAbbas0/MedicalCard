import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/auth_model.dart';
import '../services/auth_service.dart';

class AuthController extends ChangeNotifier {
  final AuthService _authService;

  UserModel? _currentUser;
  String? _token;
  bool _isLoading = false;
  String? _errorMessage;

  bool _bootstrapped = false;

  // Getters
  UserModel? get currentUser => _currentUser;
  String? get token => _token;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _token != null && _currentUser != null;
  bool get bootstrapped => _bootstrapped;
  bool get loggedIn => isAuthenticated;

  /// Current user's role (defaults to patient when unknown).
  UserRole get role => _currentUser?.role ?? UserRole.patient;

  AuthController({AuthService? authService}) 
      : _authService = authService ?? AuthService();

  /// Mock OTP check — only "123456" is accepted.
  bool verifyOtp(String code) => code == '123456';

  /// Complete login mock (used when transitioning from otp verification).
  Future<void> completeLogin() async {
    _setLoading(true);
    // Mark as authenticated by storing a dummy session if none exists
    if (!isAuthenticated) {
      _token = 'mock_otp_token';
      _currentUser = UserModel(
        id: 'mock_id',
        name: 'Ayesha Khan',
        email: 'ayesha@example.com',
      );
      await _saveToken(_token!);
      await _saveUser(_currentUser!);
    }
    _setLoading(false);
  }

  Future<void> signOut() => logout();

  /// Load session information when the app boots up.
  Future<void> loadSession() async {
    _isLoading = true;
    notifyListeners();

    try {
      final savedToken = await _readToken();
      final savedUser = await _readUser();

      if (savedToken != null && savedUser != null) {
        _token = savedToken;
        _currentUser = savedUser;
      }
    } catch (e) {
      _errorMessage = 'Failed to load session: $e';
    } finally {
      _bootstrapped = true;
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Perform login call and save authentication details.
  Future<bool> login(String email, String password) async {
    _setLoading(true);
    _clearError();

    try {
      final authResponse = await _authService.login(email, password);
      
      _token = authResponse.token;
      _currentUser = authResponse.user;

      // Save token and user details in storage
      await _saveToken(authResponse.token);
      await _saveUser(authResponse.user);

      _setLoading(false);
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      _setLoading(false);
      return false;
    } catch (e) {
      _setError('An unexpected error occurred: ${e.toString()}');
      _setLoading(false);
      return false;
    }
  }

  /// Perform sign up call and auto-login on success.
  Future<bool> signUp({
    required String name,
    required String email,
    required String password,
    String? cnic,
    String? phone,
    String? dob,
    String? gender,
    String? bloodGroup,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final authResponse = await _authService.register(
        name: name,
        email: email,
        password: password,
        cnic: cnic,
        phone: phone,
        dob: dob,
        gender: gender,
        bloodGroup: bloodGroup,
      );

      _token = authResponse.token;
      _currentUser = authResponse.user;

      // Save credentials in storage
      await _saveToken(authResponse.token);
      await _saveUser(authResponse.user);

      _setLoading(false);
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      _setLoading(false);
      return false;
    } catch (e) {
      _setError('An unexpected error occurred: ${e.toString()}');
      _setLoading(false);
      return false;
    }
  }

  /// Replace the cached current user (e.g. after a profile update) and persist it.
  Future<void> updateCurrentUser(UserModel user) async {
    _currentUser = user;
    await _saveUser(user);
    notifyListeners();
  }

  /// Log out the user and clear storage.
  Future<void> logout() async {
    _setLoading(true);
    
    try {
      await _deleteToken();
      await _deleteUser();
      
      _token = null;
      _currentUser = null;
      _clearError();
    } catch (e) {
      _setError('Failed to log out cleanly: $e');
    } finally {
      _setLoading(false);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  State Management Helpers
  // ═══════════════════════════════════════════════════════════════════════

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  Secure Storage Placeholders
  // ═══════════════════════════════════════════════════════════════════════
  // These functions use SharedPreferences as a storage backend. If you want
  // hardware-backed secure storage (iOS Keychain / Android Keystore), you can
  // easily replace these with the 'flutter_secure_storage' package.
  
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<String?> _readToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> _deleteToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  Future<void> _saveUser(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = user.toJson();
    await prefs.setString(_userKey, jsonEncode(userJson));
  }

  Future<UserModel?> _readUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userString = prefs.getString(_userKey);
    if (userString == null) return null;
    
    try {
      final userMap = jsonDecode(userString) as Map<String, dynamic>;
      return UserModel.fromJson(userMap);
    } catch (_) {
      return null;
    }
  }

  Future<void> _deleteUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
  }
}
