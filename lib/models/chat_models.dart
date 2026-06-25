class ChatMessage {
  final String text;
  final bool fromMe;
  final String time;

  ChatMessage({
    required this.text,
    required this.fromMe,
    required this.time,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      text: json['text'] as String,
      fromMe: json['fromMe'] as bool,
      time: json['time'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'fromMe': fromMe,
      'time': time,
    };
  }
}

class Conversation {
  final String doctorId;
  final String initials;
  final String name;
  final String last;
  final String time;
  final int unread;
  final bool online;
  final List<ChatMessage> messages;

  Conversation({
    required this.doctorId,
    required this.initials,
    required this.name,
    required this.last,
    required this.time,
    required this.unread,
    required this.online,
    required this.messages,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    final msgList = (json['messages'] as List? ?? [])
        .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
        .toList();

    return Conversation(
      doctorId: json['doctorId'] as String,
      initials: json['initials'] as String,
      name: json['name'] as String,
      last: json['last'] as String,
      time: json['time'] as String,
      unread: json['unread'] as int,
      online: json['online'] as bool,
      messages: msgList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'doctorId': doctorId,
      'initials': initials,
      'name': name,
      'last': last,
      'time': time,
      'unread': unread,
      'online': online,
      'messages': messages.map((m) => m.toJson()).toList(),
    };
  }

  Conversation copyWith({
    String? doctorId,
    String? initials,
    String? name,
    String? last,
    String? time,
    int? unread,
    bool? online,
    List<ChatMessage>? messages,
  }) {
    return Conversation(
      doctorId: doctorId ?? this.doctorId,
      initials: initials ?? this.initials,
      name: name ?? this.name,
      last: last ?? this.last,
      time: time ?? this.time,
      unread: unread ?? this.unread,
      online: online ?? this.online,
      messages: messages ?? this.messages,
    );
  }
}
