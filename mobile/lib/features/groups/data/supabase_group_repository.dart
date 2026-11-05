// ============================================================================
// Repository Implementation: supabase_group_repository.dart
// Description: Supabase Realtime & RLS implementation for Groups & Chat
// ============================================================================

import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/app_logger.dart';
import '../domain/models/group_model.dart';
import '../domain/models/group_message_model.dart';
import '../domain/repositories/group_repository.dart';

class SupabaseGroupRepository implements GroupRepository {
  final SupabaseClient _client;

  SupabaseGroupRepository(this._client);

  @override
  Future<List<GroupModel>> getUserGroups() async {
    try {
      final currentUserId = _client.auth.currentUser?.id;
      if (currentUserId == null) return [];

      // Query groups where user is a member (RLS will filter automatically)
      final response = await _client
          .from('groups')
          .select('*, societies(name), group_members(count)')
          .order('created_at', {ascending: false});

      return (response as List<dynamic>).map((json) {
        final map = Map<String, dynamic>.from(json as Map);
        final membersList = map['group_members'] as List<dynamic>?;
        final count = membersList != null && membersList.isNotEmpty
            ? membersList.first['count'] as int? ?? 0
            : 0;
        map['member_count'] = count;
        return GroupModel.fromMap(map);
      }).toList();
    } catch (e, stack) {
      AppLogger.e('Error fetching user groups', e, stack);
      throw ServerFailure('Failed to load groups: $e');
    }
  }

  @override
  Future<GroupModel> getGroupById(String groupId) async {
    try {
      final response = await _client
          .from('groups')
          .select('*, societies(name)')
          .eq('id', groupId)
          .single();

      return GroupModel.fromMap(response);
    } catch (e, stack) {
      AppLogger.e('Error fetching group by id', e, stack);
      throw ServerFailure('Failed to load group details: $e');
    }
  }

  @override
  Future<GroupModel> createGroup({
    required String societyId,
    required String name,
    required String description,
    bool isPrivate = true,
  }) async {
    try {
      final currentUserId = _client.auth.currentUser?.id;
      if (currentUserId == null) throw const AuthFailure('Login required to create a group.');

      // Insert group
      final response = await _client
          .from('groups')
          .insert({
            'society_id': societyId,
            'name': name.trim(),
            'description': description.trim(),
            'is_private': isPrivate,
          })
          .select('*, societies(name)')
          .single();

      final createdGroup = GroupModel.fromMap(response);

      // Automatically add the creator as admin member of the group
      await _client.from('group_members').insert({
        'group_id': createdGroup.id,
        'user_id': currentUserId,
        'role': 'admin',
      });

      return createdGroup;
    } catch (e, stack) {
      AppLogger.e('Error creating group', e, stack);
      throw ServerFailure('Failed to create group: $e');
    }
  }

