import 'dart:math';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/local/local_data_store.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/network_resilience.dart';
import '../domain/models/society_model.dart';
import '../domain/models/office_bearer_model.dart';
import '../domain/repositories/society_repository.dart';

class SupabaseSocietyRepository implements SocietyRepository {
  final SupabaseClient _client;

  SupabaseSocietyRepository(this._client);

  @override
  Future<List<SocietyModel>> getSocieties({String? category, String? search}) async {
    try {
      AppLogger.info('Fetching active societies list');
      var query = _client.from('societies').select('*, follows(user_id)').eq('status', 'active');

      if (category != null && category != 'All' && category.isNotEmpty) {
        query = query.eq('category', category);
      }

      if (search != null && search.trim().isNotEmpty) {
        final term = search.trim();
        query = query.or('name.ilike.%$term%,description.ilike.%$term%');
      }

      final response = await query.order('name');
      final currentUserId = _client.auth.currentUser?.id;

      return (response as List<dynamic>).map((row) {
        final followsList = (row['follows'] as List<dynamic>?) ?? [];
        final count = followsList.length;
        final isFollowed = currentUserId != null &&
            followsList.any((f) => f['user_id'] == currentUserId);

        return SocietyModel.fromJson(
          row as Map<String, dynamic>,
          followersCount: count,
          isFollowed: isFollowed,
        );
      }).toList();
    } catch (e) {
      AppLogger.error('Failed to get societies', e);
      if (isNetworkOrHandshakeError(e)) {
        AppLogger.warn('Network/Handshake error in getSocieties, returning local societies.');
        return LocalDataStore().getSocieties(category: category, search: search);
      }
      throw ServerFailure('Could not load societies: ${e.toString()}');
    }
  }

  @override
  Future<List<SocietyModel>> getPendingRequests() async {
    try {
      AppLogger.info('Fetching pending society requests for system admin');
      final response = await _client
          .from('societies')
          .select('*, profiles!created_by(full_name, roll_number, email)')
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      return (response as List<dynamic>)
          .map((row) => SocietyModel.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.error('Failed to get pending society requests', e);
      throw ServerFailure('Could not load pending requests: ${e.toString()}');
    }
  }

  @override
  Future<SocietyModel?> getSocietyById(String id) async {
    try {
      final currentUserId = _client.auth.currentUser?.id;
      final response = await _client
          .from('societies')
          .select('*, follows(user_id)')
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;

      final followsList = (response['follows'] as List<dynamic>?) ?? [];
      final count = followsList.length;
      final isFollowed = currentUserId != null &&
          followsList.any((f) => f['user_id'] == currentUserId);

      return SocietyModel.fromJson(
        response,
        followersCount: count,
        isFollowed: isFollowed,
      );
    } catch (e) {
      AppLogger.error('Failed to get society by id', e);
      if (isNetworkOrHandshakeError(e)) {
        return LocalDataStore().getSocietyById(id);
      }
      throw ServerFailure('Failed to load society details.');
    }
  }

  @override
  Future<String?> getUserSocietyRole(String societyId, String userId) async {
    try {
      final response = await _client
          .from('society_admins')
          .select('role')
          .eq('society_id', societyId)
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) return null;
      return response['role'] as String?;
    } catch (e) {
      AppLogger.error('Failed to check user society role', e);
      return null;
    }
  }

  @override
  Future<List<OfficeBearerModel>> getOfficeBearers(String societyId) async {
    try {
      AppLogger.info('Fetching office bearers for society');
      final response = await _client
          .from('society_admins')
          .select('id, society_id, user_id, role, profiles(full_name, roll_number, department, avatar_url)')
          .eq('society_id', societyId)
          .order('role');

      return (response as List<dynamic>)
          .map((row) => OfficeBearerModel.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.error('Failed to load office bearers', e);
      throw ServerFailure('Could not load society office bearers.');
    }
  }

  @override
  Future<SocietyModel> submitRegistrationRequest({
    required String name,
    required String category,
    required String description,
    String? email,
    String? website,
    Map<String, dynamic>? socialLinks,
    String? logoUrl,
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw const AuthFailure('You must be logged in to register a society.');
      }

      // Generate slug from name
      final slug = name
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
          .replaceAll(RegExp(r'^-+|-+$'), '');

      final row = {
        'name': name.trim(),
        'slug': '$slug-${DateTime.now().millisecondsSinceEpoch % 10000}',
        'category': category,
        'description': description.trim(),
        'email': email?.trim(),
        'website': website?.trim(),
        'social_links': socialLinks ?? {},
        'logo_url': logoUrl,
        'status': 'pending',
        'created_by': user.id,
      };

      final response = await _client
          .from('societies')
          .insert(row)
          .select()
          .single();

      return SocietyModel.fromJson(response);
    } catch (e) {
      AppLogger.error('Registration request submission failed', e);
      throw ServerFailure('Could not submit society registration: ${e.toString()}');
    }
  }

