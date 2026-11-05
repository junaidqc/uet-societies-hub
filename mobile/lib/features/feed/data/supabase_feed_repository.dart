import 'dart:math';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/app_logger.dart';
import '../domain/models/post_model.dart';
import '../domain/models/comment_model.dart';
import '../domain/models/event_model.dart';
import '../domain/repositories/feed_repository.dart';

class SupabaseFeedRepository implements FeedRepository {
  final SupabaseClient _client;

  SupabaseFeedRepository(this._client);

  @override
  Future<List<PostModel>> getFollowedFeed() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        return getPublicFeed();
      }

      // 1. Get followed society IDs
      final follows = await _client
          .from('follows')
          .select('society_id')
          .eq('user_id', user.id);

      final followedIds = (follows as List<dynamic>)
          .map((f) => f['society_id'] as String)
          .toList();

      if (followedIds.isEmpty) {
        // Fallback to general feed if user hasn't followed any society yet
        return getPublicFeed();
      }

      // 2. Fetch posts from followed societies (Newest first, pinned on top)
      final response = await _client
          .from('posts')
          .select('*, societies(name, logo_url), profiles(full_name), post_likes(user_id), post_comments(id)')
          .inFilter('society_id', followedIds)
          .order('is_pinned', ascending: false)
          .order('created_at', ascending: false);

      return (response as List<dynamic>)
          .map((row) => PostModel.fromJson(row as Map<String, dynamic>, currentUserId: user.id))
          .toList();
    } catch (e) {
      AppLogger.error('Failed to get followed feed', e);
      throw ServerFailure('Could not load feed: ${e.toString()}');
    }
  }

  @override
  Future<List<PostModel>> getPublicFeed() async {
    try {
      AppLogger.info('Fetching public feed (Newest first)');
      final user = _client.auth.currentUser;

      final response = await _client
          .from('posts')
          .select('*, societies(name, logo_url), profiles(full_name), post_likes(user_id), post_comments(id)')
          .order('is_pinned', ascending: false)
          .order('created_at', ascending: false);

      return (response as List<dynamic>)
          .map((row) => PostModel.fromJson(row as Map<String, dynamic>, currentUserId: user?.id))
          .toList();
    } catch (e) {
      AppLogger.error('Failed to get public feed', e);
      throw ServerFailure('Could not load posts: ${e.toString()}');
    }
  }

  @override
  Future<List<EventModel>> getEvents() async {
    try {
      AppLogger.info('Fetching upcoming events');
      final user = _client.auth.currentUser;

      final response = await _client
          .from('events')
          .select('*, societies(name, logo_url), event_interests(user_id)')
          .order('start_time', ascending: true);

      return (response as List<dynamic>)
          .map((row) => EventModel.fromJson(row as Map<String, dynamic>, currentUserId: user?.id))
          .toList();
    } catch (e) {
      AppLogger.error('Failed to load events', e);
      throw ServerFailure('Could not load events: ${e.toString()}');
    }
  }

  @override
  Future<PostModel> createPost({
    required String societyId,
    required String title,
    required String content,
    List<String> mediaUrls = const [],
    bool isPublic = true,
    bool isPinned = false,
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw const AuthFailure('Login required to publish posts.');
      }

      AppLogger.info('Publishing post for society: $societyId');
      final response = await _client
          .from('posts')
          .insert({
            'society_id': societyId,
            'author_id': user.id,
            'title': title.trim(),
            'content': content.trim(),
            'media_urls': mediaUrls,
            'is_public': isPublic,
            'is_pinned': isPinned,
          })
          .select('*, societies(name, logo_url), profiles(full_name), post_likes(user_id), post_comments(id)')
          .single();

      return PostModel.fromJson(response, currentUserId: user.id);
    } catch (e) {
      AppLogger.error('Error creating post', e);
      throw ServerFailure('Could not create post: ${e.toString()}');
    }
  }

  @override
  Future<void> updatePost(PostModel post) async {
    try {
      AppLogger.info('Updating post: ${post.id}');
      await _client.from('posts').update({
        'title': post.title.trim(),
        'content': post.content.trim(),
        'media_urls': post.mediaUrls,
        'is_public': post.isPublic,
        'is_pinned': post.isPinned,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', post.id);
    } catch (e) {
      AppLogger.error('Error updating post', e);
      throw ServerFailure('Could not update post: ${e.toString()}');
    }
  }

  @override
  Future<void> deletePost(String postId) async {
    try {
      AppLogger.info('Deleting post: $postId');
      await _client.from('posts').delete().eq('id', postId);
    } catch (e) {
      AppLogger.error('Error deleting post', e);
      throw ServerFailure('Could not delete post: ${e.toString()}');
    }
  }

  @override
  Future<void> togglePinPost(String postId, bool currentPinned) async {
    try {
      AppLogger.info('Toggling pin for post: $postId');
      await _client
          .from('posts')
          .update({'is_pinned': !currentPinned})
          .eq('id', postId);
    } catch (e) {
      AppLogger.error('Error toggling pin', e);
      throw ServerFailure('Could not update pin state.');
    }
  }

  @override
  Future<void> toggleLikePost(String postId, bool currentlyLiked) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw const AuthFailure('Login required to like posts.');
      }

      if (currentlyLiked) {
        await _client
            .from('post_likes')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', user.id);
      } else {
        await _client.from('post_likes').insert({
          'post_id': postId,
          'user_id': user.id,
        });
      }
    } catch (e) {
      AppLogger.error('Error toggling post like', e);
      throw ServerFailure('Could not update like state.');
    }
  }

  @override
  Future<List<CommentModel>> getComments(String postId) async {
    try {
      AppLogger.info('Fetching comments for post: $postId');
      final response = await _client
          .from('post_comments')
          .select('*, profiles(full_name, roll_number, avatar_url)')
          .eq('post_id', postId)
          .order('created_at', ascending: true);

      return (response as List<dynamic>)
          .map((row) => CommentModel.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.error('Error fetching comments', e);
      throw ServerFailure('Could not load comments.');
    }
  }

  @override
  Future<CommentModel> addComment(String postId, String content) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw const AuthFailure('Login required to post comments.');
      }

      AppLogger.info('Adding comment to post: $postId');
      final response = await _client
          .from('post_comments')
          .insert({
            'post_id': postId,
            'user_id': user.id,
            'content': content.trim(),
          })
          .select('*, profiles(full_name, roll_number, avatar_url)')
          .single();

      return CommentModel.fromJson(response);
    } catch (e) {
      AppLogger.error('Error adding comment', e);
      throw ServerFailure('Could not submit comment: ${e.toString()}');
    }
  }

  @override
  Future<void> toggleEventInterest(String eventId, bool currentlyInterested) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw const AuthFailure('Login required to express interest in events.');
      }

      if (currentlyInterested) {
        await _client
            .from('event_interests')
            .delete()
            .eq('event_id', eventId)
            .eq('user_id', user.id);
      } else {
        await _client.from('event_interests').insert({
          'event_id': eventId,
          'user_id': user.id,
          'status': 'going',
        });
      }
    } catch (e) {
      AppLogger.error('Error toggling event interest', e);
      throw ServerFailure('Could not update event interest.');
    }
  }

  @override
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
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw const AuthFailure('Login required to create events.');
      }

      AppLogger.info('Creating event for society: $societyId');
      final response = await _client
          .from('events')
          .insert({
            'society_id': societyId,
            'title': title.trim(),
            'description': description.trim(),
            'venue': venue.trim(),
            'start_time': startTime.toUtc().toIso8601String(),
            'end_time': endTime.toUtc().toIso8601String(),
            'banner_url': bannerUrl,
            'registration_link': registrationLink?.trim(),
            'is_public': isPublic,
          })
          .select('*, societies(name, logo_url), event_interests(user_id)')
          .single();

      return EventModel.fromJson(response, currentUserId: user.id);
    } catch (e) {
      AppLogger.error('Error creating event', e);
      throw ServerFailure('Could not create event: ${e.toString()}');
    }
  }

  @override
  Future<String> uploadPostMedia({
    required List<int> fileBytes,
    required String fileName,
    required String mimeType,
    required String societyId,
  }) async {
    try {
      // 1. Enforce 5 MB cap
      const maxBytes = 5 * 1024 * 1024;
      if (fileBytes.length > maxBytes) {
        throw const ValidationFailure('Media exceeds the 5 MB limit.');
      }

      // 2. MIME allowlist
      final allowed = ['image/jpeg', 'image/png', 'image/webp'];
      if (!allowed.contains(mimeType.toLowerCase())) {
        throw const ValidationFailure('Only JPEG, PNG, or WebP images are allowed.');
      }

      // 3. Randomized path
      final user = _client.auth.currentUser;
      final userId = user?.id ?? 'guest';
      final ext = fileName.split('.').last.toLowerCase();
      final randomToken = Random().nextInt(9999999).toString().padLeft(7, '0');
      final path = '$societyId/${DateTime.now().millisecondsSinceEpoch}_$randomToken.$ext';

      await _client.storage.from('post-media').uploadBinary(
            path,
            Uint8List.fromList(fileBytes),
            fileOptions: FileOptions(
              contentType: mimeType,
              upsert: true,
            ),
          );

      return _client.storage.from('post-media').getPublicUrl(path);
    } on Failure {
      rethrow;
    } catch (e) {
      AppLogger.error('Error uploading post media', e);
      throw ServerFailure('Media upload failed: ${e.toString()}');
    }
  }
}
