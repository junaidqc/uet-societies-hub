// ============================================================================
// Repository: supabase_notifications_repository.dart
// Description: Supabase Realtime in-app notifications & mute preferences (FR-36, FR-37)
// ============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/config/supabase_config.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/app_logger.dart';

class InAppNotificationModel {
  final String id;
  final String userId;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final bool isRead;
  final DateTime createdAt;

  const InAppNotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.data,
    required this.isRead,
    required this.createdAt,
  });

  factory InAppNotificationModel.fromMap(Map<String, dynamic> map) {
    return InAppNotificationModel(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      title: map['title'] as String? ?? 'Notification',
      body: map['body'] as String? ?? '',
      data: map['data'] is Map<String, dynamic> ? map['data'] as Map<String, dynamic> : {},
      isRead: map['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

class NotificationPreferenceModel {
  final String id;
  final String userId;
  final String? societyId;
  final String? societyName;
  final String? groupId;
  final String? groupName;
  final bool isMuted;

  const NotificationPreferenceModel({
    required this.id,
    required this.userId,
    this.societyId,
    this.societyName,
    this.groupId,
    this.groupName,
    required this.isMuted,
  });

  factory NotificationPreferenceModel.fromMap(Map<String, dynamic> map) {
    return NotificationPreferenceModel(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      societyId: map['society_id'] as String?,
      societyName: map['societies'] != null ? map['societies']['name'] as String? : null,
      groupId: map['group_id'] as String?,
      groupName: map['groups'] != null ? map['groups']['name'] as String? : null,
      isMuted: map['is_muted'] as bool? ?? false,
    );
  }
}

class SupabaseNotificationsRepository {
  final SupabaseClient _client;

  SupabaseNotificationsRepository(this._client);

  Stream<List<InAppNotificationModel>> streamNotifications() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const Stream.empty();

    return _client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .map((list) => list.map((json) => InAppNotificationModel.fromMap(json)).toList());
  }

  Future<void> markAsRead(String id) async {
    try {
      await _client.from('notifications').update({'is_read': true}).eq('id', id);
    } catch (e, stack) {
      AppLogger.e('Error marking notification as read', e, stack);
    }
  }

  Future<void> markAllAsRead() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return;
      await _client.from('notifications').update({'is_read': true}).eq('user_id', userId);
    } catch (e, stack) {
      AppLogger.e('Error marking all notifications as read', e, stack);
    }
  }

  Future<List<NotificationPreferenceModel>> getMutePreferences() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return [];

      final response = await _client
          .from('notification_preferences')
          .select('*, societies(name), groups(name)')
          .eq('user_id', userId);

      return (response as List<dynamic>)
          .map((json) => NotificationPreferenceModel.fromMap(json as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      AppLogger.e('Error fetching mute preferences', e, stack);
      return [];
    }
  }

  Future<void> toggleMute({String? societyId, String? groupId, required bool mute}) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return;

      if (mute) {
        await _client.from('notification_preferences').upsert({
          'user_id': userId,
          'society_id': societyId,
          'group_id': groupId,
          'is_muted': true,
        });
      } else {
        var query = _client.from('notification_preferences').delete().eq('user_id', userId);
        if (societyId != null) query = query.eq('society_id', societyId);
        if (groupId != null) query = query.eq('group_id', groupId);
        await query;
      }
    } catch (e, stack) {
      AppLogger.e('Error toggling notification mute', e, stack);
      throw ServerFailure('Failed to update mute preferences: $e');
    }
  }
}

final notificationsRepositoryProvider = Provider<SupabaseNotificationsRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseNotificationsRepository(client);
});

final inAppNotificationsStreamProvider = StreamProvider.autoDispose<List<InAppNotificationModel>>((ref) {
  final repo = ref.watch(notificationsRepositoryProvider);
  return repo.streamNotifications();
});

final mutePreferencesProvider = FutureProvider.autoDispose<List<NotificationPreferenceModel>>((ref) async {
  final repo = ref.watch(notificationsRepositoryProvider);
  return repo.getMutePreferences();
});
