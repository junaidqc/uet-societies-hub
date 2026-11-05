class EventModel {
  final String id;
  final String societyId;
  final String title;
  final String description;
  final String venue;
  final DateTime startTime;
  final DateTime endTime;
  final String? bannerUrl;
  final String? registrationLink;
  final bool isPublic;
  final String societyName;
  final String? societyLogo;
  final int interestedCount;
  final bool isInterested;

  const EventModel({
    required this.id,
    required this.societyId,
    required this.title,
    required this.description,
    required this.venue,
    required this.startTime,
    required this.endTime,
    this.bannerUrl,
    this.registrationLink,
    this.isPublic = true,
    this.societyName = 'UET Society',
    this.societyLogo,
    this.interestedCount = 0,
    this.isInterested = false,
  });

  factory EventModel.fromJson(Map<String, dynamic> json, {String? currentUserId}) {
    final society = json['societies'] as Map<String, dynamic>? ?? {};
    final interests = (json['event_interests'] as List<dynamic>?) ?? [];

    final isInterested = currentUserId != null &&
        interests.any((i) => i['user_id'] == currentUserId);

    return EventModel(
      id: json['id'] as String,
      societyId: json['society_id'] as String,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      venue: json['venue'] as String? ?? 'UET Lahore',
      startTime: DateTime.tryParse(json['start_time'] as String? ?? '') ?? DateTime.now(),
      endTime: DateTime.tryParse(json['end_time'] as String? ?? '') ?? DateTime.now(),
      bannerUrl: json['banner_url'] as String?,
      registrationLink: json['registration_link'] as String?,
      isPublic: json['is_public'] != false,
      societyName: society['name'] as String? ?? 'UET Society',
      societyLogo: society['logo_url'] as String?,
      interestedCount: interests.length,
      isInterested: isInterested,
    );
  }

  EventModel copyWith({
    String? title,
    String? description,
    String? venue,
    DateTime? startTime,
    DateTime? endTime,
    String? bannerUrl,
    String? registrationLink,
    bool? isPublic,
    int? interestedCount,
    bool? isInterested,
  }) {
    return EventModel(
      id: id,
      societyId: societyId,
      title: title ?? this.title,
      description: description ?? this.description,
      venue: venue ?? this.venue,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      registrationLink: registrationLink ?? this.registrationLink,
      isPublic: isPublic ?? this.isPublic,
      societyName: societyName,
      societyLogo: societyLogo,
      interestedCount: interestedCount ?? this.interestedCount,
      isInterested: isInterested ?? this.isInterested,
    );
  }
}
