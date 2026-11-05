import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../controllers/auth_controller.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailFormKey = GlobalKey<FormState>();
  final _resetFormKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _otpSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSendResetCode() async {
    if (!_emailFormKey.currentState!.validate()) return;

    final success = await ref.read(authControllerProvider.notifier).sendPasswordResetOtp(
          email: _emailController.text.trim(),
        );

    if (success && mounted) {
      setState(() {
        _otpSent = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset code sent! Please check your inbox.'),
          backgroundColor: AppColors.accent,
        ),
      );
    }
  }

  Future<void> _handleResetPassword() async {
    if (!_resetFormKey.currentState!.validate()) return;

    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Passwords do not match'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final success = await ref.read(authControllerProvider.notifier).resetPasswordWithOtp(
          email: _emailController.text.trim(),
          token: _otpController.text.trim(),
          newPassword: _newPasswordController.text,
        );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset successfully! Please log in with your new password.'),
          backgroundColor: AppColors.accent,
        ),
      );
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reset Password'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.forgotPassword,
                style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.primaryDark,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                _otpSent
                    ? 'Enter the 6-digit code sent to ${_emailController.text} and create a new password.'
                    : 'Enter your registered @uet.edu.pk email address to receive a secure recovery code.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),

              if (authState.errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.error.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          authState.errorMessage!,
                          style: const TextStyle(color: AppColors.error, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (!_otpSent) ...[
                // Step 1: Request Code
                Form(
                  key: _emailFormKey,
                  child: Column(
                    children: [
                      AppTextField(
                        controller: _emailController,
                        label: AppStrings.email,
                        hint: 'e.g. 2022-cs-101@uet.edu.pk',
                        keyboardType: TextInputType.emailAddress,
                        prefixIcon: Icons.email_outlined,
                        validator: Validators.validateUetEmail,
                      ),
                      const SizedBox(height: 24),
                      AppButton(
                        text: 'Send Recovery Code',
                        icon: Icons.send_rounded,
                        isLoading: authState.isLoading,
                        onPressed: _handleSendResetCode,
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Step 2: Verify & Reset
                Form(
                  key: _resetFormKey,
                  child: Column(
                    children: [
                      AppTextField(
                        controller: _otpController,
                        label: '6-Digit Recovery Code',
                        hint: '123456',
                        keyboardType: TextInputType.number,
                        prefixIcon: Icons.pin_outlined,
                        validator: Validators.validateOtp,
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        controller: _newPasswordController,
                        label: 'New Password',
                        hint: 'Minimum 8 characters with letter & number',
                        isPassword: true,
                        prefixIcon: Icons.lock_outline_rounded,
                        validator: Validators.validatePassword,
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        controller: _confirmPasswordController,
                        label: 'Confirm New Password',
                        hint: 'Re-enter new password',
                        isPassword: true,
                        prefixIcon: Icons.lock_clock_outlined,
                        validator: (val) {
                          if (val == null || val.isEmpty) {
                            return 'Confirm password is required';
                          }
                          if (val != _newPasswordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      AppButton(
                        text: 'Update Password',
                        icon: Icons.check_circle_outline_rounded,
                        isLoading: authState.isLoading,
                        onPressed: _handleResetPassword,
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => setState(() => _otpSent = false),
                        child: const Text('Change Email Address'),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
