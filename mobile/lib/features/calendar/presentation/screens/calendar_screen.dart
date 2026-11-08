// ============================================================================
// Screen: calendar_screen.dart
// Description: Unified Calendar showing Society Events & Hiring Deadlines (FR-35).
//              Works fully in Guest Mode (UC-3).
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../../core/widgets/skeleton_loader.dart';
import '../../../feed/presentation/controllers/feed_controller.dart';
import '../../../feed/domain/models/event_model.dart';
import '../../../hiring/presentation/controllers/hiring_controller.dart';
import '../../../hiring/domain/models/hiring_model.dart';

class CalendarItem {
  final String id;
  final String title;
  final String societyName;
  final DateTime date;
  final bool isEvent; // true for Event, false for Hiring Deadline
  final String subtitle;
  final dynamic originalObject;

  const CalendarItem({
    required this.id,
    required this.title,
    required this.societyName,
    required this.date,
    required this.isEvent,
    required this.subtitle,
    required this.originalObject,
  });
}

final calendarItemsProvider = Provider.autoDispose<AsyncValue<List<CalendarItem>>>((ref) {
  final eventsAsync = ref.watch(eventsListProvider);
  final hiringsAsync = ref.watch(hiringsListProvider);

  if (eventsAsync.isLoading || hiringsAsync.isLoading) {
    return const AsyncValue.loading();
  }

  if (eventsAsync.hasError) {
    return AsyncValue.error(eventsAsync.error!, eventsAsync.stackTrace!);
  }
  if (hiringsAsync.hasError) {
    return AsyncValue.error(hiringsAsync.error!, hiringsAsync.stackTrace!);
  }

  final events = eventsAsync.value ?? [];
  final hirings = hiringsAsync.value ?? [];

  final List<CalendarItem> items = [];

  for (final ev in events) {
    items.add(CalendarItem(
      id: ev.id,
      title: ev.title,
      societyName: ev.societyName,
      date: ev.startTime,
      isEvent: true,
      subtitle: 'Venue: ${ev.venue} • Starts at ${DateFormat('hh:mm a').format(ev.startTime)}',
      originalObject: ev,
    ));
  }

  for (final h in hirings) {
    if (h.isOpen) {
      items.add(CalendarItem(
        id: h.id,
        title: '${h.title} (Deadline)',
        societyName: h.societyName ?? 'UET Society',
        date: h.deadline,
        isEvent: false,
        subtitle: '${h.daysLeft} days remaining • ${h.positions.join(", ")}',
        originalObject: h,
      ));
    }
  }

  items.sort((a, b) => a.date.compareTo(b.date));
  return AsyncValue.data(items);
});

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final calendarAsync = ref.watch(calendarItemsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Campus Calendar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.today),
            tooltip: 'Today',
            onPressed: () {
              setState(() => _selectedDate = DateTime.now());
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Date Selector Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Theme.of(context).cardColor,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('MMMM yyyy').format(_selectedDate),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () {
                        setState(() {
                          _selectedDate = DateTime(
                            _selectedDate.year,
                            _selectedDate.month - 1,
                            _selectedDate.day,
                          );
                        });
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () {
                        setState(() {
                          _selectedDate = DateTime(
                            _selectedDate.year,
                            _selectedDate.month + 1,
                            _selectedDate.day,
                          );
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Items List
          Expanded(
            child: calendarAsync.when(
              loading: () => const SkeletonListLoader(),
              error: (err, _) => Center(
                child: Text('Error loading calendar: $err'),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return const EmptyStateView(
                    icon: Icons.calendar_today_outlined,
                    title: 'No Scheduled Events or Deadlines',
                    description: 'Check back later for upcoming campus events and recruitment cycles.',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _buildCalendarItemCard(context, item);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarItemCard(BuildContext context, CalendarItem item) {
    final isUpcoming = item.date.isAfter(DateTime.now());

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (item.isEvent) {
            _showEventDetailsSheet(context, item.originalObject as EventModel);
          } else {
            final hiring = item.originalObject as HiringModel;
            context.push('/hiring/${hiring.id}/apply');
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date Badge
              Container(
                width: 52,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: item.isEvent
                      ? AppColors.primaryLight.withOpacity(0.5)
                      : AppColors.warning.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: item.isEvent ? AppColors.primary : AppColors.warning,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      DateFormat('MMM').format(item.date).toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: item.isEvent ? AppColors.primary : AppColors.warning,
                      ),
                    ),
                    Text(
                      DateFormat('dd').format(item.date),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: item.isEvent ? AppColors.primary : AppColors.warning,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: item.isEvent ? AppColors.primary : AppColors.warning,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item.isEvent ? 'EVENT' : 'HIRING DEADLINE',
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.societyName,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.title,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.subtitle,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),

              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  void _showEventDetailsSheet(BuildContext context, EventModel event) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              event.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Organized by: ${event.societyName ?? "UET Society"}',
              style: const TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(DateFormat('EEEE, MMMM dd, yyyy - hh:mm a').format(event.startTime)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text('Venue: ${event.venue}'),
              ],
            ),
            const SizedBox(height: 12),
            Text(event.description, style: const TextStyle(fontSize: 13, height: 1.4)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.star_outline),
                label: Text(event.isInterested ? 'RSVP Confirmed' : 'Mark Interested (${event.interestedCount})'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  ref.read(feedActionControllerProvider.notifier).toggleEventInterest(
                    event.id,
                    event.isInterested,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
