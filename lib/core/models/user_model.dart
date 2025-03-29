import 'dart:convert';

class UserModel {
  final String id; // Add this field
  final String uid;
  final String email;
  final String? name;
  final DateTime createdAt;
  final bool isEmailVerified;
  final String? selectedModel;

  // Add Stack Auth metadata fields
  final Map<String, dynamic>? clientMetadata;
  final Map<String, dynamic>? clientReadOnlyMetadata;
  final Map<String, dynamic>? serverMetadata;

  UserModel({
    required this.id, // Add this to constructor
    required this.uid,
    required this.email,
    this.name,
    required this.createdAt,
    this.isEmailVerified = false,
    this.selectedModel,
    this.clientMetadata,
    this.clientReadOnlyMetadata,
    this.serverMetadata,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id, // Add this to map
      'uid': uid,
      'email': email,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'isEmailVerified': isEmailVerified,
      'selectedModel': selectedModel,
      'clientMetadata': clientMetadata,
      'clientReadOnlyMetadata': clientReadOnlyMetadata,
      'serverMetadata': serverMetadata,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] ?? '', // Add this to fromMap
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      name: map['name'],
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
      isEmailVerified: map['isEmailVerified'] ?? false,
      selectedModel: map['selectedModel'],
      clientMetadata: map['clientMetadata'],
      clientReadOnlyMetadata: map['clientReadOnlyMetadata'],
      serverMetadata: map['serverMetadata'],
    );
  }

  String toJson() => json.encode(toMap());

  factory UserModel.fromJson(String source) =>
      UserModel.fromMap(json.decode(source));

  UserModel copyWith({
    String? id,
    String? uid,
    String? email,
    String? name,
    DateTime? createdAt,
    bool? isEmailVerified,
    String? selectedModel,
    Map<String, dynamic>? clientMetadata,
    Map<String, dynamic>? clientReadOnlyMetadata,
    Map<String, dynamic>? serverMetadata,
  }) {
    return UserModel(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      email: email ?? this.email,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      selectedModel: selectedModel ?? this.selectedModel,
      clientMetadata: clientMetadata ?? this.clientMetadata,
      clientReadOnlyMetadata:
          clientReadOnlyMetadata ?? this.clientReadOnlyMetadata,
      serverMetadata: serverMetadata ?? this.serverMetadata,
    );
  }

  @override
  String toString() {
    return 'UserModel(id: $id, uid: $uid, email: $email, name: $name, isEmailVerified: $isEmailVerified)';
  }
}