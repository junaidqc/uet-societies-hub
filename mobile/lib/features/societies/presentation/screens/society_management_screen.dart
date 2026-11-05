import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/pull_to_refresh_wrapper.dart';
import '../../../../core/widgets/skeleton_loader.dart';
import '../../../../core/widgets/error_state_view.dart';
import '../controllers/society_controller.dart';
import '../../domain/models/society_model.dart';
import '../../domain/models/office_bearer_model.dart';

class SocietyManagementScreen extends ConsumerStatefulWidget {
  final String societyId;

  const SocietyManagementScreen({
    super.key,
    required this.societyId,
  });

  @override
  ConsumerState<SocietyManagementScreen> createState() => _SocietyManagementScreenState();
}

class _SocietyManagementScreenState extends ConsumerState<SocietyManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _profileFormKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _descController;
  late TextEditingController _emailController;
  late TextEditingController _websiteController;
  late TextEditingController _fbController;
  late TextEditingController _linkedinController;

  bool _initialized = false;
  late String _selectedCategory;

  final List<String> _categories = [
    'Technical',
    'Cultural',
    'Literary',
    'Sports',
    'Social',
    'Academic',
    'Arts'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _nameController = TextEditingController();
    _descController = TextEditingController();
    _emailController = TextEditingController();
    _websiteController = TextEditingController();
    _fbController = TextEditingController();
    _linkedinController = TextEditingController();
    _selectedCategory = _categories.first;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _descController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    _fbController.dispose();
    _linkedinController.dispose();
    super.dispose();
  }

  void _populateFields(SocietyModel society) {
    if (!_initialized) {
      _nameController.text = society.name;
      _descController.text = society.description;
      _emailController.text = society.email ?? '';
      _websiteController.text = society.website ?? '';
      _fbController.text = society.socialLinks['facebook']?.toString() ?? '';
      _linkedinController.text = society.socialLinks['linkedin']?.toString() ?? '';
      if (_categories.contains(society.category)) {
        _selectedCategory = society.category;
      }
      _initialized = true;
    }
  }

  Future<void> _handleSaveProfile(SocietyModel current) async {
    if (!_profileFormKey.currentState!.validate()) return;

    final updated = current.copyWith(
      name: _nameController.text.trim(),
      category: _selectedCategory,
      description: _descController.text.trim(),
      email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
      website: _websiteController.text.trim().isEmpty ? null : _websiteController.text.trim(),
      socialLinks: {
        if (_fbController.text.trim().isNotEmpty) 'facebook': _fbController.text.trim(),
        if (_linkedinController.text.trim().isNotEmpty) 'linkedin': _linkedinController.text.trim(),
      },
    );

    final success = await ref
        .read(societyActionControllerProvider.notifier)
        .updateSociety(updated);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Society profile successfully updated!'),
          backgroundColor: AppColors.accent,
        ),
      );
    }
  }

  void _showGrantAdminDialog(BuildContext context, bool isPresident) {
    if (!isPresident) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only the Society President can grant admin rights.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final rollController = TextEditingController();
    String selectedRole = 'admin';
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Grant Admin Privileges'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Enter the UET student roll number to appoint:'),
                const SizedBox(height: 12),
                TextFormField(
                  controller: rollController,
                  decoration: const InputDecoration(
                    labelText: 'Roll Number (YYYY-Dept-Roll)',
                    hintText: 'e.g. 2022-CS-101',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Roll number is required' : null,
                ),
                const SizedBox(height: 16),
                const Text('Select Privileged Role:'),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.military_tech_outlined)),
                  items: const [
                    DropdownMenuItem(value: 'admin', child: Text('Executive Admin')),
                    DropdownMenuItem(value: 'moderator', child: Text('Moderator')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedRole = val);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                Navigator.of(ctx).pop();
                final success = await ref
                    .read(societyActionControllerProvider.notifier)
                    .grantAdminRole(
                      societyId: widget.societyId,
                      rollNumber: rollController.text.trim(),
                      role: selectedRole,
                    );
                if (success && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Admin role granted to ${rollController.text}!'),
                      backgroundColor: AppColors.accent,
                    ),
                  );
                }
              },
              child: const Text('Grant Role'),
            ),
          ],
        ),
      ),
    );
  }

  void _showRevokeDialog(BuildContext context, OfficeBearerModel bearer) {
    if (bearer.isPresident) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot revoke the President. Presidential transfer required.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revoke Privileges?'),
        content: Text('Are you sure you want to revoke executive rights from ${bearer.fullName} (${bearer.rollNumber})?'),
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
                  .read(societyActionControllerProvider.notifier)
                  .revokeAdminRole(
                    societyId: widget.societyId,
                    targetUserId: bearer.userId,
                  );
              if (success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Admin role revoked for ${bearer.fullName}.'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            child: const Text('Revoke'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final societyAsync = ref.watch(societyDetailProvider(widget.societyId));
    final bearersAsync = ref.watch(societyOfficeBearersProvider(widget.societyId));
    final roleAsync = ref.watch(userSocietyRoleProvider(widget.societyId));
    final actionState = ref.watch(societyActionControllerProvider);

    final userRole = roleAsync.value;
    final isPresident = userRole == 'president';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Society Executive Console'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(icon: Icon(Icons.edit_note_rounded), text: 'Edit Profile'),
            Tab(icon: Icon(Icons.shield_outlined), text: 'Office Bearers'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // TAB 1: EDIT PROFILE
          societyAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => ErrorStateView(message: err.toString()),
            data: (society) {
              if (society == null) return const Center(child: Text('Society not found'));
              _populateFields(society);

              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Form(
                  key: _profileFormKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (actionState.errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: AppColors.error.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(actionState.errorMessage!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
                        ),
                      ],

                      AppTextField(
                        controller: _nameController,
                        label: 'Society Name',
                        validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 14),

                      Text('Category', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        decoration: const InputDecoration(prefixIcon: Icon(Icons.category_outlined)),
                        items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedCategory = val);
                        },
                      ),
                      const SizedBox(height: 14),

                      AppTextField(
                        controller: _descController,
                        label: 'About & Description',
                        maxLines: 4,
                        validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 14),

                      AppTextField(
                        controller: _emailController,
                        label: 'Official Society Email',
                        prefixIcon: Icons.email_outlined,
                      ),
                      const SizedBox(height: 14),

                      AppTextField(
                        controller: _websiteController,
                        label: 'Official Website',
                        prefixIcon: Icons.language_rounded,
                      ),
                      const SizedBox(height: 14),

                      AppTextField(
                        controller: _fbController,
                        label: 'Facebook Link',
                        prefixIcon: Icons.share_rounded,
                      ),
                      const SizedBox(height: 14),

                      AppTextField(
                        controller: _linkedinController,
                        label: 'LinkedIn Link',
                        prefixIcon: Icons.link_rounded,
                      ),
                      const SizedBox(height: 24),

                      AppButton(
                        text: 'Save Society Profile',
                        icon: Icons.save_rounded,
                        isLoading: actionState.isLoading,
                        onPressed: () => _handleSaveProfile(society),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              );
            },
          ),

          // TAB 2: OFFICE BEARERS & ADMIN ROLES (FR-10)
          bearersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => ErrorStateView(message: err.toString()),
            data: (bearers) {
              return PullToRefreshWrapper(
                onRefresh: () async {
                  ref.invalidate(societyOfficeBearersProvider(widget.societyId));
                },
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  children: [
                    // President Privileges Banner
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.verified_user_rounded, color: AppColors.primary, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Executive Access Control',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isPresident
                                      ? 'As President, you can grant or revoke executive admin rights by student roll number.'
                                      : 'You are viewing the executive council in read-only administrator mode.',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (isPresident) ...[
                      AppButton(
                        text: 'Grant Admin Rights to Student',
                        icon: Icons.person_add_alt_1_rounded,
                        onPressed: () => _showGrantAdminDialog(context, isPresident),
                      ),
                      const SizedBox(height: 20),
                    ],

                    Text(
                      'Current Office Bearers (${bearers.length})',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),

                    ...bearers.map((b) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: b.isPresident ? AppColors.primary : AppColors.primaryContainer,
                            child: Icon(
                              b.isPresident ? Icons.star_rounded : Icons.person_rounded,
                              color: b.isPresident ? Colors.white : AppColors.primary,
                            ),
                          ),
                          title: Text(b.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: Text('${b.rollNumber} • ${b.department}\nRole: ${b.roleDisplay}', style: const TextStyle(fontSize: 12)),
                          isThreeLine: true,
                          trailing: isPresident && !b.isPresident
                              ? IconButton(
                                  icon: const Icon(Icons.person_remove_outlined, color: AppColors.error),
                                  tooltip: 'Revoke Admin Rights',
                                  onPressed: () => _showRevokeDialog(context, b),
                                )
                              : null,
                        ),
                      );
                    }).toList(),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
