// ============================================================================
// Dialog: report_dialog.dart
// Description: Reusable student content reporting dialog (FR-38)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/supabase_config.dart';
import '../../../../core/constants/app_colors.dart';

class ReportDialog extends ConsumerStatefulWidget {
  final String targetType; // 'post' | 'comment' | 'message' | 'society'
  final String targetId;
  final String targetTitle;

  const ReportDialog({
    super.key,
    required this.targetType,
    required this.targetId,
    required this.targetTitle,
  });

  static Future<void> show(
    BuildContext context, {
    required String targetType,
    required String targetId,
    required String targetTitle,
  }) {
    return showDialog(
      context: context,
      builder: (_) => ReportDialog(
        targetType: targetType,
        targetId: targetId,
        targetTitle: targetTitle,
      ),
    );
  }

  @override
  ConsumerState<ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends ConsumerState<ReportDialog> {
  final _reasonController = TextEditingController();
  String _selectedCategory = 'Violation of UET Code of Conduct';
  bool _isSubmitting = false;

  final _categories = [
    'Violation of UET Code of Conduct',
    'Harassment or Hate Speech',
    'Spam or Commercial Promotion',
    'Misinformation or False Claim',
    'Inappropriate Media Content',
    'Other',
  ];

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    final client = ref.read(supabaseClientProvider);
    final user = client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to report content.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final combinedReason = '[$_selectedCategory] ${_reasonController.text.trim()}';

      await client.from('reports').insert({
        'reporter_id': user.id,
        'target_type': widget.targetType,
        'target_id': widget.targetId,
        'reason': combinedReason,
        'status': 'pending',
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report submitted. University administration will review promptly.'),
            backgroundColor: AppColors.accent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit report: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.flag_outlined, color: AppColors.error),
          const SizedBox(width: 8),
          Text('Report ${widget.targetType.toUpperCase()}', style: const TextStyle(fontSize: 16)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reporting: "${widget.targetTitle}"',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            const Text('Reason Category *', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 4),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              isExpanded: true,
              items: _categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13))))
                  .toList(),
              onChanged: (val) => setState(() => _selectedCategory = val!),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reasonController,
              decoration: const InputDecoration(
                labelText: 'Additional Details (Optional)',
                hintText: 'Explain why this violates university rules...',
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: _isSubmitting ? null : _submitReport,
          child: _isSubmitting
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Submit Report', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
