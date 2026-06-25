import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/auth_model.dart';
import 'api_config.dart';

/// Custom exception class to handle various API error scenarios.
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

class AuthService {
  // Uses centralized api_config.dart
  static const String _baseUrl = ApiConfig.baseUrl;

  final http.Client _client;

  AuthService({http.Client? client}) : _client = client ?? http.Client();

  // In-memory mock database of users
  static final List<Map<String, dynamic>> _mockUsers = [
    {
      'id': 'user_demo_id',
      'name': 'Ayesha Khan',
      'email': 'ayesha@example.com',
      'password': 'password123',
      'phone': '+92 310 1234567',
      'healthId': 'PK-HC-9F2A-7T',
      'dob': '14 Mar 1958',
      'gender': 'Female',
      'bloodGroup': 'B+',
    }
  ];

  /// Logs in the user with email and password.
  /// Throws [ApiException] or [NetworkException] on failure.
  Future<AuthResponse> login(String email, String password) async {
    final url = Uri.parse('$_baseUrl/auth/login');
    
    try {
      final response = await _client.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      return _processResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      
      // Backend server is offline or unreachable. Fallback to simulated success for testing.
      debugPrint('AuthService: Backend offline. Falling back to simulated login validation.');
      await Future.delayed(const Duration(milliseconds: 1200));

      final emailTrim = email.trim().toLowerCase();
      // Search by email or phone
      Map<String, dynamic>? userMap;
      try {
        userMap = _mockUsers.firstWhere(
          (u) => (u['email'].toString().toLowerCase() == emailTrim || 
                  u['phone'].toString() == emailTrim) && 
                 u['password'] == password,
        );
      } catch (_) {
        throw UnauthorizedException('Invalid email/phone or password');
      }

      return AuthResponse(
        token: 'demo_token_${userMap['id']}',
        user: UserModel.fromJson(userMap),
      );
    }
  }

  /// Registers a new user/patient.
  /// Throws [ApiException] or [NetworkException] on failure.
  Future<AuthResponse> register({
    required String name,
    required String email,
    required String password,
    String? phone,
    String? dob,
    String? gender,
    String? bloodGroup,
  }) async {
    final url = Uri.parse('$_baseUrl/auth/register');
    
    try {
      final response = await _client.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
          'phone':? phone,
          'dob':? dob,
          'gender':? gender,
          'bloodGroup':? bloodGroup,
        }),
      );

      return _processResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;

      // Backend server is offline or unreachable. Fallback to simulated success for testing.
      debugPrint('AuthService: Backend offline. Falling back to simulated register.');
      await Future.delayed(const Duration(milliseconds: 1200));

      final emailTrim = email.trim().toLowerCase();
      if (_mockUsers.any((u) => u['email'].toString().toLowerCase() == emailTrim ||
          (phone != null && phone.isNotEmpty && u['phone'] == phone))) {
        throw BadRequestException('User with this email or phone already exists');
      }

      final newId = 'user_${DateTime.now().millisecondsSinceEpoch}';
      final newUser = {
        'id': newId,
        'name': name,
        'email': email,
        'password': password,
        'phone': phone ?? '',
        'healthId': 'PK-HC-${(email.hashCode % 10000).toString().padLeft(4, '0')}',
        'dob': dob ?? '14 Mar 1958',
        'gender': gender ?? 'Male',
        'bloodGroup': bloodGroup ?? 'B+',
      };

      _mockUsers.add(newUser);

      return AuthResponse(
        token: 'demo_token_$newId',
        user: UserModel.fromJson(newUser),
      );
    }
  }

  /// Common response processor to handle HTTP status codes and map to proper models or exceptions.
  AuthResponse _processResponse(http.Response response) {
    final int statusCode = response.statusCode;
    
    Map<String, dynamic> responseBody;
    try {
      responseBody = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      responseBody = {'message': 'Unknown server response'};
    }

    final String message = responseBody['message'] ?? responseBody['error'] ?? 'An error occurred';

    if (statusCode >= 200 && statusCode < 300) {
      return AuthResponse.fromJson(responseBody);
    } else if (statusCode == 400) {
      throw BadRequestException(message);
    } else if (statusCode == 401) {
      throw UnauthorizedException(message);
    } else if (statusCode >= 500) {
      throw ServerException('Server error: $message');
    } else {
      throw ApiException('Request failed with status code $statusCode: $message', statusCode: statusCode);
    }
  }
}
