import 'dart:async';
import 'dart:typed_data';
import 'local_data_store.dart';
import '../../features/auth/domain/models/user_model.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/profile/domain/models/profile_model.dart';
import '../../features/profile/domain/repositories/profile_repository.dart';
import '../../features/societies/domain/models/society_model.dart';
import '../../features/societies/domain/models/office_bearer_model.dart';
import '../../features/societies/domain/repositories/society_repository.dart';
import '../../features/feed/domain/models/post_model.dart';
import '../../features/feed/domain/models/comment_model.dart';
import '../../features/feed/domain/models/event_model.dart';
import '../../features/feed/domain/repositories/feed_repository.dart';
import '../../features/hiring/domain/models/hiring_model.dart';
import '../../features/hiring/domain/models/application_model.dart';
import '../../features/hiring/domain/repositories/hiring_repository.dart';
import '../../features/groups/domain/models/group_model.dart';
import '../../features/groups/domain/models/group_message_model.dart';
import '../../features/groups/domain/models/poll_and_task_models.dart';
import '../../features/groups/domain/repositories/group_repository.dart';

// =============================================================================
// Local Auth Repository
// =============================================================================
class LocalAuthRepository implements AuthRepository {
  final _store = LocalDataStore();

  @override
  Stream<AppUser?> get authStateChanges => _store.authStateChanges;

  @override
  AppUser? get currentUser => _store.currentUser;

  @override
  bool get isGuest => _store.isGuest;

  @override
  Future<void> signIn({required String email, required String password}) async {
    await _store.signIn(email: email, password: password);
  }

  @override
  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
    required String rollNumber,
    required String department,
    required int semester,
  }) async {
    await _store.signUp(
      email: email,
      password: password,
      fullName: fullName,
      rollNumber: rollNumber,
      department: department,
      semester: semester,
    );
  }

  @override
  Future<void> verifyEmailOtp({required String email, required String token}) async {
    // In local autonomous mode, any entered code verifies instantly!
    await Future.delayed(const Duration(milliseconds: 300));
  }

  @override
  Future<void> resendSignUpOtp({required String email}) async {
    await Future.delayed(const Duration(milliseconds: 300));
  }

  @override
  Future<void> sendPasswordResetOtp({required String email}) async {
    await Future.delayed(const Duration(milliseconds: 300));
  }

  @override
  Future<void> resetPasswordWithOtp({
    required String email,
    required String token,
    required String newPassword,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
  }

  @override
  Future<void> continueAsGuest() async {
    await _store.continueAsGuest();
  }

  @override
  Future<void> signOut() async {
    await _store.signOut();
  }
}

// =============================================================================
// Local Society Repository
// =============================================================================
class LocalSocietyRepository implements SocietyRepository {
  final _store = LocalDataStore();

  @override
  Future<List<SocietyModel>> getSocieties({String? category, String? search}) async {
    return _store.getSocieties(category: category, search: search);
  }

  @override
  Future<SocietyModel?> getSocietyById(String id) async {
    return _store.getSocietyById(id);
  }

  @override
  Future<List<OfficeBearerModel>> getOfficeBearers(String societyId) async {
    return _store.getOfficeBearers(societyId);
  }

  @override
  Future<String?> getUserSocietyRole(String societyId, String userId) async {
    return _store.getUserSocietyRole(societyId, userId);
  }

  @override
  Future<void> followSociety(String societyId) async {
    _store.toggleFollow(societyId);
  }

  @override
  Future<void> unfollowSociety(String societyId) async {
    _store.toggleFollow(societyId);
  }

  @override
  Future<SocietyModel> submitRegistrationRequest({
    required String name,
    required String category,
    required String description,
    String? email,
    String? website,
    Map<String, dynamic>? socialLinks,
    String? logoUrl,
  }) async {
    return _store.submitRegistrationRequest(
      name: name,
      category: category,
      description: description,
      email: email,
      website: website,
      logoUrl: logoUrl,
    );
  }

  @override
  Future<List<SocietyModel>> getPendingRequests() async {
    return _store.getPendingRequests();
  }

  @override
  Future<void> approveSociety(String societyId) async {}

  @override
  Future<void> rejectSociety(String societyId, String reason) async {}

  @override
  Future<void> updateSociety(SocietyModel society) async {}

  @override
  Future<void> grantAdminRole({
    required String societyId,
    required String targetRollNumber,
    required String role,
  }) async {}

