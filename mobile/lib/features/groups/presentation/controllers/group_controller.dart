// ============================================================================
// Controller: group_controller.dart
// Description: Riverpod state management for Groups, Chat, Polls & Tasks
// ============================================================================

import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/supabase_config.dart';
import '../../data/supabase_group_repository.dart';
import '../../domain/models/group_model.dart';
import '../../domain/models/group_message_model.dart';
import '../../domain/repositories/group_repository.dart';

final supabaseGroupRepositoryProvider = Provider<GroupRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseGroupRepository(client);
});

/// Future provider for groups the current user is a member of
final userGroupsProvider = FutureProvider.autoDispose<List<GroupModel>>((ref) async {
  final repo = ref.watch(supabaseGroupRepositoryProvider);
  return repo.getUserGroups();
});

/// Future provider for members of a specific group
final groupMembersProvider = FutureProvider.family.autoDispose<List<GroupMemberModel>, String>((ref, groupId) async {
  final repo = ref.watch(supabaseGroupRepositoryProvider);
  return repo.getGroupMembers(groupId);
});

/// Realtime stream provider for group messages
final groupMessagesStreamProvider = StreamProvider.family.autoDispose<List<GroupMessageModel>, String>((ref, groupId) {
  final repo = ref.watch(supabaseGroupRepositoryProvider);
  return repo.getGroupMessagesStream(groupId);
});

/// Controller for group mutations (create group, send message, remove member, etc.)
class GroupActionsController extends StateNotifier<AsyncValue<void>> {
  final GroupRepository _repository;
  final Ref _ref;

  GroupActionsController(this._repository, this._ref) : super(const AsyncValue.data(null));

  Future<bool> createGroup({
    required String societyId,
    required String name,
    required String description,
    bool isPrivate = true,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repository.createGroup(
        societyId: societyId,
        name: name,
        description: description,
        isPrivate: isPrivate,
      );
      _ref.invalidate(userGroupsProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }

  Future<void> sendTextMessage({required String groupId, required String content}) async {
    try {
      await _repository.sendTextMessage(groupId: groupId, content: content);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> sendAttachmentMessage({
    required String groupId,
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    required String messageType,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repository.sendAttachmentMessage(
        groupId: groupId,
        bytes: bytes,
        fileName: fileName,
        mimeType: mimeType,
        messageType: messageType,
      );
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> sendNotice({
    required String groupId,
    required String title,
    required String noticeText,
  }) async {
    try {
      await _repository.sendNoticeMessage(
        groupId: groupId,
        title: title,
        noticeText: noticeText,
      );
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> sendPoll({
    required String groupId,
    required String question,
    required List<String> options,
  }) async {
    try {
      await _repository.sendPollMessage(
        groupId: groupId,
        question: question,
        options: options,
      );
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> sendTask({
    required String groupId,
    required String title,
    required String description,
    DateTime? dueDate,
    String? assignedTo,
    String? assignedToName,
  }) async {
    try {
      await _repository.sendTaskMessage(
        groupId: groupId,
        title: title,
        description: description,
        dueDate: dueDate,
        assignedTo: assignedTo,
        assignedToName: assignedToName,
      );
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> votePoll({required String messageId, required int optionIndex}) async {
    try {
      await _repository.votePoll(messageId: messageId, optionIndex: optionIndex);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> toggleTask({required String messageId}) async {
    try {
      await _repository.toggleTaskCompletion(messageId: messageId);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<bool> leaveGroup(String groupId) async {
    state = const AsyncValue.loading();
    try {
      await _repository.leaveGroup(groupId);
      _ref.invalidate(userGroupsProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }

  Future<bool> removeMember({
    required String groupId,
    required String userId,
    bool permanentBlock = true,
    String? reason,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repository.removeMember(
        groupId: groupId,
        userId: userId,
        permanentBlock: permanentBlock,
        reason: reason,
      );
      _ref.invalidate(groupMembersProvider(groupId));
      state = const AsyncValue.data(null);
      return true;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }
}

final groupActionsControllerProvider = StateNotifierProvider<GroupActionsController, AsyncValue<void>>((ref) {
  final repo = ref.watch(supabaseGroupRepositoryProvider);
  return GroupActionsController(repo, ref);
});
