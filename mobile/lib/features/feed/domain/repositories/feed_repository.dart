import '../models/post_model.dart';
import '../models/comment_model.dart';
import '../models/event_model.dart';

abstract class FeedRepository {
  Future<List<PostModel>> getFollowedFeed();
  Future<List<PostModel>> getPublicFeed();
  Future<List<EventModel>> getEvents();

  Future<PostModel> createPost({
    required String societyId,
    required String title,
    required String content,
    List<String> mediaUrls = const [],
    bool isPublic = true,
    bool isPinned = false,
  });

  Future<void> updatePost(PostModel post);
  Future<void> deletePost(String postId);
  Future<void> togglePinPost(String postId, bool currentPinned);

  Future<void> toggleLikePost(String postId, bool currentlyLiked);

  Future<List<CommentModel>> getComments(String postId);
  Future<CommentModel> addComment(String postId, String content);

  Future<void> toggleEventInterest(String eventId, bool currentlyInterested);

  Future<EventModel> createEvent({
    required String societyId,
    required String title,
    required String description,
    required String venue,
    required DateTime startTime,
    required DateTime endTime,
    String? bannerUrl,
    String? registrationLink,
    bool isPublic = true,
  });

  Future<String> uploadPostMedia({
    required List<int> fileBytes,
    required String fileName,
    required String mimeType,
    required String societyId,
  });
}
