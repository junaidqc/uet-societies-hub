import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../feed/presentation/controllers/feed_controller.dart';
import '../controllers/hiring_controller.dart';

class CreateHiringScreen extends ConsumerStatefulWidget {
  const CreateHiringScreen({super.key});

  @override
  ConsumerState<CreateHiringScreen> createState() => _CreateHiringScreenState();
}

class _CreateHiringScreenState extends ConsumerState<CreateHiringScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _reqController = TextEditingController();
  final _positionInputController = TextEditingController();
  final _seatsController = TextEditingController(text: '5');

  String? _selectedSocietyId;
  final List<String> _positions = [];
  final List<Map<String, dynamic>> _customQuestions = [];

  final List<String> _selectionMethods = [
    'Interview',
    'Test',
    'Portfolio Review',
    'Interview & Test'
  ];
  late String _selectedSelectionMethod;

  DateTime _deadlineDate = DateTime.now().add(const Duration(days: 14));
  TimeOfDay _deadlineTime = const TimeOfDay(hour: 23, minute: 59);

  @override
  void initState() {
    super.initState();
    _selectedSelectionMethod = _selectionMethods.first;
    // Default sample questions
    _customQuestions.add({'id': 'q1', 'question': 'Why do you want to join this society?', 'required': true});
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _reqController.dispose();
    _positionInputController.dispose();
    _seatsController.dispose();
    super.dispose();
  }

  void _addPosition() {
    final text = _positionInputController.text.trim();
    if (text.isNotEmpty && !_positions.contains(text)) {
      setState(() {
        _positions.add(text);
        _positionInputController.clear();
      });
    }
  }

  void _addCustomQuestionDialog() {
    final qController = TextEditingController();
    bool isRequired = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: const Text('Add Questionnaire Field'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: qController,
                decoration: const InputDecoration(
                  labelText: 'Question Title *',
                  hintText: 'e.g. Link to your GitHub profile...',
                ),
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Required Answer', style: TextStyle(fontSize: 13)),
                value: isRequired,
                onChanged: (val) => setDlgState(() => isRequired = val ?? true),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (qController.text.trim().isNotEmpty) {
                  setState(() {
                    _customQuestions.add({
                      'id': 'q_${DateTime.now().millisecondsSinceEpoch}',
                      'question': qController.text.trim(),
                      'required': isRequired,
                    });
                  });
                  Navigator.of(ctx).pop();
                }
              },
              child: const Text('Add Question'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDeadline() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _deadlineDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 180)),
    );
    if (pickedDate != null) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: _deadlineTime,
      );
      if (pickedTime != null) {
        setState(() {
          _deadlineDate = pickedDate;
          _deadlineTime = pickedTime;
        });
      }
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSocietyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an organizing society.')),
      );
      return;
    }

    if (_positions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one position/role to hire for.')),
      );
      return;
    }

    final deadline = DateTime(
      _deadlineDate.year,
      _deadlineDate.month,
      _deadlineDate.day,
      _deadlineTime.hour,
      _deadlineTime.minute,
    );

    final success = await ref
        .read(hiringActionControllerProvider.notifier)
        .createHiring(
          societyId: _selectedSocietyId!,
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
          positions: _positions,
          deadline: deadline,
          requirements: _reqController.text.trim(),
          selectionMethod: _selectedSelectionMethod,
          totalSeats: int.tryParse(_seatsController.text.trim()) ?? 5,
          customQuestions: _customQuestions,
        );

    if (success && mounted) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final societiesAsync = ref.watch(userAdminSocietiesProvider);
    final actionState = ref.watch(hiringActionControllerProvider);
    final theme = Theme.of(context);

    final deadlineStr = '${DateFormat("MMM d, y").format(_deadlineDate)} at ${_deadlineTime.format(context)}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Publish Recruitment'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Form(
            key: _formKey,
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

                // Society Dropdown
                societiesAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Error: $e'),
                  data: (societies) {
                    if (societies.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(10)),
                        child: const Text('You must be a Society Admin to post recruitments.'),
                      );
                    }

                    if (_selectedSocietyId == null && societies.isNotEmpty) {
                      _selectedSocietyId = societies.first['id'] as String;
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Society *', style: theme.textTheme.titleMedium?.copyWith(fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: _selectedSocietyId,
                          isExpanded: true,
                          decoration: const InputDecoration(prefixIcon: Icon(Icons.group_work_outlined)),
                          items: societies.map((s) {
                            return DropdownMenuItem<String>(
                              value: s['id'] as String,
                              child: Text(s['name'] as String),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedSocietyId = val);
                          },
                        ),
                        const SizedBox(height: 18),
                      ],
                    );
                  },
                ),

                // Hiring Title
                AppTextField(
                  controller: _titleController,
                  label: 'Recruitment Title *',
                  hint: 'e.g. Annual Executive Recruitment 2026',
                  validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),

                // Description
                AppTextField(
                  controller: _descController,
                  label: 'Recruitment Description *',
                  hint: 'Describe goals, perks, culture, and team structure...',
                  maxLines: 4,
                  validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),

                // Requirements
                AppTextField(
                  controller: _reqController,
                  label: 'Eligibility & Requirements *',
                  hint: 'e.g. Currently enrolled UET student, minimum 2.5 CGPA...',
                  maxLines: 3,
                  validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),

                // Positions Tag Input
                Text('Open Positions * (Add at least one)', style: theme.textTheme.titleMedium?.copyWith(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _positionInputController,
                        decoration: const InputDecoration(
                          hintText: 'e.g. Mobile Developer',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                        onSubmitted: (_) => _addPosition(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(60, 50),
                        backgroundColor: AppColors.primary,
                      ),
                      onPressed: _addPosition,
                      child: const Text('Add'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _positions.map((pos) {
                    return Chip(
                      label: Text(pos),
                      deleteIcon: const Icon(Icons.close_rounded, size: 16),
                      onDeleted: () {
                        setState(() => _positions.remove(pos));
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Selection Method & Total Seats Row
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Selection Method *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            value: _selectedSelectionMethod,
                            decoration: const InputDecoration(prefixIcon: Icon(Icons.checklist_rounded)),
                            items: _selectionMethods.map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 13)))).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedSelectionMethod = val);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: AppTextField(
                        controller: _seatsController,
                        label: 'Total Seats *',
                        keyboardType: TextInputType.number,
                        prefixIcon: Icons.event_seat_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Deadline Picker (FR-18)
                const Text('Last Date / Deadline *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                  icon: const Icon(Icons.calendar_today_rounded, size: 18),
                  label: Text('Deadline: $deadlineStr'),
                  onPressed: _selectDeadline,
                ),
                const SizedBox(height: 20),

                // Custom Questions Builder (FR-18, FR-22)
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Custom Questionnaire', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    TextButton.icon(
                      icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                      label: const Text('Add Question'),
                      onPressed: _addCustomQuestionDialog,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ..._customQuestions.map((q) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(q['question'] as String, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      subtitle: Text(q['required'] == true ? 'Mandatory Answer' : 'Optional', style: const TextStyle(fontSize: 11)),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 18),
                        onPressed: () {
                          setState(() => _customQuestions.remove(q));
                        },
                      ),
                    ),
                  );
                }).toList(),
                const SizedBox(height: 28),

                AppButton(
                  text: 'Publish Recruitment',
                  icon: Icons.send_rounded,
                  isLoading: actionState.isLoading,
                  onPressed: _handleSubmit,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
