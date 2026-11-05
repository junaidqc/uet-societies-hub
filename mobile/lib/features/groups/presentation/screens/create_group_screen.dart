// ============================================================================
// Screen: create_group_screen.dart
// Description: Admin creates committee/sub-committee group (FR-26)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../societies/presentation/controllers/society_controller.dart';
import '../controllers/group_controller.dart';

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  String? _selectedSocietyId;
  bool _isPrivate = true;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSocietyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an affiliated society.')),
      );
      return;
    }

    final success = await ref.read(groupActionsControllerProvider.notifier).createGroup(
      societyId: _selectedSocietyId!,
      name: _nameController.text.trim(),
      description: _descController.text.trim(),
      isPrivate: _isPrivate,
    );

    if (mounted && success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Committee group created successfully!'),
          backgroundColor: AppColors.accent,
        ),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final societiesAsync = ref.watch(societiesListProvider);
    final actionState = ref.watch(groupActionsControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Create Committee Group')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'New Committee / Working Group',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'Groups are private to invited members and selected recruits.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 20),

              // Affiliated Society Selector
              societiesAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const SizedBox.shrink(),
                data: (societies) {
                  return DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Affiliated Society *',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    value: _selectedSocietyId,
                    items: societies.map((s) {
                      return DropdownMenuItem(value: s.id, child: Text(s.name));
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedSocietyId = val),
                    validator: (val) => val == null ? 'Please select a society' : null,
                  );
                },
              ),
              const SizedBox(height: 16),

              AppTextField(
                controller: _nameController,
                labelText: 'Group Name *',
                hintText: 'e.g. Executive Board, Logistics Team, Media Wing',
                validator: (val) => val == null || val.isEmpty ? 'Group name is required' : null,
              ),
              const SizedBox(height: 16),

              AppTextField(
                controller: _descController,
                labelText: 'Purpose & Description',
                hintText: 'Describe responsibilities, internal targets and scope...',
                maxLines: 3,
              ),
              const SizedBox(height: 16),

              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Strictly Private'),
                subtitle: const Text('Only confirmed members can view and send messages'),
                value: _isPrivate,
                activeColor: AppColors.primary,
                onChanged: (val) => setState(() => _isPrivate = val),
              ),
              const SizedBox(height: 24),

              AppButton(
                text: 'Create Committee Group',
                isLoading: actionState.isLoading,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
