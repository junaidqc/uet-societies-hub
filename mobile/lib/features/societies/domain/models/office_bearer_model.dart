class OfficeBearerModel {
  final String id;
  final String societyId;
  final String userId;
  final String role;
  final String fullName;
  final String rollNumber;
  final String department;
  final String? avatarUrl;

  const OfficeBearerModel({
    required this.id,
    required this.societyId,
    required this.userId,
    required this.role,
    required this.fullName,
    required this.rollNumber,
    required this.department,
    this.avatarUrl,
  });

  factory OfficeBearerModel.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>? ?? {};

    return OfficeBearerModel(
      id: json['id'] as String,
      societyId: json['society_id'] as String,
      userId: json['user_id'] as String,
      role: json['role'] as String? ?? 'admin',
      fullName: profile['full_name'] as String? ?? 'Executive Member',
      rollNumber: profile['roll_number'] as String? ?? 'UET Student',
      department: profile['department'] as String? ?? 'Engineering',
      avatarUrl: profile['avatar_url'] as String?,
    );
  }

  bool get isPresident => role == 'president';
  bool get isAdmin => role == 'admin';
  bool get isModerator => role == 'moderator';

  String get roleDisplay {
    switch (role) {
      case 'president':
        return 'President';
      case 'admin':
        return 'Executive Admin';
      case 'moderator':
        return 'Moderator';
      default:
        return 'Council Member';
    }
  }
}
