class PostModel {
  final String id;
  final String societyId;
  final String authorId;
  final String title;
  final String content;
  final List<String> mediaUrls;
  final bool isPinned;
  final bool isPublic;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String societyName;
  final String? societyLogo;
  final String authorName;
  final int likesCount;
  final int commentsCount;
  final bool isLiked;
  final bool canManage;

  const PostModel({
    required this.id,
    required this.societyId,
    required this.authorId,
    required this.title,
    required this.content,
    this.mediaUrls = const [],
    this.isPinned = false,
    this.isPublic = true,
    required this.createdAt,
    required this.updatedAt,
    this.societyName = 'UET Society',
    this.societyLogo,
    this.authorName = 'Society Executive',
    this.likesCount = 0,
    this.commentsCount = 0,
    this.isLiked = false,
    this.canManage = false,
  });

  factory PostModel.fromJson(
    Map<String, dynamic> json, {
    String? currentUserId,
    bool isSocietyAdmin = false,
  }) {
    final society = json['societies'] as Map<String, dynamic>? ?? {};
    final author = json['profiles'] as Map<String, dynamic>? ?? {};
    final likesList = (json['post_likes'] as List<dynamic>?) ?? [];
    final commentsList = (json['post_comments'] as List<dynamic>?) ?? [];

    final rawMedia = json['media_urls'];
    List<String> parsedMedia = [];
    if (rawMedia is List) {
      parsedMedia = rawMedia.map((e) => e.toString()).toList();
    }

    final isLiked = currentUserId != null &&
        likesList.any((l) => l['user_id'] == currentUserId);

    final canManage = isSocietyAdmin ||
        (currentUserId != null && currentUserId == json['author_id']);

    return PostModel(
      id: json['id'] as String,
      societyId: json['society_id'] as String,
      authorId: json['author_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      mediaUrls: parsedMedia,
      isPinned: json['is_pinned'] == true,
      isPublic: json['is_public'] != false,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ?? DateTime.now(),
      societyName: society['name'] as String? ?? 'UET Society',
      societyLogo: society['logo_url'] as String?,
      authorName: author['full_name'] as String? ?? 'Executive',
      likesCount: likesList.length,
      commentsCount: commentsList.length,
      isLiked: isLiked,
      canManage: canManage,
    );
  }

  PostModel copyWith({
    String? title,
    String? content,
    List<String>? mediaUrls,
    bool? isPinned,
    bool? isPublic,
    int? likesCount,
    int? commentsCount,
    bool? isLiked,
    bool? canManage,
  }) {
    return PostModel(
      id: id,
      societyId: societyId,
      authorId: authorId,
      title: title ?? this.title,
      content: content ?? this.content,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      isPinned: isPinned ?? this.isPinned,
      isPublic: isPublic ?? this.isPublic,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      societyName: societyName,
      societyLogo: societyLogo,
      authorName: authorName,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      isLiked: isLiked ?? this.isLiked,
      canManage: canManage ?? this.canManage,
    );
  }
}
