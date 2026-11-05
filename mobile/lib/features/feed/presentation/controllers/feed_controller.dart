import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/supabase_config.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../domain/models/post_model.dart';
import '../../domain/models/comment_model.dart';
import '../../domain/models/event_model.dart';
import '../../domain/repositories/feed_repository.dart';
import '../../data/supabase_feed_repository.dart';

final feedRepositoryProvider = Provider<FeedRepository>((ref) {
  return SupabaseFeedRepository(SupabaseConfig.client);
});

// 0: Following Feed, 1: Explore All Feed
final feedTabFilterProvider = StateProvider<int>((ref) => 0);

final followedFeedProvider = FutureProvider.autoDispose<List<PostModel>>((ref) async {
  final repo = ref.watch(feedRepositoryProvider);
  return repo.getFollowedFeed();
});

final publicFeedProvider = FutureProvider.autoDispose<List<PostModel>>((ref) async {
  final repo = ref.watch(feedRepositoryProvider);
  return repo.getPublicFeed();
});

final eventsListProvider = FutureProvider.autoDispose<List<EventModel>>((ref) async {
  final repo = ref.watch(feedRepositoryProvider);
  return repo.getEvents();
});

final postCommentsProvider = FutureProvider.family.autoDispose<List<CommentModel>, String>((ref, postId) async {
  final repo = ref.watch(feedRepositoryProvider);
  return repo.getComments(postId);
});

// Fetches the societies that the current logged-in user can post / create events for
final userAdminSocietiesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null || user.isGuest) return [];

  final client = SupabaseConfig.client;

  if (user.isSystemAdmin) {
    final all = await client.from('societies').select('id, name, logo_url').eq('status', 'active');
    return (all as List<dynamic>).map((e) => e as Map<String, dynamic>).toList();
  }

  final response = await client
      .from('society_admins')
      .select('society_id, role, societies(id, name, logo_url)')
      .eq('user_id', user.id);

  return (response as List<dynamic>).map((row) {
    final s = row['societies'] as Map<String, dynamic>? ?? {};
    return {
      'id': s['id'] ?? row['society_id'],
      'name': s['name'] ?? 'Society',
      'logo_url': s['logo_url'],
      'role': row['role'],
    };
  }).toList();
});

class FeedActionState {
  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;

  const FeedActionState({
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
  });

  FeedActionState copyWith({
    bool? isLoading,
    String? errorMessage,
    String? successMessage,
  }) {
    return FeedActionState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      successMessage: successMessage,
    );
  }
}

class FeedActionController extends StateNotifier<FeedActionState> {
  final FeedRepository _repo;
  final Ref _ref;

  FeedActionController(this._repo, this._ref) : super(const FeedActionState());

  Future<bool> toggleLike(String postId, bool currentlyLiked) async {
    try {
      await _repo.toggleLikePost(postId, currentlyLiked);
      _ref.invalidate(followedFeedProvider);
      _ref.invalidate(publicFeedProvider);
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> addComment(String postId, String content) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repo.addComment(postId, content);
      state = state.copyWith(isLoading: false);
      _ref.invalidate(postCommentsProvider(postId));
      _ref.invalidate(followedFeedProvider);
      _ref.invalidate(publicFeedProvider);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> togglePin(String postId, bool currentPinned) async {
    try {
      await _repo.togglePinPost(postId, currentPinned);
      _ref.invalidate(followedFeedProvider);
      _ref.invalidate(publicFeedProvider);
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> deletePost(String postId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repo.deletePost(postId);
      state = state.copyWith(isLoading: false, successMessage: 'Post deleted.');
      _ref.invalidate(followedFeedProvider);
      _ref.invalidate(publicFeedProvider);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> toggleEventInterest(String eventId, bool currentlyInterested) async {
    try {
      await _repo.toggleEventInterest(eventId, currentlyInterested);
      _ref.invalidate(eventsListProvider);
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> createPost({
    required String societyId,
    required String title,
    required String content,
    List<String> mediaUrls = const [],
    bool isPublic = true,
    bool isPinned = false,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repo.createPost(
        societyId: societyId,
        title: title,
        content: content,
        mediaUrls: mediaUrls,
        isPublic: isPublic,
        isPinned: isPinned,
      );
      state = state.copyWith(isLoading: false, successMessage: 'Post published successfully!');
      _ref.invalidate(followedFeedProvider);
      _ref.invalidate(publicFeedProvider);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> updatePost(PostModel post) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repo.updatePost(post);
      state = state.copyWith(isLoading: false, successMessage: 'Post updated successfully!');
      _ref.invalidate(followedFeedProvider);
      _ref.invalidate(publicFeedProvider);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> createEvent({
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
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repo.createEvent(
        societyId: societyId,
        title: title,
        description: description,
        venue: venue,
        startTime: startTime,
        endTime: endTime,
        bannerUrl: bannerUrl,
        registrationLink: registrationLink,
        isPublic: isPublic,
      );
      state = state.copyWith(isLoading: false, successMessage: 'Event created successfully!');
      _ref.invalidate(eventsListProvider);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }
}

final feedActionControllerProvider = StateNotifierProvider<FeedActionController, FeedActionState>((ref) {
  final repo = ref.watch(feedRepositoryProvider);
  return FeedActionController(repo, ref);
});
