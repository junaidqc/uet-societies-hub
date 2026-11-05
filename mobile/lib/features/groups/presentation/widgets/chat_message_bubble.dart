// ============================================================================
// Widget: chat_message_bubble.dart
// Description: Renders text, image, doc, notice, poll, and task messages
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/models/group_message_model.dart';
import '../controllers/group_controller.dart';

class ChatMessageBubble extends ConsumerWidget {
  final GroupMessageModel message;
  final bool isMe;

  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (message.isNotice) {
      return _buildNoticeCard(context);
    } else if (message.isPoll) {
      return _buildPollCard(context, ref);
    } else if (message.isTask) {
      return _buildTaskCard(context, ref);
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primary : (Theme.of(context).brightness == Brightness.dark ? AppColors.darkCard : Colors.white),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isMe && message.senderName != null) ...[
              Text(
                message.senderName!,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(height: 2),
            ],
            if (message.isImage && message.attachmentUrl != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  message.attachmentUrl!,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 48),
                ),
              ),
              const SizedBox(height: 6),
            ],
            if (message.isDocument) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.description_outlined,
                    color: isMe ? Colors.white : AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      message.content,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isMe ? Colors.white : null,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ] else ...[
              Text(
                message.content,
                style: TextStyle(
                  fontSize: 14,
                  color: isMe ? Colors.white : null,
                ),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              DateFormat('hh:mm a').format(message.createdAt.toLocal()),
              style: TextStyle(
                fontSize: 10,
                color: isMe ? Colors.white70 : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoticeCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.campaign, color: AppColors.warning, size: 20),
              const SizedBox(width: 8),
              const Text(
                'OFFICIAL NOTICE',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 0.8,
                  color: AppColors.warning,
                ),
              ),
              const Spacer(),
              Text(
                DateFormat('MMM dd, hh:mm a').format(message.createdAt.toLocal()),
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message.content,
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
          if (message.senderName != null) ...[
            const SizedBox(height: 6),
            Text(
              'Posted by: ${message.senderName}',
              style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPollCard(BuildContext context, WidgetRef ref) {
    final poll = message.poll;
    if (poll == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.how_to_vote, color: AppColors.primary, size: 18),
              const SizedBox(width: 6),
              const Text(
                'GROUP POLL',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
              const Spacer(),
              Text('${poll.totalVotes} votes', style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            poll.question,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          ...List.generate(poll.options.length, (index) {
            final option = poll.options[index];
            final percent = poll.votePercentage(index);
            final voteCount = poll.votesForOption(index);

            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: InkWell(
                onTap: () {
                  ref.read(groupActionsControllerProvider.notifier).votePoll(
                    messageId: message.id,
                    optionIndex: index,
                  );
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(option, style: const TextStyle(fontSize: 13)),
                          ),
                          Text(
                            '$voteCount (${(percent * 100).toStringAsFixed(0)}%)',
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: percent,
                          backgroundColor: Colors.grey.withOpacity(0.15),
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                          minHeight: 5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTaskCard(BuildContext context, WidgetRef ref) {
    final task = message.task;
    if (task == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: task.isCompleted ? AppColors.accent.withOpacity(0.5) : Colors.grey.withOpacity(0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: task.isCompleted,
            activeColor: AppColors.accent,
            onChanged: (_) {
              ref.read(groupActionsControllerProvider.notifier).toggleTask(messageId: message.id);
            },
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (task.description != null && task.description!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    task.description!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (task.dueDate != null) ...[
                      const Icon(Icons.event, size: 12, color: AppColors.error),
                      const SizedBox(width: 4),
                      Text(
                        'Due ${DateFormat('MMM dd').format(task.dueDate!)}',
                        style: const TextStyle(fontSize: 11, color: AppColors.error, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(width: 12),
                    ],
                    if (task.assignedToName != null) ...[
                      const Icon(Icons.person, size: 12, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        task.assignedToName!,
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
