import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/local/local_data_store.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/network_resilience.dart';
import '../domain/models/profile_model.dart';
import '../domain/repositories/profile_repository.dart';

class SupabaseProfileRepository implements ProfileRepository {
  final SupabaseClient _client;

  SupabaseProfileRepository(this._client);

  @override
  Future<StudentProfile?> getProfile(String userId) async {
    try {
      AppLogger.info('Fetching profile for student');
      final response = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (response == null) {
        return null;
      }
      return StudentProfile.fromJson(response);
    } catch (e) {
      AppLogger.error('Failed to get profile', e);
      if (isNetworkOrHandshakeError(e)) {
        return LocalDataStore().getProfile(userId);
      }
      throw ServerFailure('Could not load profile: ${e.toString()}');
    }
  }

  @override
  Future<void> updateProfile({
    required String userId,
    required String fullName,
    required int semester,
    String? bio,
    String? phoneNumber,
    String? avatarUrl,
  }) async {
    try {
      AppLogger.info('Updating profile for user');
      final updates = <String, dynamic>{
        'full_name': fullName.trim(),
        'semester': semester,
        'bio': bio?.trim(),
        'phone_number': phoneNumber?.trim(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      if (avatarUrl != null) {
        updates['avatar_url'] = avatarUrl;
      }

      await _client
          .from('profiles')
          .update(updates)
          .eq('id', userId);
    } catch (e) {
      AppLogger.error('Error updating profile', e);
      throw ServerFailure('Failed to update profile: ${e.toString()}');
    }
  }
}
