import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/config/supabase_config.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/backend_config_sheet.dart';
import '../controllers/auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    // If user enters roll number or username without @, append @uet.edu.pk
    String emailText = _emailController.text.trim();
    if (emailText.isNotEmpty && !emailText.contains('@')) {
      emailText = '$emailText@uet.edu.pk';
      _emailController.text = emailText;
    }

    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your email or roll number and password.'),
          backgroundColor: AppColors.error,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    final success = await ref.read(authControllerProvider.notifier).signIn(
          email: emailText,
          password: _passwordController.text,
        );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Logged in successfully! Welcome back.'),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 2),
        ),
      );
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_sync_rounded, color: AppColors.primary),
            tooltip: 'Configure Supabase Backend',
            onPressed: () => BackendConfigSheet.show(context),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top UET Lahore Emblem Header
                Center(
                  child: Container(
                    width: 76,
                    height: 76,
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.18),
                          blurRadius: 18,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/uet_logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),

                if (SupabaseConfig.isDemoHost) ...[
                  GestureDetector(
                    onTap: () => BackendConfigSheet.show(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.amber.shade700, width: 0.8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, size: 18, color: Colors.amber.shade900),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Demo Supabase backend active. Tap to connect your project.',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.amber.shade900,
                              ),
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded, size: 18, color: Colors.amber),
                        ],
                      ),
                    ),
                  ),
                ],

                Text(
                  AppStrings.welcomeBack,
                  style: theme.textTheme.displayMedium?.copyWith(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.primaryDark,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  AppStrings.loginSubtitle,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 32),

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

                if (SupabaseConfig.isDemoHost) ...[
                  Text(
                    'Quick Demo Accounts (Tap to Auto-fill):',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ActionChip(
                          avatar: const Icon(Icons.school_rounded, size: 16),
                          label: const Text('Student (Junaid)', style: TextStyle(fontSize: 12)),
                          onPressed: () {
                            setState(() {
                              _emailController.text = '2022cs101@uet.edu.pk';
                              _passwordController.text = 'Student@123';
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        ActionChip(
                          avatar: const Icon(Icons.stars_rounded, size: 16),
                          label: const Text('President (ACM)', style: TextStyle(fontSize: 12)),
                          onPressed: () {
                            setState(() {
                              _emailController.text = 'president.acm@uet.edu.pk';
                              _passwordController.text = 'President@123';
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        ActionChip(
                          avatar: const Icon(Icons.admin_panel_settings_rounded, size: 16),
                          label: const Text('System Admin', style: TextStyle(fontSize: 12)),
                          onPressed: () {
                            setState(() {
                              _emailController.text = 'admin@uet.edu.pk';
                              _passwordController.text = 'Admin@123';
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Email Field
                AppTextField(
                  controller: _emailController,
                  label: AppStrings.email,
                  hint: 'e.g. 2022-cs-101@uet.edu.pk',
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: Icons.email_outlined,
                  validator: Validators.validateUetEmail,
                ),
                const SizedBox(height: 18),

                // Password Field
                AppTextField(
                  controller: _passwordController,
                  label: AppStrings.password,
                  hint: '••••••••',
                  isPassword: true,
                  prefixIcon: Icons.lock_outline_rounded,
                  validator: (val) => val == null || val.isEmpty ? 'Password is required' : null,
                ),
                const SizedBox(height: 10),

                // Forgot Password Link
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => context.push('/forgot-password'),
                    child: Text(
                      AppStrings.forgotPassword,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.primaryLight : AppColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Log In Button
                AppButton(
                  text: AppStrings.login,
                  icon: Icons.login_rounded,
                  isLoading: authState.isLoading,
                  onPressed: _handleLogin,
                ),
                const SizedBox(height: 24),

                // Switch to Sign Up
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account? ",
                      style: theme.textTheme.bodyMedium,
                    ),
                    GestureDetector(
                      onTap: () => context.pushReplacement('/signup'),
                      child: Text(
                        'Sign Up',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.primaryLight : AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Continue as guest
                Center(
                  child: TextButton(
                    onPressed: () async {
                      await ref.read(authControllerProvider.notifier).continueAsGuest();
                      if (context.mounted) {
                        context.go('/home');
                      }
                    },
                    child: const Text('Or Continue as Guest'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
