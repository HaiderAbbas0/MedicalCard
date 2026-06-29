import 'dart:convert';
import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'auth_service.dart' show ApiException, UnauthorizedException, ServerException, BadRequestException;

/// Authenticated JSON API client shared by the doctor / lab / receptionist
/// feature services. Construct it with the current bearer token.
class ApiClient {
  final String token;
  final http.Client _client;

  ApiClient(this.token, {http.Client? client}) : _client = client ?? http.Client();

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };

  Uri _uri(String path) => Uri.parse('${ApiConfig.baseUrl}$path');

  Future<dynamic> get(String path) async => _send(() => _client.get(_uri(path), headers: _headers));

  Future<dynamic> post(String path, [Map<String, dynamic>? body]) async =>
      _send(() => _client.post(_uri(path), headers: _headers, body: jsonEncode(body ?? {})));

  Future<dynamic> patch(String path, [Map<String, dynamic>? body]) async =>
      _send(() => _client.patch(_uri(path), headers: _headers, body: jsonEncode(body ?? {})));

  Future<dynamic> delete(String path) async => _send(() => _client.delete(_uri(path), headers: _headers));

  Future<dynamic> _send(Future<http.Response> Function() request) async {
    final http.Response res;
    try {
      res = await request();
    } catch (_) {
      throw ApiException('Network error — could not reach the server.');
    }

    dynamic body;
    if (res.body.isNotEmpty) {
      try {
        body = jsonDecode(res.body);
      } catch (_) {
        body = null;
      }
    }

    if (res.statusCode >= 200 && res.statusCode < 300) return body;

    final message = (body is Map && body['message'] != null)
        ? body['message'].toString()
        : 'Request failed (${res.statusCode}).';
    if (res.statusCode == 400) throw BadRequestException(message);
    if (res.statusCode == 401 || res.statusCode == 403) throw UnauthorizedException(message);
    if (res.statusCode >= 500) throw ServerException(message);
    throw ApiException(message, statusCode: res.statusCode);
  }
}
