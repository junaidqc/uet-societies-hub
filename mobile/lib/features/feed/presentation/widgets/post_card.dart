import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../navigation/presentation/screens/main_scaffold.dart';
import '../controllers/feed_controller.dart';
import '../../domain/models/post_model.dart';
import 'comments_bottom_sheet.dart';
import '../../../admin/presentation/widgets/report_dialog.dart';

class PostCard extends ConsumerWidget {
  final PostModel post;

  const PostCard({
    super.key,
    required this.post,
  });

  void _showDeleteDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Post?'),
        content: const Text('Are you sure you want to delete this announcement? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final success = await ref
                  .read(feedActionControllerProvider.notifier)
                  .deletePost(post.id);
              if (success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Post deleted successfully.')),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentUser = ref.watch(currentUserProvider);

    final timeAgo = DateFormat('MMM d, h:mm a').format(post.createdAt);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Society Logo, Name, Badges, 3-dots Menu
            Row(
              children: [
                GestureDetector(
                  onTap: () => context.push('/societies/${post.societyId}'),
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.primaryContainer,
                    backgroundImage: post.societyLogo != null
                        ? NetworkImage(post.societyLogo!)
                        : null,
                    child: post.societyLogo == null
                        ? const Icon(Icons.group_work_rounded, color: AppColors.primary, size: 22)
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => context.push('/societies/${post.societyId}'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                post.societyName,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ),
                            if (post.isPinned) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryContainer,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.push_pin_rounded, size: 10, color: AppColors.primaryDark),
                                    SizedBox(width: 2),
                                    Text(
                                      'PINNED',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primaryDark,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              timeAgo,
                              style: const TextStyle(fontSize: 11, color: AppColors.lightTextMuted),
                            ),
                            const SizedBox(width: 8),
                            // Visibility Badge (Public vs Members Only)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: post.isPublic
                                    ? Colors.blue.withOpacity(0.12)
                                    : Colors.amber.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    post.isPublic ? Icons.public_rounded : Icons.lock_outline_rounded,
                                    size: 10,
                                    color: post.isPublic ? Colors.blue.shade700 : Colors.amber.shade900,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    post.isPublic ? 'Public' : 'Members Only',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: post.isPublic ? Colors.blue.shade800 : Colors.amber.shade900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // 3-dots Menu for Edit / Delete / Pin (FR-15) & Report (FR-38)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, size: 20),
                  onSelected: (value) {
                    if (value == 'pin') {
                      ref
                          .read(feedActionControllerProvider.notifier)
                          .togglePin(post.id, post.isPinned);
                    } else if (value == 'edit') {
                      context.push('/posts/${post.id}/edit', extra: post);
                    } else if (value == 'delete') {
                      _showDeleteDialog(context, ref);
                    } else if (value == 'report') {
                      ReportDialog.show(
                        context,
                        targetType: 'post',
                        targetId: post.id,
                        targetTitle: post.title,
                      );
                    }
                  },
                  itemBuilder: (ctx) => [
                    if (post.canManage) ...[
                      PopupMenuItem(
                        value: 'pin',
                        child: Row(
                          children: [
                            Icon(
                              post.isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(post.isPinned ? 'Unpin Post' : 'Pin to Top'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: const [
                            Icon(Icons.edit_outlined, size: 18),
                            SizedBox(width: 8),
                            Text('Edit Post'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: const [
                            Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
                            SizedBox(width: 8),
                            Text('Delete Post', style: TextStyle(color: AppColors.error)),
                          ],
                        ),
                      ),
                    ],
                    PopupMenuItem(
                      value: 'report',
                      child: Row(
                        children: const [
                          Icon(Icons.flag_outlined, size: 18, color: AppColors.error),
                          SizedBox(width: 8),
                          Text('Report Content', style: TextStyle(color: AppColors.error)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Title
            Text(
              post.title,
              style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
            ),
            const SizedBox(height: 6),

            // Content
            Text(
              post.content,
              style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.4,
                  ),
            ),

            // Media Image Preview
            if (post.mediaUrls.isNotEmpty) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  post.mediaUrls.first,
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 120,
                    color: Colors.grey.shade200,
                    child: const Center(child: Icon(Icons.broken_image_rounded)),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            const Divider(height: 1),

            // Footer Actions: Like, Comment, Share
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                children: [
                  // Like Button (FR-14)
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      if (currentUser == null || currentUser.isGuest) {
                        MainScaffold.promptGuestLogin(context, 'like this post');
                      } else {
                        HapticFeedback.lightImpact();
                        ref.read(feedActionControllerProvider.notifier).toggleLike(post.id, post.isLiked);
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        children: [
                          Icon(
                            post.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            size: 18,
                            color: post.isLiked ? Colors.red : AppColors.lightTextSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${post.likesCount}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: post.isLiked ? Colors.red : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Comment Button (FR-14)
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => CommentsBottomSheet.show(context, post.id),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 18,
                            color: AppColors.lightTextSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${post.commentsCount}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),

                  // Post Author Credit
                  Text(
                    'by ${post.authorName}',
                    style: const TextStyle(fontSize: 11, color: AppColors.lightTextMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
