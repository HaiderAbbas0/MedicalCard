import 'package:supabase_flutter/supabase_flutter.dart' hide AuthResponse;

import '../models/auth_model.dart';
import 'supabase_client.dart';

/// API exception hierarchy (kept for the rest of the app that imports these).
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});
  @override
  String toString() => message;
}

class BadRequestException extends ApiException {
  BadRequestException(super.message, {super.statusCode = 400});
}

class UnauthorizedException extends ApiException {
  UnauthorizedException(super.message, {super.statusCode = 401});
}

class ServerException extends ApiException {
  ServerException(super.message, {super.statusCode = 500});
}

class NetworkException extends ApiException {
  NetworkException(super.message);
}

/// Authentication backed by Supabase Auth. Login uses Hayaat ID, email, or phone.
class AuthService {
  /// Sign in with a 16-digit Hayaat ID, email, or phone + password.
  Future<AuthResponse> login(String identifier, String password) async {
    String? email;
    try {
      email = await resolveLoginEmail(identifier);
    } catch (_) {
      email = null;
    }
    // Fall back to the deterministic mapping for phone-only accounts.
    email ??= SupabaseConfig.emailFor(identifier);
    try {
      await db.auth.signInWithPassword(email: email, password: password);
    } on AuthException catch (e) {
      throw UnauthorizedException(_friendly(e.message));
    } catch (e) {
      throw NetworkException(
        'Could not reach the server. Check your connection.',
      );
    }

    final uid = currentUid;
    if (uid == null)
      throw UnauthorizedException('Login failed. Please try again.');

    final profile = await fetchFullProfile(uid);
    if (profile == null) {
      await db.auth.signOut();
      throw UnauthorizedException('Account profile not found.');
    }

    _gateStatus(profile['status'] as String?, profile['role'] as String?);
    return AuthResponse(
      token: db.auth.currentSession?.accessToken ?? '',
      user: UserModel.fromJson(profile),
    );
  }

  /// Register a new patient. Returns a session (auto sign-in).
  Future<AuthResponse> register({
    required String name,
    required String email,
    required String password,
    String? phone,
    String? dob,
    String? gender,
    String? bloodGroup,
    String? emergencyPhone,
  }) async {
    // Use the patient's real email as the Auth identity when supplied. Phone-only
    // registrations retain the deterministic @hayaat.id alias.
    if (phone == null || phone.trim().length < 7) {
      throw BadRequestException('A valid phone number is required.');
    }
    final authEmail = email.trim().isNotEmpty
        ? email.trim().toLowerCase()
        : SupabaseConfig.emailFor(phone.replaceAll(RegExp(r'\D'), ''));
    try {
      await db.auth.signUp(
        email: authEmail,
        password: password,
        data: {
          'role': 'patient',
          'full_name': name,
          'phone': phone.trim(),
          if (email.isNotEmpty) 'email': email,
          if (dob != null) 'date_of_birth': dob,
          if (gender != null) 'gender': gender,
          if (bloodGroup != null) 'blood_group': bloodGroup,
          if (emergencyPhone != null) 'emergency_phone': emergencyPhone,
        },
      );
    } on AuthException catch (e) {
      throw BadRequestException(_friendly(e.message, isPhone: true));
    }

    if (db.auth.currentSession == null) {
      throw BadRequestException(
        'Account created, but email confirmation is on. Disable "Confirm email" in Supabase Auth settings.',
      );
    }
    final profile = await _profileWithRetry(currentUid!);
    return AuthResponse(
      token: db.auth.currentSession?.accessToken ?? '',
      user: UserModel.fromJson(profile),
    );
  }

  /// Register a doctor — created PENDING. No session is kept (admin must approve).
  Future<String> registerDoctor({
    required String fullName,
    required String password,
    required String pmdcNumber,
    required String specialization,
    required String phone,
    String? gender,
    String? dob,
    String? clinicId,
    String? email,
    bool mbbs = false,
    bool md = false,
    bool fcps = false,
    int? yearsExperience,
    num? consultationFee,
  }) async {
    if (phone.trim().length < 7)
      throw BadRequestException('A valid phone number is required.');
    final authEmail = SupabaseConfig.emailFor(
      phone.replaceAll(RegExp(r'\D'), ''),
    );
    try {
      await db.auth.signUp(
        email: authEmail,
        password: password,
        data: {
          'role': 'doctor',
          'full_name': fullName,
          'phone': phone.trim(),
          if (gender != null) 'gender': gender,
          if (dob != null) 'date_of_birth': dob,
          if (email != null && email.isNotEmpty) 'email': email,
          'pmdc_number': pmdcNumber,
          'specialization_primary': specialization,
          if (clinicId != null) 'clinic_id': clinicId,
          'qualification_mbbs': mbbs,
          'qualification_fcps': fcps,
        },
      );
    } on AuthException catch (e) {
      throw BadRequestException(_friendly(e.message, isPhone: true));
    }
    // Doctors cannot use the app until an admin approves them.
    await db.auth.signOut();
    return 'Application submitted. An administrator will review your account before you can log in.';
  }

  Future<void> signOut() => db.auth.signOut();

  Future<void> sendPasswordReset(String identifier) async {
    final clean = identifier.trim();
    if (clean.isEmpty) {
      throw BadRequestException('Enter your Hayaat ID, email, or phone first.');
    }
    String? email;
    try {
      email = await resolveLoginEmail(clean);
    } catch (_) {
      email = null;
    }
    email ??= clean.contains('@') ? clean : null;
    if (email == null) {
      throw BadRequestException('Enter the email attached to your account.');
    }
    await db.auth.resetPasswordForEmail(email);
  }

  // ── helpers ────────────────────────────────────────────────────────────────
  void _gateStatus(String? status, String? role) {
    if (status == 'pending') {
      db.auth.signOut();
      throw UnauthorizedException(
        'Your account is pending approval by an administrator.',
      );
    }
    if (status == 'suspended') {
      db.auth.signOut();
      throw UnauthorizedException(
        'This account has been suspended. Contact an administrator.',
      );
    }
    if (status == 'rejected') {
      db.auth.signOut();
      throw UnauthorizedException('This registration was not approved.');
    }
  }

  Future<Map<String, dynamic>> _profileWithRetry(String uid) async {
    var profile = await fetchFullProfile(uid);
    if (profile == null) {
      await Future.delayed(const Duration(milliseconds: 400));
      profile = await fetchFullProfile(uid);
    }
    return profile ??
        {'id': uid, 'role': 'patient', 'full_name': '', 'extended': {}};
  }

  String _friendly(String raw, {bool isPhone = false}) {
    final m = raw.toLowerCase();
    if (m.contains('invalid login')) return 'Invalid Hayaat ID or password.';
    if (m.contains('already registered') || m.contains('already exists')) {
      return isPhone
          ? 'An account with this phone number already exists.'
          : 'An account with this email or phone already exists.';
    }
    return raw;
  }
}
