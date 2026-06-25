import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mock authentication state, persisted via SharedPreferences.
class AuthProvider extends ChangeNotifier {
  static const _loggedInKey = 'isLoggedIn';

  bool _loggedIn = false;
  bool _bootstrapped = false;

  bool get loggedIn => _loggedIn;
  bool get bootstrapped => _bootstrapped;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _loggedIn = prefs.getBool(_loggedInKey) ?? false;
    _bootstrapped = true;
    notifyListeners();
  }

  /// Marks the user as logged in (called after sign-in / OTP success).
  Future<void> completeLogin() async {
    _loggedIn = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_loggedInKey, true);
  }

  Future<void> signOut() async {
    _loggedIn = false;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_loggedInKey, false);
  }

  /// Mock OTP check — only "123456" is accepted.
  bool verifyOtp(String code) => code == '123456';
}
