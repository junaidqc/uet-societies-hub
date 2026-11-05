// ============================================================================
// Model: group_model.dart
// Description: Data models for Committee & Sub-committee Groups (FR-26..FR-32)
// ============================================================================

class GroupModel {
  final String id;
  final String societyId;
  final String? societyName;
  final String name;
  final String? description;
  final bool isPrivate;
  final DateTime createdAt;
  final int memberCount;

  const GroupModel({
    required this.id,
    required this.societyId,
    this.societyName,
    required this.name,
    this.description,
    this.isPrivate = true,
    required this.createdAt,
    this.memberCount = 0,
  });

  factory GroupModel.fromMap(Map<String, dynamic> map) {
    return GroupModel(
      id: map['id'] as String,
      societyId: map['society_id'] as String,
      societyName: map['societies'] != null ? map['societies']['name'] as String? : null,
      name: map['name'] as String? ?? 'Committee Group',
      description: map['description'] as String?,
      isPrivate: map['is_private'] as bool? ?? true,
      createdAt: DateTime.parse(map['created_at'] as String),
      memberCount: map['member_count'] is int ? map['member_count'] as int : 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'society_id': societyId,
      'name': name,
      'description': description,
      'is_private': isPrivate,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class GroupMemberModel {
  final String id;
  final String groupId;
  final String userId;
  final String role; // 'admin' | 'moderator' | 'member'
  final DateTime joinedAt;
  final String? fullName;
  final String? email;
  final String? rollNumber;
  final String? avatarUrl;

  const GroupMemberModel({
    required this.id,
    required this.groupId,
    required this.userId,
    required this.role,
    required this.joinedAt,
    this.fullName,
    this.email,
    this.rollNumber,
    this.avatarUrl,
  });

  factory GroupMemberModel.fromMap(Map<String, dynamic> map) {
    final profile = map['profiles'] as Map<String, dynamic>?;
    return GroupMemberModel(
      id: map['id'] as String,
      groupId: map['group_id'] as String,
      userId: map['user_id'] as String,
      role: map['role'] as String? ?? 'member',
      joinedAt: DateTime.parse(map['joined_at'] as String),
      fullName: profile?['full_name'] as String? ?? 'Student Member',
      email: profile?['email'] as String?,
      rollNumber: profile?['roll_number'] as String?,
      avatarUrl: profile?['avatar_url'] as String?,
    );
  }
}