  @override
  Future<List<GroupMemberModel>> getGroupMembers(String groupId) async {
    try {
      final response = await _client
          .from('group_members')
          .select('*, profiles(full_name, email, roll_number, avatar_url)')
          .eq('group_id', groupId)
          .order('joined_at', {ascending: true});

      return (response as List<dynamic>)
          .map((json) => GroupMemberModel.fromMap(json as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      AppLogger.e('Error fetching group members', e, stack);
      throw ServerFailure('Failed to load group members: $e');
    }
  }

  @override
  Future<void> leaveGroup(String groupId) async {
    try {
      await _client.rpc('leave_group', params: {'p_group_id': groupId});
    } catch (e, stack) {
      AppLogger.e('Error leaving group', e, stack);
      throw ServerFailure('Failed to leave group: $e');
    }
  }

  @override
  Future<void> removeMember({
    required String groupId,
    required String userId,
    bool permanentBlock = true,
    String? reason,
  }) async {
    try {
      await _client.rpc('remove_group_member', params: {
        'p_group_id': groupId,
        'p_target_user_id': userId,
        'p_permanent_block': permanentBlock,
        'p_reason': reason,
      });
    } catch (e, stack) {
      AppLogger.e('Error removing group member', e, stack);
      throw ServerFailure('Failed to remove member: $e');
    }
  }

  @override
  Stream<List<GroupMessageModel>> getGroupMessagesStream(String groupId) {
    // Uses Supabase realtime stream with RLS enforcement
    return _client
        .from('group_messages')
        .stream(primaryKey: ['id'])
        .eq('group_id', groupId)
        .order('created_at', {ascending: true})
        .asyncMap((rawList) async {
          final List<GroupMessageModel> messages = [];
          for (final item in rawList) {
            String? signedUrl;
            final attachmentPath = item['attachment_path'] as String?;
            if (attachmentPath != null && attachmentPath.isNotEmpty) {
              try {
                // Generate signed URL (valid 1 hour) for private chat attachment
                signedUrl = await _client.storage
                    .from('chat-attachments')
                    .createSignedUrl(attachmentPath, 3600);
              } catch (_) {
                // Ignore storage fetch error if already cleaned up by retention
              }
            }

            // Fetch sender profile details if needed
            final senderId = item['sender_id'] as String;
            final profile = await _client
                .from('profiles')
                .select('full_name, avatar_url')
                .eq('id', senderId)
                .maybeSingle();

            final enriched = Map<String, dynamic>.from(item);
            if (profile != null) {
              enriched['sender'] = profile;
            }

            messages.add(GroupMessageModel.fromMap(enriched, signedAttachmentUrl: signedUrl));
          }
          return messages;
        });
  }

  @override
  Future<void> sendTextMessage({
    required String groupId,
    required String content,
  }) async {
    try {
      final currentUserId = _client.auth.currentUser?.id;
      if (currentUserId == null) throw const AuthFailure('Login required.');

      await _client.from('group_messages').insert({
        'group_id': groupId,
        'sender_id': currentUserId,
        'content': content.trim(),
        'message_type': 'text',
      });
    } catch (e, stack) {
      AppLogger.e('Error sending text message', e, stack);
      throw ServerFailure('Failed to send message: $e');
    }
  }

  @override
  Future<void> sendAttachmentMessage({
    required String groupId,
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    required String messageType,
  }) async {
    try {
      final currentUserId = _client.auth.currentUser?.id;
      if (currentUserId == null) throw const AuthFailure('Login required.');

      // 1. Client-side 5 MB file size validation
      const maxBytes = 5 * 1024 * 1024; // 5 MB
      if (bytes.length > maxBytes) {
        throw const ValidationFailure('File size exceeds the 5 MB limit.');
      }

      // 2. MIME allowlist validation
      const allowedMimes = [
        'image/jpeg',
        'image/png',
        'image/webp',
        'application/pdf',
        'application/msword',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'text/plain',
      ];
      if (!allowedMimes.contains(mimeType.toLowerCase())) {
        throw ValidationFailure('File format $mimeType is not permitted.');
      }

      // 3. Upload file with secure randomized path: {groupId}/{userId}/{timestamp}_{cleanFileName}
      final sanitizedFileName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final storagePath = '$groupId/$currentUserId/${DateTime.now().millisecondsSinceEpoch}_$sanitizedFileName';

      await _client.storage.from('chat-attachments').uploadBinary(
        storagePath,
        bytes,
        fileOptions: FileOptions(
          contentType: mimeType,
          upsert: false,
        ),
      );

      // 4. Insert message record with attachment_path column (crucial for Phase 5b retention cleanup)
      await _client.from('group_messages').insert({
        'group_id': groupId,
        'sender_id': currentUserId,
        'content': fileName,
        'message_type': messageType,
        'attachment_path': storagePath,
      });
    } catch (e, stack) {
      AppLogger.e('Error sending attachment message', e, stack);
      throw ServerFailure('Failed to upload file: $e');
    }
  }

  @override
  Future<void> sendNoticeMessage({
    required String groupId,
    required String title,
    required String noticeText,
  }) async {
    try {
      final currentUserId = _client.auth.currentUser?.id;
      if (currentUserId == null) throw const AuthFailure('Login required.');

      await _client.from('group_messages').insert({
        'group_id': groupId,
        'sender_id': currentUserId,
        'content': '📢 $title\n\n$noticeText',
        'message_type': 'notice',
      });
    } catch (e, stack) {
      AppLogger.e('Error sending notice', e, stack);
      throw ServerFailure('Failed to post notice: $e');
    }
  }

  @override
  Future<void> sendPollMessage({
    required String groupId,
    required String question,
    required List<String> options,
  }) async {
    try {
      final currentUserId = _client.auth.currentUser?.id;
      if (currentUserId == null) throw const AuthFailure('Login required.');

      await _client.from('group_messages').insert({
        'group_id': groupId,
        'sender_id': currentUserId,
        'content': question,
        'message_type': 'poll',
        'poll_data': {
          'question': question.trim(),
          'options': options.map((o) => o.trim()).toList(),
          'votes': {},
        },
      });
    } catch (e, stack) {
      AppLogger.e('Error creating poll', e, stack);
      throw ServerFailure('Failed to create poll: $e');
    }
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
    try {
      final currentUserId = _client.auth.currentUser?.id;
      if (currentUserId == null) throw const AuthFailure('Login required.');

      await _client.from('group_messages').insert({
        'group_id': groupId,
        'sender_id': currentUserId,
        'content': title,
        'message_type': 'task',
        'task_data': {
          'title': title.trim(),
          'description': description.trim(),
          'due_date': dueDate?.toIso8601String(),
          'assigned_to': assignedTo,
          'assigned_to_name': assignedToName,
          'is_completed': false,
        },
      });
    } catch (e, stack) {
      AppLogger.e('Error assigning task', e, stack);
      throw ServerFailure('Failed to assign task: $e');
    }
  }

  @override
  Future<void> votePoll({
    required String messageId,
    required int optionIndex,
  }) async {
    try {
      await _client.rpc('vote_poll', params: {
        'p_message_id': messageId,
        'p_option_index': optionIndex,
      });
    } catch (e, stack) {
      AppLogger.e('Error voting on poll', e, stack);
      throw ServerFailure('Failed to record vote: $e');
    }
  }

  @override
  Future<void> toggleTaskCompletion({
    required String messageId,
  }) async {
    try {
      await _client.rpc('toggle_task_completion', params: {
        'p_message_id': messageId,
      });
    } catch (e, stack) {
      AppLogger.e('Error toggling task completion', e, stack);
      throw ServerFailure('Failed to update task: $e');
    }
  }
}
