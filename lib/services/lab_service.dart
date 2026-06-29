import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/clinical_models.dart';
import 'api_client.dart';
import 'api_config.dart';
import 'auth_service.dart' show ApiException, BadRequestException;

/// Lab-worker-facing API calls (Scope §11.4).
class LabService {
  final String _token;
  final ApiClient _api;
  LabService(this._token) : _api = ApiClient(_token);

  Future<List<LabOrderModel>> queue() async {
    final res = await _api.get('/lab/orders');
    return (res as List).map((e) => LabOrderModel.fromJson(e)).toList();
  }

  Future<void> markCollected(String orderId) => _api.patch('/lab/orders/$orderId/collect');
  Future<void> markProcessing(String orderId) => _api.patch('/lab/orders/$orderId/processing');

  /// Simulated result (structured values + comments, no binary file).
  Future<void> uploadResult(
    String orderId, {
    String? fileName,
    String? comments,
    List<Map<String, dynamic>>? structuredResults,
  }) {
    return _api.post('/lab/orders/$orderId/result', {
      if (fileName != null) 'result_file_name': fileName,
      if (comments != null) 'comments': comments,
      if (structuredResults != null) 'structured_results': structuredResults,
    });
  }

  /// Real multipart PDF upload to /lab/orders/:id/result-file (P-FR-055).
  /// Pass the local [filePath] of the selected result document.
  Future<void> uploadResultFile(
    String orderId,
    String filePath, {
    String? comments,
    List<Map<String, dynamic>>? structuredResults,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/lab/orders/$orderId/result-file');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $_token'
      ..files.add(await http.MultipartFile.fromPath('file', filePath));
    if (comments != null) request.fields['comments'] = comments;
    if (structuredResults != null) {
      request.fields['structured_results'] = jsonEncode(structuredResults);
    }

    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode >= 200 && res.statusCode < 300) return;

    String message = 'Upload failed (${res.statusCode}).';
    try {
      message = (jsonDecode(res.body) as Map)['message']?.toString() ?? message;
    } catch (_) {}
    if (res.statusCode == 400) throw BadRequestException(message);
    throw ApiException(message, statusCode: res.statusCode);
  }
}
