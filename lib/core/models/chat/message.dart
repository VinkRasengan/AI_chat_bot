import 'dart:convert';

// Message data model that represents individual messages in chat history
class Message {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isTyping;
  final String? id;
  final Map<String, dynamic>? metadata;

  Message({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isTyping = false,
    this.id,
    this.metadata,
  });

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'isUser': isUser,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'isTyping': isTyping,
      'id': id,
      'metadata': metadata,
    };
  }

  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      text: map['text'] ?? '',
      isUser: map['isUser'] ?? false,
      timestamp: map['timestamp'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['timestamp'])
          : DateTime.now(),
      isTyping: map['isTyping'] ?? false,
      id: map['id'],
      metadata: map['metadata'],
    );
  }

  String toJson() => json.encode(toMap());

  factory Message.fromJson(String source) => Message.fromMap(json.decode(source));

  Message copyWith({
    String? text,
    bool? isUser,
    DateTime? timestamp,
    bool? isTyping,
    String? id,
    Map<String, dynamic>? metadata,
  }) {
    return Message(
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
      isTyping: isTyping ?? this.isTyping,
      id: id ?? this.id,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() {
    return 'Message(text: $text, isUser: $isUser, timestamp: $timestamp, isTyping: $isTyping)';
  }
}

// Helper extension to check if a message is a system message
extension MessageExtension on Message {
  bool get isSystemMessage {
    return metadata != null && metadata!['isSystemMessage'] == true;
  }
  
  bool get isInitializationMessage {
    return isUser && text == 'start_conversation';
  }
  
  bool get isDuplicateWelcomeMessage {
    return isUser && text == 'Hello, how can I help you today?';
  }
}