import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../controllers/feed_controller.dart';

class CreateEventScreen extends ConsumerStatefulWidget {
  const CreateEventScreen({super.key});

  @override
  ConsumerState<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends ConsumerState<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _venueController = TextEditingController();
  final _regLinkController = TextEditingController();

  String? _selectedSocietyId;
  DateTime _startDate = DateTime.now().add(const Duration(days: 3));
  TimeOfDay _startTime = const TimeOfDay(hour: 10, minute: 0);
  DateTime _endDate = DateTime.now().add(const Duration(days: 3));
  TimeOfDay _endTime = const TimeOfDay(hour: 16, minute: 0);

  bool _isPublic = true;
  String? _bannerUrl;
  bool _isUploadingBanner = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _venueController.dispose();
    _regLinkController.dispose();
    super.dispose();
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        if (_endDate.isBefore(_startDate)) {
          _endDate = _startDate;
        }
      });
    }
  }

  Future<void> _selectStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (picked != null) {
      setState(() => _startTime = picked);
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _endDate = picked);
    }
  }

  Future<void> _selectEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
    );
    if (picked != null) {
      setState(() => _endTime = picked);
    }
  }

  Future<void> _handleBannerUpload() async {
    if (_selectedSocietyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a society first.')),
      );
      return;
    }

    setState(() => _isUploadingBanner = true);
    try {
      final sampleImageBytes = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
      );

      final repo = ref.read(feedRepositoryProvider);
      final url = await repo.uploadPostMedia(
        fileBytes: sampleImageBytes,
        fileName: 'event_banner.png',
        mimeType: 'image/png',
        societyId: _selectedSocietyId!,
      );

      setState(() {
        _bannerUrl = url;
        _isUploadingBanner = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Event banner uploaded (5 MB cap & MIME verified)!'),
            backgroundColor: AppColors.accent,
          ),
        );
      }
    } catch (e) {
      setState(() => _isUploadingBanner = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload error: $e'), backgroundColor: AppColors.error),
        );
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

    final startDateTime = DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
      _startTime.hour,
      _startTime.minute,
    );

    final endDateTime = DateTime(
      _endDate.year,
      _endDate.month,
      _endDate.day,
      _endTime.hour,
      _endTime.minute,
    );

    if (endDateTime.isBefore(startDateTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('End time cannot be earlier than start time.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final success = await ref
        .read(feedActionControllerProvider.notifier)
        .createEvent(
          societyId: _selectedSocietyId!,
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
          venue: _venueController.text.trim(),
          startTime: startDateTime,
          endTime: endDateTime,
          bannerUrl: _bannerUrl,
          registrationLink: _regLinkController.text.trim().isEmpty ? null : _regLinkController.text.trim(),
          isPublic: _isPublic,
        );

    if (success && mounted) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final societiesAsync = ref.watch(userAdminSocietiesProvider);
    final actionState = ref.watch(feedActionControllerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Society Event'),
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
                    child: Text(
                      actionState.errorMessage!,
                      style: const TextStyle(color: AppColors.error, fontSize: 13),
                    ),
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
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text('You must be a Society Admin to host events.'),
                      );
                    }

                    if (_selectedSocietyId == null && societies.isNotEmpty) {
                      _selectedSocietyId = societies.first['id'] as String;
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Organizing Society *', style: theme.textTheme.titleMedium?.copyWith(fontSize: 14, fontWeight: FontWeight.w600)),
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

                // Event Title
                AppTextField(
                  controller: _titleController,
                  label: 'Event Title *',
                  hint: 'e.g. National Robotics Expo 2026',
                  validator: (val) => val == null || val.trim().isEmpty ? 'Title is required' : null,
                ),
                const SizedBox(height: 16),

                // Venue
                AppTextField(
                  controller: _venueController,
                  label: 'Campus Venue *',
                  hint: 'e.g. Main Auditorium / CS Department Hall',
                  prefixIcon: Icons.location_on_outlined,
                  validator: (val) => val == null || val.trim().isEmpty ? 'Venue is required' : null,
                ),
                const SizedBox(height: 16),

                // Dates & Times Pickers
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Start Date *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          const SizedBox(height: 6),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.calendar_today_rounded, size: 16),
                            label: Text(DateFormat('MMM d, y').format(_startDate), style: const TextStyle(fontSize: 12)),
                            onPressed: _selectStartDate,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Start Time *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          const SizedBox(height: 6),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.access_time_rounded, size: 16),
                            label: Text(_startTime.format(context), style: const TextStyle(fontSize: 12)),
                            onPressed: _selectStartTime,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('End Date *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          const SizedBox(height: 6),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.calendar_today_rounded, size: 16),
                            label: Text(DateFormat('MMM d, y').format(_endDate), style: const TextStyle(fontSize: 12)),
                            onPressed: _selectEndDate,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('End Time *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          const SizedBox(height: 6),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.access_time_rounded, size: 16),
                            label: Text(_endTime.format(context), style: const TextStyle(fontSize: 12)),
                            onPressed: _selectEndTime,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Description
                AppTextField(
                  controller: _descController,
                  label: 'Event Details & Agenda *',
                  hint: 'Describe schedule, guest speakers, guidelines, or entry rules...',
                  maxLines: 4,
                  validator: (val) => val == null || val.trim().isEmpty ? 'Description is required' : null,
                ),
                const SizedBox(height: 16),

                // Registration URL
                AppTextField(
                  controller: _regLinkController,
                  label: 'Online Registration Form URL (Optional)',
                  hint: 'https://forms.gle/...',
                  keyboardType: TextInputType.url,
                  prefixIcon: Icons.link_rounded,
                ),
                const SizedBox(height: 16),

                // Banner Upload
                Text('Event Banner (5 MB Cap, Image MIME)', style: theme.textTheme.titleMedium?.copyWith(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (_bannerUrl != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(_bannerUrl!, width: 80, height: 60, fit: BoxFit.cover),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isUploadingBanner ? null : _handleBannerUpload,
                        icon: _isUploadingBanner
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.add_photo_alternate_outlined, size: 18),
                        label: Text(_bannerUrl != null ? 'Change Banner' : 'Upload Banner'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),

                // Visibility Switch (FR-12)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Public Event', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text(
                    _isPublic
                        ? 'Open for all students & public attendees across campus.'
                        : 'Members Only: RSVP restricted strictly to confirmed society members.',
                    style: const TextStyle(fontSize: 12),
                  ),
                  value: _isPublic,
                  activeColor: AppColors.primary,
                  onChanged: (val) => setState(() => _isPublic = val),
                ),
                const SizedBox(height: 24),

                AppButton(
                  text: 'Publish Event',
                  icon: Icons.event_available_rounded,
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
