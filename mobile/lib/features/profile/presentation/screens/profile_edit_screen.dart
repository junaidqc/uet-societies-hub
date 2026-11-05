import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/error_state_view.dart';
import '../../../../core/widgets/skeleton_loader.dart';
import '../controllers/profile_controller.dart';

class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _fullNameController;
  late TextEditingController _semesterController;
  late TextEditingController _bioController;
  late TextEditingController _phoneController;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController();
    _semesterController = TextEditingController();
    _bioController = TextEditingController();
    _phoneController = TextEditingController();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _semesterController.dispose();
    _bioController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleSave(String userId) async {
    if (!_formKey.currentState!.validate()) return;

    final success = await ref.read(profileControllerProvider.notifier).updateProfile(
          userId: userId,
          fullName: _fullNameController.text.trim(),
          semester: int.tryParse(_semesterController.text.trim()) ?? 1,
          bio: _bioController.text.trim(),
          phoneNumber: _phoneController.text.trim(),
        );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully!'),
          backgroundColor: AppColors.accent,
        ),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentProfileProvider);
    final editState = ref.watch(profileControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: profileAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(24.0),
            child: SkeletonCardLoader(),
          ),
          error: (err, _) => ErrorStateView(
            message: err.toString(),
            onRetry: () => ref.invalidate(currentProfileProvider),
          ),
          data: (profile) {
            if (profile == null) {
              return const Center(child: Text('Profile not found'));
            }

            if (!_initialized) {
              _fullNameController.text = profile.fullName;
              _semesterController.text = profile.semester.toString();
              _bioController.text = profile.bio ?? '';
              _phoneController.text = profile.phoneNumber ?? '';
              _initialized = true;
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (editState.errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: BorderSide(color: AppColors.error.withOpacity(0.3)),
                        ),
                        child: Text(
                          editState.errorMessage!,
                          style: const TextStyle(color: AppColors.error, fontSize: 13),
                        ),
                      ),
                    ],

                    // Read-only info banner
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Roll No (${profile.rollNumber}) and Email (${profile.email}) are verified student records and cannot be altered.',
                              style: const TextStyle(fontSize: 12, color: AppColors.primaryDark),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Full Name
                    AppTextField(
                      controller: _fullNameController,
                      label: 'Full Name',
                      hint: 'Your official name',
                      prefixIcon: Icons.person_outline_rounded,
                      validator: Validators.validateFullName,
                    ),
                    const SizedBox(height: 18),

                    // Semester
                    AppTextField(
                      controller: _semesterController,
                      label: 'Current Semester (1-12)',
                      hint: '1 - 12',
                      keyboardType: TextInputType.number,
                      prefixIcon: Icons.school_outlined,
                      validator: Validators.validateSemester,
                    ),
                    const SizedBox(height: 18),

                    // Phone Number
                    AppTextField(
                      controller: _phoneController,
                      label: 'Phone Number (Optional)',
                      hint: 'e.g. 03001234567',
                      keyboardType: TextInputType.phone,
                      prefixIcon: Icons.phone_outlined,
                    ),
                    const SizedBox(height: 18),

                    // Bio
                    AppTextField(
                      controller: _bioController,
                      label: 'Bio / About You',
                      hint: 'Share your skills, society interests, and passions...',
                      maxLines: 4,
                      prefixIcon: Icons.description_outlined,
                    ),
                    const SizedBox(height: 32),

                    // Save Button
                    AppButton(
                      text: 'Save Changes',
                      icon: Icons.save_rounded,
                      isLoading: editState.isLoading,
                      onPressed: () => _handleSave(profile.id),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
