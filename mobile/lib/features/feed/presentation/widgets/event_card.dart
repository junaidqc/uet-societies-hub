import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../navigation/presentation/screens/main_scaffold.dart';
import '../controllers/feed_controller.dart';
import '../../domain/models/event_model.dart';

class EventCard extends ConsumerWidget {
  final EventModel event;

  const EventCard({
    super.key,
    required this.event,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currentUser = ref.watch(currentUserProvider);

    final dateMonth = DateFormat('MMM').format(event.startTime).toUpperCase();
    final dateDay = DateFormat('d').format(event.startTime);
    final timeRange = '${DateFormat('h:mm a').format(event.startTime)} - ${DateFormat('h:mm a').format(event.endTime)}';

    return Card(
      margin: const EdgeInsets.only(right: 14, bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: SizedBox(
        width: 300,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner Image & Badges
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Stack(
                children: [
                  event.bannerUrl != null
                      ? Image.network(
                          event.bannerUrl!,
                          height: 130,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            height: 130,
                            color: AppColors.primaryContainer,
                            child: const Center(child: Icon(Icons.event_rounded, size: 36, color: AppColors.primary)),
                          ),
                        )
                      : Container(
                          height: 130,
                          color: AppColors.primaryContainer,
                          child: const Center(child: Icon(Icons.event_rounded, size: 36, color: AppColors.primary)),
                        ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            dateMonth,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          Text(
                            dateDay,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        event.isPublic ? 'PUBLIC' : 'MEMBERS ONLY',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content Padding
            Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Society row
                  GestureDetector(
                    onTap: () => context.push('/societies/${event.societyId}'),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 10,
                          backgroundColor: AppColors.primaryContainer,
                          backgroundImage: event.societyLogo != null
                              ? NetworkImage(event.societyLogo!)
                              : null,
                          child: event.societyLogo == null
                              ? const Icon(Icons.group_work_rounded, size: 12)
                              : null,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            event.societyName,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Title
                  Text(
                    event.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 6),

                  // Venue
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 14, color: AppColors.lightTextSecondary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          event.venue,
                          style: const TextStyle(fontSize: 11, color: AppColors.lightTextSecondary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Time
                  Row(
                    children: [
                      const Icon(Icons.access_time_rounded, size: 14, color: AppColors.lightTextSecondary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          timeRange,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: AppColors.lightTextSecondary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Actions: Interested (FR-17) & Register
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: event.isInterested ? AppColors.primaryContainer : null,
                            foregroundColor: event.isInterested ? AppColors.primaryDark : null,
                            side: BorderSide(
                              color: event.isInterested ? AppColors.primary : AppColors.lightBorder,
                            ),
                            minimumSize: const Size(0, 36),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          icon: Icon(
                            event.isInterested ? Icons.star_rounded : Icons.star_border_rounded,
                            size: 16,
                            color: event.isInterested ? Colors.amber.shade800 : null,
                          ),
                          label: Text(
                            event.isInterested
                                ? 'Going (${event.interestedCount})'
                                : 'Interested (${event.interestedCount})',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                          onPressed: () {
                            if (currentUser == null || currentUser.isGuest) {
                              MainScaffold.promptGuestLogin(context, 'RSVP as interested');
                            } else {
                              ref
                                  .read(feedActionControllerProvider.notifier)
                                  .toggleEventInterest(event.id, event.isInterested);
                            }
                          },
                        ),
                      ),
                      if (event.registrationLink != null) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.open_in_new_rounded, size: 18, color: AppColors.primary),
                          tooltip: 'Open Registration Link',
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Registration portal: ${event.registrationLink}')),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
