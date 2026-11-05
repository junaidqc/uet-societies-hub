class StudentProfile {
  final String id;
  final String email;
  final String fullName;
  final String rollNumber;
  final String department;
  final int semester;
  final String? avatarUrl;
  final String? bio;
  final String? phoneNumber;
  final bool isSystemAdmin;
  final DateTime createdAt;
  final DateTime updatedAt;

  const StudentProfile({
    required this.id,
    required this.email,
    required this.fullName,
    required this.rollNumber,
    required this.department,
    required this.semester,
    this.avatarUrl,
    this.bio,
    this.phoneNumber,
    this.isSystemAdmin = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StudentProfile.fromJson(Map<String, dynamic> json) {
    return StudentProfile(
      id: json['id'] as String,
      email: json['email'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      rollNumber: json['roll_number'] as String? ?? '',
      department: json['department'] as String? ?? '',
      semester: (json['semester'] as num?)?.toInt() ?? 1,
      avatarUrl: json['avatar_url'] as String?,
      bio: json['bio'] as String?,
      phoneNumber: json['phone_number'] as String?,
      isSystemAdmin: json['is_system_admin'] == true,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'full_name': fullName,
      'roll_number': rollNumber,
      'department': department,
      'semester': semester,
      'avatar_url': avatarUrl,
      'bio': bio,
      'phone_number': phoneNumber,
    };
  }

  StudentProfile copyWith({
    String? fullName,
    String? rollNumber,
    String? department,
    int? semester,
    String? avatarUrl,
    String? bio,
    String? phoneNumber,
  }) {
    return StudentProfile(
      id: id,
      email: email,
      fullName: fullName ?? this.fullName,
      rollNumber: rollNumber ?? this.rollNumber,
      department: department ?? this.department,
      semester: semester ?? this.semester,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      isSystemAdmin: isSystemAdmin,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
