// ============================================================================
// Model: group_message_model.dart
// Description: Realtime chat message model with attachment, notice, poll, task
// ============================================================================

import 'poll_and_task_models.dart';

class GroupMessageModel {
  final String id;
  final String groupId;
  final String senderId;
  final String? senderName;
  final String? senderAvatarUrl;
  final String content;
  final String messageType; // 'text', 'image', 'document', 'notice', 'poll', 'task'
  final String? attachmentPath;
  final String? attachmentUrl;
  final PollModel? poll;
  final TaskModel? task;
  final DateTime createdAt;

  const GroupMessageModel({
    required this.id,
    required this.groupId,
    required this.senderId,
    this.senderName,
    this.senderAvatarUrl,
    required this.content,
    this.messageType = 'text',
    this.attachmentPath,
    this.attachmentUrl,
    this.poll,
    this.task,
    required this.createdAt,
  });

  factory GroupMessageModel.fromMap(Map<String, dynamic> map, {String? signedAttachmentUrl}) {
    final sender = map['sender'] as Map<String, dynamic>? ?? map['profiles'] as Map<String, dynamic>?;

    PollModel? pollModel;
    if (map['poll_data'] != null && map['poll_data'] is Map<String, dynamic> && (map['poll_data'] as Map).isNotEmpty) {
      pollModel = PollModel.fromMap(map['poll_data'] as Map<String, dynamic>);
    }

    TaskModel? taskModel;
    if (map['task_data'] != null && map['task_data'] is Map<String, dynamic> && (map['task_data'] as Map).isNotEmpty) {
      taskModel = TaskModel.fromMap(map['task_data'] as Map<String, dynamic>);
    }

    return GroupMessageModel(
      id: map['id'] as String,
      groupId: map['group_id'] as String,
      senderId: map['sender_id'] as String,
      senderName: sender?['full_name'] as String? ?? 'Group Member',
      senderAvatarUrl: sender?['avatar_url'] as String?,
      content: map['content'] as String? ?? '',
      messageType: map['message_type'] as String? ?? 'text',
      attachmentPath: map['attachment_path'] as String?,
      attachmentUrl: signedAttachmentUrl,
      poll: pollModel,
      task: taskModel,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  bool get isNotice => messageType == 'notice';
  bool get isPoll => messageType == 'poll';
  bool get isTask => messageType == 'task';
  bool get isImage => messageType == 'image';
  bool get isDocument => messageType == 'document';
}
