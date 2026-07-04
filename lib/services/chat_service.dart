import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat_models.dart';
import 'supabase_client.dart';

/// Real patient↔doctor messaging backed by Supabase (`conversations` +
/// `messages` tables, see `supabase/chat.sql`). Replaces the old demo Node/HTTP
/// chat stub — there is no mock fallback and no simulated replies.
class ChatService {
  SupabaseClient get _db => db;

  String _fmtTime(DateTime dtUtc) {
    final l = dtUtc.toLocal();
    final now = DateTime.now();
    final sameDay = l.year == now.year && l.month == now.month && l.day == now.day;
    if (sameDay) {
      return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
    }
    final days = now.difference(l).inDays;
    if (days <= 1) return 'Yesterday';
    if (days < 7) {
      const w = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return w[l.weekday - 1];
    }
    return '${l.day}/${l.month}';
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'Dr';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  /// All conversations for the signed-in patient, each with its full message
  /// history. RLS guarantees only the patient's own rows are returned.
  Future<List<Conversation>> fetchConversations() async {
    final uid = currentUid;
    if (uid == null) return [];

    final convRows = await _db
        .from('conversations')
        .select('id, doctor_id, last_message, last_message_at, doctor:profiles!doctor_id(full_name)')
        .eq('patient_id', uid)
        .order('last_message_at', ascending: false);
    if (convRows.isEmpty) return [];

    // One query for every message across all the patient's conversations, then
    // group in memory — avoids an N+1 (a separate query per conversation).
    final convIds = [for (final m in convRows) m['id'] as String];
    final msgRows = await _db
        .from('messages')
        .select('conversation_id, sender_id, body, created_at, read_at')
        .inFilter('conversation_id', convIds)
        .order('created_at', ascending: true);

    final byConv = <String, List<Map<String, dynamic>>>{};
    for (final mm in msgRows) {
      (byConv[mm['conversation_id'] as String] ??= []).add(mm);
    }

    final out = <Conversation>[];
    for (final m in convRows) {
      final convId = m['id'] as String;
      final doctor = m['doctor'] as Map<String, dynamic>?;
      final name = (doctor?['full_name'] as String?) ?? 'Doctor';

      final messages = <ChatMessage>[];
      var unread = 0;
      for (final mm in (byConv[convId] ?? const <Map<String, dynamic>>[])) {
        final fromMe = mm['sender_id'] == uid;
        messages.add(ChatMessage(
          text: mm['body'] as String,
          fromMe: fromMe,
          time: _fmtTime(DateTime.parse(mm['created_at'] as String)),
        ));
        if (!fromMe && mm['read_at'] == null) unread++;
      }

      final last = messages.isNotEmpty ? messages.last.text : ((m['last_message'] as String?) ?? '');
      final lastAtRaw = m['last_message_at'] as String?;
      final time = lastAtRaw != null ? _fmtTime(DateTime.parse(lastAtRaw)) : '';

      out.add(Conversation(
        conversationId: convId,
        doctorId: m['doctor_id'] as String,
        initials: _initials(name),
        name: name,
        last: last,
        time: time,
        unread: unread,
        online: false,
        messages: messages,
      ));
    }
    return out;
  }

  /// Send a message from the signed-in patient to [doctorId], creating the
  /// conversation on first contact. Throws on failure (no silent fallback).
  Future<void> sendMessage(String doctorId, String text) async {
    final uid = currentUid;
    if (uid == null) throw StateError('Not signed in');
    final body = text.trim();
    if (body.isEmpty) return;

    final rpcResult = await _db.rpc('start_conversation', params: {
      'p_patient': uid,
      'p_doctor': doctorId,
    });
    final convId = rpcResult as String;

    await _db.from('messages').insert({
      'conversation_id': convId,
      'sender_id': uid,
      'body': body,
    });
  }

  /// Mark the doctor's messages in [conversationId] as read.
  Future<void> markRead(String conversationId) async {
    final uid = currentUid;
    if (uid == null || conversationId.isEmpty) return;
    await _db
        .from('messages')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('conversation_id', conversationId)
        .neq('sender_id', uid)
        .isFilter('read_at', null);
  }

  /// Local echo of a message the patient just sent (shown immediately on send).
  ChatMessage outgoing(String text) =>
      ChatMessage(text: text, fromMe: true, time: _fmtTime(DateTime.now().toUtc()));

  /// Subscribe to new messages in realtime; [onEvent] receives the inserted row
  /// so the caller can react to just that message. Returns the channel so the
  /// caller can [unsubscribe] on teardown.
  RealtimeChannel subscribe(void Function(Map<String, dynamic> newRow) onEvent) {
    final channel = _db.channel('patient:messages').onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (payload) => onEvent(payload.newRecord),
        );
    channel.subscribe();
    return channel;
  }

  Future<void> unsubscribe(RealtimeChannel channel) async {
    await _db.removeChannel(channel);
  }
}
