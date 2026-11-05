class HiringModel {
  final String id;
  final String societyId;
  final String societyName;
  final String? societyLogo;
  final String title;
  final String description;
  final List<String> positions;
  final DateTime deadline;
  final String status;
  final String? requirements;
  final String selectionMethod;
  final int totalSeats;
  final List<Map<String, dynamic>> customQuestions;
  final bool isSaved;
  final bool hasApplied;
  final DateTime createdAt;

  const HiringModel({
    required this.id,
    required this.societyId,
    this.societyName = 'UET Society',
    this.societyLogo,
    required this.title,
    required this.description,
    this.positions = const [],
    required this.deadline,
    this.status = 'open',
    this.requirements,
    this.selectionMethod = 'Interview',
    this.totalSeats = 5,
    this.customQuestions = const [],
    this.isSaved = false,
    this.hasApplied = false,
    required this.createdAt,
  });

  factory HiringModel.fromJson(Map<String, dynamic> json, {String? currentUserId}) {
    final society = json['societies'] as Map<String, dynamic>? ?? {};
    final savedList = (json['saved_hirings'] as List<dynamic>?) ?? [];
    final appsList = (json['applications'] as List<dynamic>?) ?? [];

    List<String> posList = [];
    final rawPositions = json['positions'];
    if (rawPositions is List) {
      posList = rawPositions.map((e) => e.toString()).toList();
    }

    List<Map<String, dynamic>> questions = [];
    final rawQ = json['custom_questions'];
    if (rawQ is List) {
      questions = rawQ.map((e) => e as Map<String, dynamic>).toList();
    }

    final isSaved = currentUserId != null &&
        savedList.any((s) => s['user_id'] == currentUserId);

    final hasApplied = currentUserId != null &&
        appsList.any((a) => a['user_id'] == currentUserId);

    return HiringModel(
      id: json['id'] as String,
      societyId: json['society_id'] as String,
      societyName: society['name'] as String? ?? 'UET Society',
      societyLogo: society['logo_url'] as String?,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      positions: posList,
      deadline: DateTime.tryParse(json['deadline'] as String? ?? '') ?? DateTime.now(),
      status: json['status'] as String? ?? 'open',
      requirements: json['requirements'] as String?,
      selectionMethod: json['selection_method'] as String? ?? 'Interview',
      totalSeats: (json['total_seats'] as num?)?.toInt() ?? 5,
      customQuestions: questions,
      isSaved: isSaved,
      hasApplied: hasApplied,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  bool get isOpen => status == 'open' && !isExpired;
  bool get isExpired => deadline.isBefore(DateTime.now());

  int get daysLeft => deadline.difference(DateTime.now()).inDays;
  int get hoursLeft => deadline.difference(DateTime.now()).inHours;

  String get daysLeftText {
    if (status == 'closed' || isExpired) {
      return 'Closed';
    }
    final d = daysLeft;
    if (d <= 0) {
      final h = hoursLeft;
      if (h <= 0) return 'Closing soon';
      return '$h hour${h == 1 ? '' : 's'} left';
    }
    if (d == 1) return '1 day left';
    return '$d days left';
  }

  HiringModel copyWith({
    bool? isSaved,
    bool? hasApplied,
    String? status,
  }) {
    return HiringModel(
      id: id,
      societyId: societyId,
      societyName: societyName,
      societyLogo: societyLogo,
      title: title,
      description: description,
      positions: positions,
      deadline: deadline,
      status: status ?? this.status,
      requirements: requirements,
      selectionMethod: selectionMethod,
      totalSeats: totalSeats,
      customQuestions: customQuestions,
      isSaved: isSaved ?? this.isSaved,
      hasApplied: hasApplied ?? this.hasApplied,
      createdAt: createdAt,
    );
  }
}
