import 'dart:convert';

import 'package:http/http.dart' as http;

/// "AI assistant doctor" — explains one of the patient's own records in
/// plain language via a locally-running LM Studio server (its OpenAI-compatible
/// API). Nothing is sent to any cloud LLM: the model runs entirely on the
/// machine LM Studio is installed on.
///
/// Requires LM Studio's local server to be started (Developer tab -> Start
/// Server) with a model loaded, and — when calling from a web build — its
/// "Enable CORS" setting turned on, since the app and LM Studio run on
/// different localhost ports.
class AiInsightsService {
  /// Base URL of LM Studio's OpenAI-compatible API. Override at build time with
  /// `--dart-define=LM_STUDIO_URL=http://<host>:<port>/v1`
  /// (e.g. `http://10.0.2.2:1234/v1` for the Android emulator, or the machine's
  /// LAN IP for a physical device on the same network).
  static const String _baseUrl = String.fromEnvironment(
    'LM_STUDIO_URL',
    defaultValue: 'http://localhost:1234/v1',
  );

  /// Pin a specific model with `--dart-define=LM_STUDIO_MODEL=<id>`. When empty,
  /// whichever chat model LM Studio currently has loaded is discovered and used.
  static const String _configuredModel = String.fromEnvironment('LM_STUDIO_MODEL');

  /// Reasoning models (Qwen3 and friends) spend a large share of their output
  /// budget on hidden reasoning before writing the answer, so this needs real
  /// headroom — too low and the reply comes back empty.
  static const int _maxTokens = 2500;

  static String? _discoveredModel;

  static const _systemPrompt = '''
You are the "Explain this record" assistant inside HayaatID, a Pakistani digital health card app.
A patient is looking at one record from their own medical history (a prescription, lab report, consultation note, or similar) and wants it explained in plain, everyday language.

Rules:
- Explain what the record says and what the key terms mean in simple language a non-medical person can understand.
- If lab values are given with a reference range, say plainly whether each is within, above, or below that range — but frame it as "this is a bit outside the usual range" rather than naming a disease.
- Never provide a new diagnosis, never contradict or second-guess the treating doctor, and never suggest changing or stopping a medication.
- Always close by encouraging the patient to discuss any questions or concerns with their doctor.
- Keep the tone warm, reassuring, and concise (roughly 150-300 words unless the record has a lot of detail).
- If asked to respond in Urdu, write the entire explanation in Urdu.
- If the record has too little information to say anything useful, say so honestly instead of guessing.''';

  /// LM Studio rejects a request without a `model`, so resolve one: the pinned
  /// id if configured, otherwise the first loaded non-embedding model.
  Future<String> _resolveModel() async {
    if (_configuredModel.isNotEmpty) return _configuredModel;
    final cached = _discoveredModel;
    if (cached != null) return cached;

    final http.Response res;
    try {
      res = await http
          .get(Uri.parse('$_baseUrl/models'))
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      // On web a CORS rejection surfaces as a plain network failure, identical
      // to the server being down — so name both causes rather than guessing.
      throw Exception(
        'Could not reach LM Studio at $_baseUrl.\n\n'
        'Check both of these:\n'
        '1. LM Studio is running with its local server started, and a model is loaded.\n'
        '2. "Enable CORS" is switched on in the LM Studio server settings — without '
        'it the browser blocks the request before it is ever sent, which looks '
        'exactly like the server being offline.',
      );
    }
    if (res.statusCode != 200) {
      throw Exception('LM Studio returned HTTP ${res.statusCode} when listing models.');
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final models = (body['data'] as List?) ?? const [];
    for (final entry in models) {
      final id = (entry as Map)['id']?.toString() ?? '';
      // Embedding models can't answer chat completions.
      if (id.isEmpty || id.toLowerCase().contains('embed')) continue;
      _discoveredModel = id;
      return id;
    }
    throw Exception('No chat model is loaded in LM Studio. Load one and try again.');
  }

  Future<String> explainRecord(
    Map<String, dynamic> record, {
    required bool urdu,
  }) async {
    final model = await _resolveModel();
    final language = urdu ? 'Urdu' : 'English';
    final recordText = const JsonEncoder.withIndent('  ').convert(record);
    final userPrompt =
        'Please explain this medical record to me. Respond in $language.\n\n$recordText';

    final http.Response res;
    try {
      res = await http
          .post(
            Uri.parse('$_baseUrl/chat/completions'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'model': model,
              'messages': [
                {'role': 'system', 'content': _systemPrompt},
                {'role': 'user', 'content': userPrompt},
              ],
              'temperature': 0.4,
              'max_tokens': _maxTokens,
              'stream': false,
            }),
          )
          .timeout(const Duration(minutes: 5));
    } catch (_) {
      throw Exception(
        'LM Studio did not respond in time. A local model can be slow on the '
        'first request — try again, or load a smaller model.',
      );
    }

    if (res.statusCode != 200) {
      throw Exception('LM Studio returned an error (HTTP ${res.statusCode}).');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final choices = data['choices'] as List?;
    if (choices == null || choices.isEmpty) {
      throw Exception('LM Studio did not return an explanation.');
    }
    final message = (choices.first as Map)['message'] as Map?;
    final content = (message?['content'] as String?)?.trim() ?? '';
    if (content.isNotEmpty) return content;

    // A reasoning model that spent its whole budget thinking returns empty
    // content — say so plainly rather than showing a blank sheet.
    final reasoned = (message?['reasoning_content'] as String?)?.trim() ?? '';
    if (reasoned.isNotEmpty) {
      throw Exception(
        'The model ran out of room while thinking and did not finish its answer. '
        'Try again, or use a non-reasoning model in LM Studio.',
      );
    }
    throw Exception('LM Studio did not return an explanation.');
  }
}
