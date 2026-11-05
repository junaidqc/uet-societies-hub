class ApplicationModel {
  final String id;
  final String hiringId;
  final String userId;
  final String position;
  final String status;
  final Map<String, dynamic> answers;
  final String? resumeUrl;
  final String? feedback;
  final DateTime createdAt;
  final String applicantName;
  final String applicantRoll;
  final String applicantDept;
  final int applicantSemester;
  final String applicantEmail;
  final String? applicantAvatar;

  const ApplicationModel({
    required this.id,
    required this.hiringId,
    required this.userId,
    required this.position,
    required this.status,
    this.answers = const {},
    this.resumeUrl,
    this.feedback,
    required this.createdAt,
    this.applicantName = 'UET Student',
    this.applicantRoll = '',
    this.applicantDept = 'Engineering',
    this.applicantSemester = 1,
    this.applicantEmail = '',
    this.applicantAvatar,
  });

  factory ApplicationModel.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>? ?? {};

    return ApplicationModel(
      id: json['id'] as String,
      hiringId: json['hiring_id'] as String,
      userId: json['user_id'] as String,
      position: json['position'] as String? ?? 'Executive',
      status: json['status'] as String? ?? 'submitted',
      answers: (json['answers'] as Map<String, dynamic>?) ?? {},
      resumeUrl: json['resume_url'] as String?,
      feedback: json['feedback'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      applicantName: profile['full_name'] as String? ?? 'UET Student',
      applicantRoll: profile['roll_number'] as String? ?? '',
      applicantDept: profile['department'] as String? ?? 'Engineering',
      applicantSemester: (profile['semester'] as num?)?.toInt() ?? 1,
      applicantEmail: profile['email'] as String? ?? '',
      applicantAvatar: profile['avatar_url'] as String?,
    );
  }

  bool get isSelected => status == 'accepted';
  bool get isRejected => status == 'rejected';
  bool get isShortlisted => status == 'shortlisted';
  bool get isUnderReview => status == 'under_review';
  bool get isSubmitted => status == 'submitted';

  String get statusDisplay {
    switch (status) {
      case 'submitted':
        return 'Submitted';
      case 'under_review':
        return 'Under Review';
      case 'shortlisted':
        return 'Shortlisted';
      case 'accepted':
        return 'Selected';
      case 'rejected':
        return 'Rejected';
      default:
        return status;
    }
  }

  ApplicationModel copyWith({
    String? status,
    String? feedback,
  }) {
    return ApplicationModel(
      id: id,
      hiringId: hiringId,
      userId: userId,
      position: position,
      status: status ?? this.status,
      answers: answers,
      resumeUrl: resumeUrl,
      feedback: feedback ?? this.feedback,
      createdAt: createdAt,
      applicantName: applicantName,
      applicantRoll: applicantRoll,
      applicantDept: applicantDept,
      applicantSemester: applicantSemester,
      applicantEmail: applicantEmail,
      applicantAvatar: applicantAvatar,
    );
  }
}