  @override
  Future<void> revokeAdminRole({
    required String societyId,
    required String targetUserId,
  }) async {}

  @override
  Future<String> uploadLogo({
    required List<int> fileBytes,
    required String fileName,
    required String mimeType,
  }) async {
    return 'https://images.unsplash.com/photo-1517694712202-14dd9538aa97?w=150';
  }
}

// =============================================================================
// Local Feed Repository
// =============================================================================
class LocalFeedRepository implements FeedRepository {
  final _store = LocalDataStore();

  @override
  Future<List<PostModel>> getFollowedFeed() async {
    return _store.getPosts(onlyFollowed: true);
  }

  @override
  Future<List<PostModel>> getPublicFeed() async {
    return _store.getPosts(onlyFollowed: false);
  }

  @override
  Future<List<EventModel>> getEvents() async {
    return _store.getEvents();
  }

  @override
  Future<void> toggleLikePost(String postId, bool currentlyLiked) async {
    _store.toggleLikePost(postId);
  }

  @override
  Future<List<CommentModel>> getComments(String postId) async {
    return _store.getComments(postId);
  }

  @override
  Future<CommentModel> addComment(String postId, String content) async {
    return _store.addComment(postId, content);
  }

  @override
  Future<void> toggleEventInterest(String eventId, bool currentlyInterested) async {
    _store.toggleEventInterest(eventId);
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
    return _store.createPost(
      societyId: societyId,
      title: title,
      content: content,
      mediaUrls: mediaUrls,
      isPublic: isPublic,
      isPinned: isPinned,
    );
  }

  @override
  Future<void> updatePost(PostModel post) async {}

  @override
  Future<void> deletePost(String postId) async {}

  @override
  Future<void> togglePinPost(String postId, bool currentPinned) async {}

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
    final ev = EventModel(
      id: 'event-${DateTime.now().millisecondsSinceEpoch}',
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
    _store.getEvents().add(ev);
    return ev;
  }

  @override
  Future<String> uploadPostMedia({
    required List<int> fileBytes,
    required String fileName,
    required String mimeType,
    required String societyId,
  }) async {
    return 'https://images.unsplash.com/photo-1517694712202-14dd9538aa97?w=150';
  }
}

// =============================================================================
// Local Hiring Repository
// =============================================================================
class LocalHiringRepository implements HiringRepository {
  final _store = LocalDataStore();

  @override
  Future<List<HiringModel>> getHirings({String? societyId, bool onlySaved = false}) async {
    return _store.getHirings(societyId: societyId, onlySaved: onlySaved);
  }

