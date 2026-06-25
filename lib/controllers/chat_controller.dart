import 'dart:async';
import 'package:flutter/material.dart';
import '../models/chat_models.dart';
import '../services/chat_service.dart';

class ChatController extends ChangeNotifier {
  final ChatService _service;

  List<Conversation> _conversations = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  List<Conversation> get conversations => _conversations;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  ChatController({ChatService? service}) : _service = service ?? ChatService();

  /// Loads all conversations.
  Future<void> loadConversations(String token) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _conversations = await _service.fetchConversations(token);
    } catch (e) {
      _errorMessage = 'Failed to load conversations: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Sends a message and triggers a simulated reply if running in mock/offline mode.
  Future<bool> sendMessage(String token, String doctorId, String text) async {
    if (text.trim().isEmpty) return false;

    try {
      final chatMsg = await _service.sendMessage(token, doctorId, text);

      // Find active conversation
      final index = _conversations.indexWhere((c) => c.doctorId == doctorId);
      if (index != -1) {
        final convo = _conversations[index];
        final updatedMessages = List<ChatMessage>.from(convo.messages)..add(chatMsg);
        
        _conversations[index] = convo.copyWith(
          last: text,
          time: chatMsg.time,
          messages: updatedMessages,
        );
        notifyListeners();

        // Simulate reply if using mock service (token starts with 'demo_' or 'mock_')
        if (token.startsWith('demo_') || token.startsWith('mock_')) {
          _simulateDoctorReply(doctorId);
        }
      }
      return true;
    } catch (e) {
      _errorMessage = 'Failed to send message: $e';
      notifyListeners();
      return false;
    }
  }

  /// Simulates a doctor replying after a brief delay.
  void _simulateDoctorReply(String doctorId) {
    Timer(const Duration(milliseconds: 1500), () {
      final index = _conversations.indexWhere((c) => c.doctorId == doctorId);
      if (index == -1) return;

      final convo = _conversations[index];
      
      String replyText = 'Thank you for your message. I will review it and get back to you shortly.';
      if (doctorId == 'imran') {
        replyText = 'Please continue taking your medication as prescribed and record your daily BP readings.';
      } else if (doctorId == 'sana') {
        replyText = 'Your fasting sugar level is looking better. Keep up the low-carb diet.';
      } else if (doctorId == 'care') {
        replyText = 'Understood. If you need any assistance regarding your health card, let us know!';
      }

      final now = DateTime.now();
      final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      
      final replyMsg = ChatMessage(
        text: replyText,
        fromMe: false,
        time: timeStr,
      );

      final updatedMessages = List<ChatMessage>.from(convo.messages)..add(replyMsg);
      _conversations[index] = convo.copyWith(
        last: replyText,
        time: timeStr,
        unread: convo.unread + 1,
        messages: updatedMessages,
      );
      notifyListeners();
    });
  }

  /// Marks a conversation as read.
  void markAsRead(String doctorId) {
    final index = _conversations.indexWhere((c) => c.doctorId == doctorId);
    if (index != -1 && _conversations[index].unread > 0) {
      _conversations[index] = _conversations[index].copyWith(unread: 0);
      notifyListeners();
    }
  }

  /// Clears stored chat history on logout.
  void clear() {
    _conversations = [];
    _errorMessage = null;
    notifyListeners();
  }
}
