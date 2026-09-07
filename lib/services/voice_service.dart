import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Wraps on-device speech-to-text and text-to-speech behind one small API so
/// screens don't touch the underlying plugins directly.
class VoiceService {
  VoiceService._();
  static final VoiceService instance = VoiceService._();

  final stt.SpeechToText _stt = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  bool _sttInitialized = false;

  bool get isListening => _stt.isListening;

  Future<bool> _ensureInitialized() async {
    if (_sttInitialized) return true;
    _sttInitialized = await _stt.initialize(
      onError: (SpeechRecognitionError e) =>
          debugPrint('VoiceService: speech error ${e.errorMsg}'),
    );
    return _sttInitialized;
  }

  /// Starts listening. [onResult] is called with the recognized text on
  /// every partial and final result; [isFinal] marks the end of an utterance.
  /// Returns false when the microphone/speech engine isn't available
  /// (permission denied, unsupported device, etc.).
  Future<bool> startListening({
    required void Function(String text, bool isFinal) onResult,
  }) async {
    if (!await _ensureInitialized()) return false;
    await _stt.listen(
      onResult: (r) => onResult(r.recognizedWords, r.finalResult),
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
      ),
    );
    return true;
  }

  Future<void> stopListening() => _stt.stop();

  Future<void> speak(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    await _tts.stop();
    await _tts.speak(trimmed);
  }

  Future<void> stopSpeaking() => _tts.stop();
}
