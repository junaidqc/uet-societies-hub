// ============================================================================
// Screen: admin_dashboard_screen.dart
// Description: System Admin Moderation & Metrics Dashboard (FR-38..FR-40)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/config/supabase_config.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../../core/widgets/error_state_view.dart';
import '../../../../core/widgets/skeleton_loader.dart';

final systemMetricsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  if (SupabaseConfig.isDemoHost) {
    return {
      'total_users': 1420,
      'total_societies': 12,
      'total_posts': 84,
      'pending_reports': 2,
    };
  }
  final client = ref.watch(supabaseClientProvider);
  final response = await client.rpc('get_system_dashboard_metrics');
  return Map<String, dynamic>.from(response as Map);
});

final pendingReportsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  if (SupabaseConfig.isDemoHost) {
    return [
      {
        'id': 'rep-1',
        'target_type': 'comment',
        'target_id': 'cmt-99',
        'reason': 'Spam / promotional link in comment section',
        'status': 'pending',
        'created_at': DateTime.now().subtract(const Duration(hours: 5)).toIso8601String(),
        'profiles': {'full_name': 'Ali Raza', 'email': '2021se45@uet.edu.pk', 'roll_number': '2021-SE-45'},
      },
    ];
  }
  final client = ref.watch(supabaseClientProvider);
  final response = await client
      .from('reports')
      .select('*, profiles:reporter_id(full_name, email, roll_number)')
      .order('created_at', ascending: false);
  return (response as List<dynamic>).map((e) => Map<String, dynamic>.from(e as Map)).toList();
});

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  String _reportFilter = 'pending'; // 'pending' | 'resolved' | 'dismissed'

  Future<void> _deleteContent(Map<String, dynamic> report) async {
    final reportId = report['id'] as String;
    final reasonController = TextEditingController(text: 'Violated UET Community Guidelines');

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Reported Content?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This will permanently delete the ${report['target_type']} and log an audit record.'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(labelText: 'Deletion Reason'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Content', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final client = ref.read(supabaseClientProvider);
      await client.rpc('delete_reported_content', params: {
        'p_report_id': reportId,
        'p_reason': reasonController.text.trim(),
      });

      ref.invalidate(pendingReportsProvider);
      ref.invalidate(systemMetricsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Content removed & report resolved.'), backgroundColor: AppColors.accent),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting content: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _dismissReport(String reportId) async {
    try {
      final client = ref.read(supabaseClientProvider);
      await client.rpc('resolve_report', params: {
        'p_report_id': reportId,
        'p_status': 'dismissed',
        'p_admin_notes': 'Reviewed by admin; no violation found.',
      });

      ref.invalidate(pendingReportsProvider);
      ref.invalidate(systemMetricsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report dismissed.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final metricsAsync = ref.watch(systemMetricsProvider);
    final reportsAsync = ref.watch(pendingReportsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('System Admin Console'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              ref.invalidate(systemMetricsProvider);
              ref.invalidate(pendingReportsProvider);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'University Overview',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // Metrics Cards Grid
            metricsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (err, _) => Text('Metrics error: $err', style: const TextStyle(color: AppColors.error)),
              data: (metrics) => _buildMetricsGrid(metrics),
            ),

            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Content Moderation Queue',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                DropdownButton<String>(
                  value: _reportFilter,
                  items: const [
                    DropdownMenuItem(value: 'pending', child: Text('Pending')),
                    DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
                    DropdownMenuItem(value: 'dismissed', child: Text('Dismissed')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _reportFilter = val);
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),

            reportsAsync.when(
              loading: () => const SkeletonListLoader(),
              error: (err, _) => ErrorStateView(
                title: 'Unable to load reports',
                message: err.toString(),
                onRetry: () => ref.refresh(pendingReportsProvider),
              ),
              data: (reports) {
                final filtered = reports.where((r) => r['status'] == _reportFilter).toList();

                if (filtered.isEmpty) {
                  return EmptyStateView(
                    icon: Icons.verified_user_outlined,
                    title: 'No $_reportFilter Reports',
                    description: 'All student reports in this category have been processed.',
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final report = filtered[index];
                    return _buildReportCard(report);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsGrid(Map<String, dynamic> m) {
    return LayoutBuilder(builder: (context, constraints) {
      final width = (constraints.maxWidth - 12) / 2;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _buildMetricTile(width, 'Total Students', '${m['total_users'] ?? 0}', Icons.people, AppColors.primary),
          _buildMetricTile(width, 'Active Societies', '${m['total_societies'] ?? 0}', Icons.account_balance, AppColors.accent),
          _buildMetricTile(width, 'Total Posts', '${m['total_posts'] ?? 0}', Icons.article, Colors.indigo),
          _buildMetricTile(width, 'Active Recruitments', '${m['active_hirings'] ?? 0}', Icons.work, Colors.orange),
          _buildMetricTile(constraints.maxWidth, 'Pending Reports', '${m['pending_reports'] ?? 0}', Icons.flag, AppColors.error),
        ],
      );
    });
  }

  Widget _buildMetricTile(double width, String title, String value, IconData icon, Color color) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.18),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
              Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard(Map<String, dynamic> r) {
    final reporter = r['profiles'] as Map<String, dynamic>?;
    final reporterName = reporter?['full_name'] as String? ?? 'Student';
    final targetType = (r['target_type'] as String? ?? 'content').toUpperCase();
    final reason = r['reason'] as String? ?? '';
    final createdAt = DateTime.tryParse(r['created_at'] as String? ?? '');

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    targetType,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.error),
                  ),
                ),
                if (createdAt != null)
                  Text(
                    DateFormat('MMM dd, hh:mm a').format(createdAt.toLocal()),
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              reason,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              'Reported by: $reporterName (${reporter?['email'] ?? ""})',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            if (r['status'] == 'pending') ...[
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => _dismissReport(r['id'] as String),
                    child: const Text('Dismiss'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                    onPressed: () => _deleteContent(r),
                    child: const Text('Delete Content', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
