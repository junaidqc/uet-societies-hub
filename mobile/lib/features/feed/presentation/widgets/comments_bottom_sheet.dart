import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/error_state_view.dart';
import '../../../../core/widgets/skeleton_loader.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../navigation/presentation/screens/main_scaffold.dart';
import '../controllers/feed_controller.dart';
import '../../domain/models/comment_model.dart';

class CommentsBottomSheet extends ConsumerStatefulWidget {
  final String postId;

  const CommentsBottomSheet({
    super.key,
    required this.postId,
  });

  static void show(BuildContext context, String postId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => CommentsBottomSheet(postId: postId),
    );
  }

  @override
  ConsumerState<CommentsBottomSheet> createState() => _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends ConsumerState<CommentsBottomSheet> {
  final _commentController = TextEditingController();
  bool _isPosting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _handlePostComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final user = ref.read(currentUserProvider);
    if (user == null || user.isGuest) {
      MainScaffold.promptGuestLogin(context, 'join the conversation and comment');
      return;
    }

    setState(() => _isPosting = true);
    final success = await ref
        .read(feedActionControllerProvider.notifier)
        .addComment(widget.postId, text);

    setState(() => _isPosting = false);

    if (success && mounted) {
      _commentController.clear();
      FocusScope.of(context).unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final commentsAsync = ref.watch(postCommentsProvider(widget.postId));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Container(
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),

              // Title Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Comments',
                    style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 1),

              // Comments List
              Expanded(
                child: commentsAsync.when(
                  loading: () => ListView(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    children: const [
                      SkeletonBox(width: double.infinity, height: 60),
                      SizedBox(height: 12),
                      SkeletonBox(width: double.infinity, height: 60),
                    ],
                  ),
                  error: (err, _) => ErrorStateView(
                    message: err.toString(),
                    onRetry: () => ref.invalidate(postCommentsProvider(widget.postId)),
                  ),
                  data: (comments) {
                    if (comments.isEmpty) {
                      return const Center(
                        child: Text(
                          'No comments yet. Be the first to share your thoughts!',
                          style: TextStyle(color: AppColors.lightTextMuted, fontSize: 13),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      itemCount: comments.length,
                      itemBuilder: (context, index) {
                        final c = comments[index];
                        final timeStr = DateFormat('MMM d, h:mm a').format(c.createdAt);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: AppColors.primaryContainer,
                                backgroundImage: c.authorAvatar != null
                                    ? NetworkImage(c.authorAvatar!)
                                    : null,
                                child: c.authorAvatar == null
                                    ? Text(
                                        c.authorName.isNotEmpty ? c.authorName[0].toUpperCase() : 'U',
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            c.authorRoll.isNotEmpty
                                                ? '${c.authorName} (${c.authorRoll})'
                                                : c.authorName,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          timeStr,
                                          style: const TextStyle(fontSize: 10, color: AppColors.lightTextMuted),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      c.content,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                        height: 1.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              // Comment Input
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _handlePostComment(),
                        decoration: InputDecoration(
                          hintText: 'Add a comment...',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _isPosting
                        ? const SizedBox(
                            width: 32,
                            height: 32,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : IconButton(
                            icon: const Icon(Icons.send_rounded, color: AppColors.primary),
                            onPressed: _handlePostComment,
                          ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
