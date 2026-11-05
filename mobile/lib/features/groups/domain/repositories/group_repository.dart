// ============================================================================
// Repository Interface: group_repository.dart
// Description: Contract for Groups, Realtime Chat, Notices, Polls, Tasks (FR-26..FR-32)
// ============================================================================

import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/group_model.dart';
import '../domain/models/group_message_model.dart';

abstract class GroupRepository {
  Future<List<GroupModel>> getUserGroups();
  Future<GroupModel> getGroupById(String groupId);
  Future<GroupModel> createGroup({
    required String societyId,
    required String name,
    required String description,
    bool isPrivate = true,
  });
  Future<List<GroupMemberModel>> getGroupMembers(String groupId);
  Future<void> leaveGroup(String groupId);
  Future<void> removeMember({
    required String groupId,
    required String userId,
    bool permanentBlock = true,
    String? reason,
  });
  Stream<List<GroupMessageModel>> getGroupMessagesStream(String groupId);
  Future<void> sendTextMessage({
    required String groupId,
    required String content,
  });
  Future<void> sendAttachmentMessage({
    required String groupId,
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    required String messageType, // 'image' | 'document'
  });
  Future<void> sendNoticeMessage({
    required String groupId,
    required String title,
    required String noticeText,
  });
  Future<void> sendPollMessage({
    required String groupId,
    required String question,
    required List<String> options,
  });
  Future<void> sendTaskMessage({
    required String groupId,
    required String title,
    required String description,
    DateTime? dueDate,
    String? assignedTo,
    String? assignedToName,
  });
  Future<void> votePoll({
    required String messageId,
    required int optionIndex,
  });
  Future<void> toggleTaskCompletion({
    required String messageId,
  });
}

final groupRepositoryProvider = Provider<GroupRepository>((ref) {
  throw UnimplementedError('groupRepositoryProvider must be overridden');
});
