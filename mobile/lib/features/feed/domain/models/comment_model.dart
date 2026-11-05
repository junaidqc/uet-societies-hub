class CommentModel {
  final String id;
  final String postId;
  final String userId;
  final String content;
  final DateTime createdAt;
  final String authorName;
  final String authorRoll;
  final String? authorAvatar;

  const CommentModel({
    required this.id,
    required this.postId,
    required this.userId,
    required this.content,
    required this.createdAt,
    required this.authorName,
    required this.authorRoll,
    this.authorAvatar,
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>? ?? {};

    return CommentModel(
      id: json['id'] as String,
      postId: json['post_id'] as String,
      userId: json['user_id'] as String,
      content: json['content'] as String? ?? '',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      authorName: profile['full_name'] as String? ?? 'UET Student',
      authorRoll: profile['roll_number'] as String? ?? '',
      authorAvatar: profile['avatar_url'] as String?,
    );
  }
}
