import 'dart:convert';

class PromptModel {
  final String? id;
  final String title;
  final String content;
  final String description;
  final bool isPublic;
  final String? category;
  final String? language;
  final String? userId;
  final String? userName;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  PromptModel({
    this.id,
    required this.title,
    required this.content,
    required this.description,
    required this.isPublic,
    this.category = 'other',
    this.language = 'English',
    this.userId,
    this.userName,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'content': content,
      'description': description,
      'isPublic': isPublic,
      'category': category,
      'language': language,
      'userId': userId,
      'userName': userName,
    };
  }

  // Creates the JSON body for API requests
  Map<String, dynamic> toRequestBody() {
    return {
      // Optional fields in API but include them if available
      if (title.isNotEmpty) 'title': title,
      if (content.isNotEmpty) 'content': content,
      
      // Required fields per API documentation
      'description': description,
      'isPublic': isPublic,
      'category': category ?? 'other', // Default category if not specified
      'language': language ?? 'English', // Default language if not specified
    };
  }

  // Creates the JSON body specifically for update requests
  Map<String, dynamic> toUpdateRequestBody({
    bool includeContent = true,
    bool includeTitle = true,
  }) {
    final Map<String, dynamic> body = {
      // Required fields per API documentation
      'description': description,
      'isPublic': isPublic,
      'category': category ?? 'other',
      'language': language ?? 'English',
    };
    
    // Only include optional fields if specified and not empty
    if (includeTitle && title.isNotEmpty) {
      body['title'] = title;
    }
    
    if (includeContent && content.isNotEmpty) {
      body['content'] = content;
    }
    
    return body;
  }

  factory PromptModel.fromMap(Map<String, dynamic> map) {
    return PromptModel(
      id: map['_id'] ?? map['id'],
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      description: map['description'] ?? '',
      isPublic: map['isPublic'] ?? false,
      category: map['category'],
      language: map['language'],
      userId: map['userId'],
      userName: map['userName'],
      createdAt: map['createdAt'] != null 
        ? DateTime.tryParse(map['createdAt'])
        : null,
      updatedAt: map['updatedAt'] != null 
        ? DateTime.tryParse(map['updatedAt'])
        : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory PromptModel.fromJson(String source) => 
      PromptModel.fromMap(json.decode(source));

  PromptModel copyWith({
    String? id,
    String? title,
    String? content,
    String? description,
    bool? isPublic,
    String? category,
    String? language,
    String? userId,
    String? userName,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PromptModel(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      description: description ?? this.description,
      isPublic: isPublic ?? this.isPublic,
      category: category ?? this.category,
      language: language ?? this.language,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