  @override
  Future<HiringModel?> getHiringById(String hiringId) async {
    try {
      return _store.getHirings().firstWhere((h) => h.id == hiringId);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> toggleSaveHiring(String hiringId, bool currentlySaved) async {
    _store.toggleSaveHiring(hiringId);
  }

  @override
  Future<ApplicationModel> applyToHiring({
    required String hiringId,
    required String position,
    required Map<String, dynamic> answers,
    String? resumeUrl,
  }) async {
    return _store.applyToHiring(
      hiringId: hiringId,
      position: position,
      answers: answers,
    );
  }

  @override
  Future<bool> checkHasApplied(String hiringId, String position) async {
    final apps = _store.getApplications(hiringId);
    return apps.any((a) => a.position == position && a.userId == (_store.currentUser?.id ?? ''));
  }

  @override
  Future<List<ApplicationModel>> getApplications(String hiringId, {String? status, String? position}) async {
    return _store.getApplications(hiringId, status: status, position: position);
  }

  @override
  Future<HiringModel> createHiring({
    required String societyId,
    required String title,
    required String description,
    required List<String> positions,
    required DateTime deadline,
    required String requirements,
    required String selectionMethod,
    required int totalSeats,
    required List<Map<String, dynamic>> customQuestions,
  }) async {
    final soc = _store.getSocietyById(societyId);
    final now = DateTime.now();
    final h = HiringModel(
      id: 'hiring-${now.millisecondsSinceEpoch}',
      societyId: societyId,
      societyName: soc?.name ?? 'UET Society',
      title: title,
      description: description,
      positions: positions,
      deadline: deadline,
      requirements: requirements,
      selectionMethod: selectionMethod,
      totalSeats: totalSeats,
      customQuestions: customQuestions,
      createdAt: now,
    );
    _store.getHirings().add(h);
    return h;
  }

  @override
  Future<void> updateApplicationStatus({
    required String applicationId,
    required String status,
    String? feedback,
  }) async {}

  @override
  Future<void> addApplicantToGroup({
    required String applicationId,
    required String groupId,
    String role = 'member',
  }) async {}

  @override
  Future<List<Map<String, dynamic>>> getSocietyGroups(String societyId) async {
    return [
      {'id': 'grp-acm-core', 'name': 'ACM Executive Council 2026'},
    ];
  }
}

// =============================================================================
// Local Group Repository
// =============================================================================
class LocalGroupRepository implements GroupRepository {
  final _store = LocalDataStore();

  @override
  Future<List<GroupModel>> getUserGroups() async {
    return _store.getUserGroups();
  }

  @override
  Future<GroupModel> getGroupById(String groupId) async {
    return _store.getUserGroups().firstWhere(
      (g) => g.id == groupId,
      orElse: () => _store.getUserGroups().first,
    );
  }

  @override
  Future<List<GroupMemberModel>> getGroupMembers(String groupId) async {
    return _store.getGroupMembers(groupId);
  }

  @override
  Stream<List<GroupMessageModel>> getGroupMessagesStream(String groupId) {
    return _store.getGroupMessagesStream(groupId);
  }

  @override
  Future<void> sendTextMessage({required String groupId, required String content}) async {
    _store.sendMessage(groupId: groupId, content: content, messageType: 'text');
  }

  @override
  Future<void> sendNoticeMessage({
    required String groupId,
    required String title,
    required String noticeText,
  }) async {
    _store.sendMessage(
      groupId: groupId,
      content: '$title\n$noticeText',
      messageType: 'notice',
    );
  }

  @override
  Future<void> sendPollMessage({
    required String groupId,
    required String question,
    required List<String> options,
  }) async {
    final poll = PollModel(
      question: question,
      options: options,
      votes: const {},
    );
    _store.sendMessage(
      groupId: groupId,
      content: question,
      messageType: 'poll',
      poll: poll,
    );
  }

  @override
  Future<void> sendTaskMessage({
    required String groupId,
    required String title,
    required String description,
    DateTime? dueDate,
    String? assignedTo,
    String? assignedToName,
  }) async {
    final task = TaskModel(
      title: title,
      description: description,
      assignedTo: assignedTo,
      assignedToName: assignedToName ?? 'Assigned Team',
      dueDate: dueDate ?? DateTime.now().add(const Duration(days: 3)),
      isCompleted: false,
    );
    _store.sendMessage(
      groupId: groupId,
      content: title,
      messageType: 'task',
      task: task,
    );
  }

  @override
  Future<void> sendAttachmentMessage({
    required String groupId,
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    required String messageType,
  }) async {
    _store.sendMessage(
      groupId: groupId,
      content: '📎 Shared attachment: $fileName',
      messageType: messageType,
    );
  }

  @override
  Future<GroupModel> createGroup({
    required String societyId,
    required String name,
    required String description,
    bool isPrivate = true,
  }) async {
    final soc = _store.getSocietyById(societyId);
    final grp = GroupModel(
      id: 'grp-${DateTime.now().millisecondsSinceEpoch}',
      societyId: societyId,
      societyName: soc?.name ?? 'UET Society',
      name: name,
      description: description,
      isPrivate: isPrivate,
      createdAt: DateTime.now(),
      memberCount: 1,
    );
    _store.getUserGroups().add(grp);
    return grp;
  }

  @override
  Future<void> leaveGroup(String groupId) async {}

  @override
  Future<void> removeMember({
    required String groupId,
    required String userId,
    bool permanentBlock = true,
    String? reason,
  }) async {}

  @override
  Future<void> votePoll({
    required String messageId,
    required int optionIndex,
  }) async {}

  @override
  Future<void> toggleTaskCompletion({
    required String messageId,
  }) async {}
}

// =============================================================================
// Local Profile Repository
// =============================================================================
class LocalProfileRepository implements ProfileRepository {
  final _store = LocalDataStore();

  @override
  Future<StudentProfile?> getProfile(String userId) async {
    return _store.getProfile(userId);
  }

  @override
  Future<void> updateProfile({
    required String userId,
    required String fullName,
    required int semester,
    String? bio,
    String? phoneNumber,
    String? avatarUrl,
  }) async {
    _store.updateProfile(
      userId: userId,
      fullName: fullName,
      semester: semester,
      bio: bio,
      phoneNumber: phoneNumber,
    );
  }
}
