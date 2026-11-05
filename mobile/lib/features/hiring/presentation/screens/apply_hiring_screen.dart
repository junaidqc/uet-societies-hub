import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/skeleton_loader.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../profile/presentation/controllers/profile_controller.dart';
import '../controllers/hiring_controller.dart';
import '../../domain/models/hiring_model.dart';

class ApplyHiringScreen extends ConsumerStatefulWidget {
  final String hiringId;
  final String? initialPosition;

  const ApplyHiringScreen({
    super.key,
    required this.hiringId,
    this.initialPosition,
  });

  @override
  ConsumerState<ApplyHiringScreen> createState() => _ApplyHiringScreenState();
}

class _ApplyHiringScreenState extends ConsumerState<ApplyHiringScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedPosition;
  final Map<String, TextEditingController> _questionControllers = {};
  bool _isCheckingDuplicate = false;
  bool _hasAlreadyApplied = false;

  @override
  void initState() {
    super.initState();
    _selectedPosition = widget.initialPosition;
  }

  @override
  void dispose() {
    for (var c in _questionControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _checkDuplicate(String pos) async {
    setState(() => _isCheckingDuplicate = true);
    final repo = ref.read(hiringRepositoryProvider);
    final applied = await repo.checkHasApplied(widget.hiringId, pos);
    setState(() {
      _hasAlreadyApplied = applied;
      _isCheckingDuplicate = false;
    });
  }

  Future<void> _handleSubmit(HiringModel hiring) async {
    if (_hasAlreadyApplied) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You have already submitted an application for "$_selectedPosition".'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;
    if (_selectedPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select the position you are applying for.')),
      );
      return;
    }

    // Collect answers
    final answers = <String, dynamic>{};
    for (var q in hiring.customQuestions) {
      final qId = q['id']?.toString() ?? q['question'].toString();
      final text = _questionControllers[qId]?.text.trim() ?? '';
      answers[q['question'].toString()] = text;
    }

    final success = await ref
        .read(hiringActionControllerProvider.notifier)
        .applyToHiring(
          hiringId: hiring.id,
          position: _selectedPosition!,
          answers: answers,
        );

    if (success && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: const [
              Icon(Icons.check_circle_rounded, color: AppColors.accent, size: 28),
              SizedBox(width: 10),
              Text('Application Sent!'),
            ],
          ),
          content: Text(
            'Your application for $_selectedPosition at ${hiring.societyName} has been received. You can track status updates in your profile and notifications.',
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () {
                Navigator.of(ctx).pop();
                context.pop();
              },
              child: const Text('Return to Hirings'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hiringAsync = ref.watch(hiringDetailProvider(widget.hiringId));
    final profileAsync = ref.watch(currentProfileProvider);
    final actionState = ref.watch(hiringActionControllerProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Submit Application'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: hiringAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Error: $err')),
          data: (hiring) {
            if (hiring == null) {
              return const Center(child: Text('Recruitment not found.'));
            }

            if (_selectedPosition == null && hiring.positions.isNotEmpty) {
              _selectedPosition = hiring.positions.first;
              _checkDuplicate(_selectedPosition!);
            }

            // Initialize question controllers
            for (var q in hiring.customQuestions) {
              final qId = q['id']?.toString() ?? q['question'].toString();
              if (!_questionControllers.containsKey(qId)) {
                _questionControllers[qId] = TextEditingController();
              }
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Society & Role Header Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: AppColors.primary,
                            backgroundImage: hiring.societyLogo != null
                                ? NetworkImage(hiring.societyLogo!)
                                : null,
                            child: hiring.societyLogo == null
                                ? const Icon(Icons.group_work_rounded, color: Colors.white)
                                : null,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  hiring.societyName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  hiring.title,
                                  style: const TextStyle(fontSize: 13, color: AppColors.primaryDark),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Selection Method: ${hiring.selectionMethod} • Total Seats: ${hiring.totalSeats}',
                                  style: const TextStyle(fontSize: 11, color: AppColors.lightTextSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Verified Student Info Banner
                    profileAsync.when(
                      loading: () => const SkeletonBox(width: double.infinity, height: 50),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (profile) {
                        if (profile == null) return const SizedBox.shrink();
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurface : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.lightBorder),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.verified_user_rounded, color: AppColors.primary, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Applying as ${profile.fullName} (${profile.rollNumber}) • ${profile.department}, Sem ${profile.semester}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),

                    // Position Selector
                    const Text(
                      'Choose Position *',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: hiring.positions.map((pos) {
                        final isSelected = pos == _selectedPosition;
                        return ChoiceChip(
                          label: Text(pos),
                          selected: isSelected,
                          selectedColor: AppColors.primary,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : null,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _selectedPosition = pos);
                              _checkDuplicate(pos);
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),

                    // Duplicate Warning Banner (FR-23)
                    if (_hasAlreadyApplied) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.error.withOpacity(0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.block_rounded, color: AppColors.error, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Duplicate Block (FR-23): You have already submitted an application for "$_selectedPosition".',
                                style: const TextStyle(fontSize: 12, color: AppColors.error, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Error from controller
                    if (actionState.errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          actionState.errorMessage!,
                          style: const TextStyle(color: AppColors.error, fontSize: 13),
                        ),
                      ),
                    ],

                    // Custom Admin Questions (FR-22)
                    if (hiring.customQuestions.isNotEmpty) ...[
                      const Divider(height: 28),
                      Text(
                        'Society Executive Questionnaire',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 14),
                      ...hiring.customQuestions.map((q) {
                        final qId = q['id']?.toString() ?? q['question'].toString();
                        final qText = q['question']?.toString() ?? '';
                        final isRequired = q['required'] == true;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: AppTextField(
                            controller: _questionControllers[qId],
                            label: '$qText ${isRequired ? "*" : "(Optional)"}',
                            hint: 'Your answer...',
                            maxLines: 3,
                            validator: (val) {
                              if (isRequired && (val == null || val.trim().isEmpty)) {
                                return 'This question requires an answer';
                              }
                              return null;
                            },
                          ),
                        );
                      }).toList(),
                    ],
                    const SizedBox(height: 24),

                    // Submit Button (<= 5 taps achieved!)
                    AppButton(
                      text: _hasAlreadyApplied ? 'Already Applied' : 'Submit Application Now',
                      icon: Icons.send_rounded,
                      isLoading: actionState.isLoading || _isCheckingDuplicate,
                      onPressed: _hasAlreadyApplied ? null : () => _handleSubmit(hiring),
                    ),
                    const SizedBox(height: 24),
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
