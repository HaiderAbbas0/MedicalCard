import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/chat_models.dart';
import 'api_config.dart';
import 'auth_service.dart';

class ChatService {
  static const String _baseUrl = ApiConfig.baseUrl;

  final http.Client _client;

  ChatService({http.Client? client}) : _client = client ?? http.Client();

  /// Fetches conversations list.
  Future<List<Conversation>> fetchConversations(String token) async {
    final url = Uri.parse('$_baseUrl/patient/conversations');
    try {
      final response = await _client.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final List<dynamic> body = jsonDecode(response.body) as List;
        return body.map((c) => Conversation.fromJson(c as Map<String, dynamic>)).toList();
      } else {
        throw ApiException('Failed to load conversations', statusCode: response.statusCode);
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      debugPrint('ChatService: Fetch conversations failed. Falling back to mock data.');
      await Future.delayed(const Duration(milliseconds: 600));

      return [
        Conversation(
          doctorId: 'imran',
          initials: 'IY',
          name: 'Dr. Imran Yousuf',
          last: 'Yes, same dose. I’ve added it to your…',
          time: '09:21',
          unread: 1,
          online: true,
          messages: [
            ChatMessage(text: 'Your BP readings look stable. Keep logging twice daily.', fromMe: false, time: '09:12'),
            ChatMessage(text: 'Thank you doctor. Should I continue Amlodipine?', fromMe: true, time: '09:20'),
            ChatMessage(text: 'Yes, same dose. I’ve added it to your prescriptions.', fromMe: false, time: '09:21'),
          ],
        ),
        Conversation(
          doctorId: 'sana',
          initials: 'ST',
          name: 'Dr. Sana Tariq',
          last: 'Your HbA1c looks much better.',
          time: 'Yesterday',
          unread: 0,
          online: false,
          messages: [
            ChatMessage(text: 'I uploaded my fasting sugar log for the week.', fromMe: true, time: '18:02'),
            ChatMessage(text: 'Your HbA1c looks much better. Well done!', fromMe: false, time: '18:30'),
          ],
        ),
        Conversation(
          doctorId: 'care',
          initials: 'SC',
          name: 'Hayaat Care Team',
          last: 'Welcome to HayaatID 👋',
          time: 'Mon',
          unread: 0,
          online: false,
          messages: [
            ChatMessage(text: 'Welcome to HayaatID 👋 We’re here if you need anything.', fromMe: false, time: 'Mon'),
          ],
        ),
      ];
    }
  }

  /// Sends a chat message.
  Future<ChatMessage> sendMessage(String token, String doctorId, String text) async {
    final url = Uri.parse('$_baseUrl/patient/chat/send');
    try {
      final response = await _client.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'doctorId': doctorId,
          'message': text,
        }),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> body = jsonDecode(response.body) as Map<String, dynamic>;
        return ChatMessage.fromJson(body);
      } else {
        throw ApiException('Failed to send message', statusCode: response.statusCode);
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      debugPrint('ChatService: Send message failed. Simulating local message append.');
      await Future.delayed(const Duration(milliseconds: 200));

      final now = DateTime.now();
      final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      return ChatMessage(
        text: text,
        fromMe: true,
        time: timeStr,
      );
    }
  }
}
