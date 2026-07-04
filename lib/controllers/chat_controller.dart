import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat_models.dart';
import '../services/chat_service.dart';
import '../services/supabase_client.dart';

/// Drives the patient messaging UI over real Supabase data + realtime.
/// No mock data and no simulated replies — a doctor reply arrives only when a
/// doctor actually sends one (from the staff portal), pushed live via realtime.
class ChatController extends ChangeNotifier {
  final ChatService _service;

  List<Conversation> _conversations = [];
  bool _isLoading = false;
  bool _loaded = false;
  String? _errorMessage;
  RealtimeChannel? _channel;

  List<Conversation> get conversations => _conversations;
  bool get isLoading => _isLoading;
  bool get loaded => _loaded;
  String? get errorMessage => _errorMessage;

  ChatController({ChatService? service}) : _service = service ?? ChatService();

  /// Loads all conversations for the signed-in patient and starts the realtime
  /// subscription. [token] is accepted for call-site compatibility but unused —
  /// the Supabase client already holds the session.
  Future<void> loadConversations([String? token]) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _conversations = await _service.fetchConversations();
      _channel ??= _service.subscribe(_onRealtime);
    } catch (e) {
      _errorMessage = 'Failed to load conversations: $e';
    } finally {
      _isLoading = false;
      _loaded = true;
      notifyListeners();
    }
  }

  void _onRealtime(Map<String, dynamic> row) {
    // Our own messages are shown optimistically on send — ignore the echo so we
    // don't do a redundant reload. A doctor's reply triggers one cheap refresh.
    if (row['sender_id'] == currentUid) return;
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      _conversations = await _service.fetchConversations();
      notifyListeners();
    } catch (_) {
      // Transient; keep the current view. Next event or reload will recover.
    }
  }

  /// Sends a message to [doctorId]. [token] retained for call-site compatibility.
  Future<bool> sendMessage(String token, String doctorId, String text) async {
    final body = text.trim();
    if (body.isEmpty) return false;
    try {
      await _service.sendMessage(doctorId, body);
      final idx = _conversations.indexWhere((c) => c.doctorId == doctorId);
      if (idx == -1) {
        await _refresh(); // first message to this doctor — pull in the new conversation
      } else {
        // Optimistic: show it immediately and move the thread to the top; no reload.
        final convo = _conversations[idx];
        final msg = _service.outgoing(body);
        _conversations
          ..removeAt(idx)
          ..insert(0, convo.copyWith(
            last: body,
            time: msg.time,
            messages: [...convo.messages, msg],
          ));
        notifyListeners();
      }
      return true;
    } catch (e) {
      _errorMessage = 'Failed to send message: $e';
      notifyListeners();
      return false;
    }
  }

  /// Marks the doctor's messages in a conversation as read.
  Future<void> markAsRead(String doctorId) async {
    final index = _conversations.indexWhere((c) => c.doctorId == doctorId);
    if (index == -1) return;
    final convo = _conversations[index];
    if (convo.unread == 0) return;

    _conversations[index] = convo.copyWith(unread: 0);
    notifyListeners();
    await _service.markRead(convo.conversationId);
  }

  /// Clears state and tears down realtime on logout.
  void clear() {
    _teardown();
    _conversations = [];
    _loaded = false;
    _errorMessage = null;
    notifyListeners();
  }

  void _teardown() {
    final ch = _channel;
    if (ch != null) {
      _channel = null;
      _service.unsubscribe(ch);
    }
  }

  @override
  void dispose() {
    _teardown();
    super.dispose();
  }
}