  @override
  Future<void> approveSociety(String societyId) async {
    try {
      AppLogger.info('Approving society via RPC');
      await _client.rpc('approve_society_registration', params: {
        'p_society_id': societyId,
      });
    } catch (e) {
      AppLogger.error('Error approving society', e);
      throw ServerFailure('Failed to approve society: ${e.toString()}');
    }
  }

  @override
  Future<void> rejectSociety(String societyId, String reason) async {
    try {
      AppLogger.info('Rejecting society via RPC');
      await _client.rpc('reject_society_registration', params: {
        'p_society_id': societyId,
        'p_reason': reason,
      });
    } catch (e) {
      AppLogger.error('Error rejecting society', e);
      throw ServerFailure('Failed to reject society: ${e.toString()}');
    }
  }

  @override
  Future<void> followSociety(String societyId) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw const AuthFailure('Login required to follow societies.');
      }

      await _client.from('follows').insert({
        'user_id': user.id,
        'society_id': societyId,
      });
    } catch (e) {
      AppLogger.error('Follow society error', e);
      throw ServerFailure('Could not follow society.');
    }
  }

  @override
  Future<void> unfollowSociety(String societyId) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return;

      await _client
          .from('follows')
          .delete()
          .eq('user_id', user.id)
          .eq('society_id', societyId);
    } catch (e) {
      AppLogger.error('Unfollow society error', e);
      throw ServerFailure('Could not unfollow society.');
    }
  }

  @override
  Future<void> updateSociety(SocietyModel society) async {
    try {
      AppLogger.info('Updating society profile');
      await _client.from('societies').update({
        'name': society.name.trim(),
        'category': society.category,
        'description': society.description.trim(),
        'email': society.email?.trim(),
        'website': society.website?.trim(),
        'social_links': society.socialLinks,
        if (society.logoUrl != null) 'logo_url': society.logoUrl,
        if (society.bannerUrl != null) 'banner_url': society.bannerUrl,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', society.id);
    } catch (e) {
      AppLogger.error('Failed to update society', e);
      throw ServerFailure('Could not update society: ${e.toString()}');
    }
  }

  @override
  Future<void> grantAdminRole({
    required String societyId,
    required String targetRollNumber,
    required String role,
  }) async {
    try {
      AppLogger.info('Granting society admin role');
      await _client.rpc('grant_society_admin', params: {
        'p_society_id': societyId,
        'p_target_roll_number': targetRollNumber.trim().toUpperCase(),
        'p_role': role,
      });
    } catch (e) {
      AppLogger.error('Failed to grant admin role', e);
      throw ServerFailure(e.toString().replaceAll('Exception: ', ''));
    }
  }

  @override
  Future<void> revokeAdminRole({
    required String societyId,
    required String targetUserId,
  }) async {
    try {
      AppLogger.info('Revoking society admin role');
      await _client.rpc('revoke_society_admin', params: {
        'p_society_id': societyId,
        'p_target_user_id': targetUserId,
      });
    } catch (e) {
      AppLogger.error('Failed to revoke admin role', e);
      throw ServerFailure(e.toString().replaceAll('Exception: ', ''));
    }
  }

  @override
  Future<String> uploadLogo({
    required List<int> fileBytes,
    required String fileName,
    required String mimeType,
  }) async {
    try {
      // 1. Enforce 5 MB cap
      const maxBytes = 5 * 1024 * 1024; // 5 MB
      if (fileBytes.length > maxBytes) {
        throw const ValidationFailure('File size exceeds the 5 MB limit.');
      }

      // 2. Enforce image MIME allowlist
      final allowedMimes = ['image/jpeg', 'image/png', 'image/webp'];
      if (!allowedMimes.contains(mimeType.toLowerCase())) {
        throw const ValidationFailure('Only JPEG, PNG, and WebP images are permitted.');
      }

      // 3. Randomized filename
      final user = _client.auth.currentUser;
      final userId = user?.id ?? 'guest';
      final ext = fileName.split('.').last.toLowerCase();
      final randomToken = Random().nextInt(9999999).toString().padLeft(7, '0');
      final secureFileName = '${DateTime.now().millisecondsSinceEpoch}_$randomToken.$ext';
      final path = 'logos/$userId/$secureFileName';

      // 4. Upload to Supabase Storage bucket 'society-assets'
      await _client.storage.from('society-assets').uploadBinary(
            path,
            Uint8List.fromList(fileBytes),
            fileOptions: FileOptions(
              contentType: mimeType,
              upsert: true,
            ),
          );

      // 5. Retrieve public URL
      return _client.storage.from('society-assets').getPublicUrl(path);
    } on Failure {
      rethrow;
    } catch (e) {
      AppLogger.error('Storage logo upload failed', e);
      throw ServerFailure('Logo upload failed: ${e.toString()}');
    }
  }
}
