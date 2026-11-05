import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/app_logger.dart';
import '../domain/models/hiring_model.dart';
import '../domain/models/application_model.dart';
import '../domain/repositories/hiring_repository.dart';

class SupabaseHiringRepository implements HiringRepository {
  final SupabaseClient _client;

  SupabaseHiringRepository(this._client);

  @override
  Future<List<HiringModel>> getHirings({String? societyId, bool onlySaved = false}) async {
    try {
      AppLogger.info('Fetching hirings list sorted by deadline');
      final user = _client.auth.currentUser;

      var query = _client.from('hirings').select('*, societies(name, logo_url), saved_hirings(user_id), applications(user_id)');

      if (societyId != null && societyId.isNotEmpty && societyId != 'All') {
        query = query.eq('society_id', societyId);
      }

      // Single list sorted by deadline (FR-19)
      final response = await query.order('deadline', ascending: true);

      final list = (response as List<dynamic>)
          .map((row) => HiringModel.fromJson(row as Map<String, dynamic>, currentUserId: user?.id))
          .toList();

      if (onlySaved) {
        return list.where((h) => h.isSaved).toList();
      }

      return list;
    } catch (e) {
      AppLogger.error('Error fetching hirings', e);
      throw ServerFailure('Could not load recruitments: ${e.toString()}');
    }
  }

  @override
  Future<HiringModel?> getHiringById(String hiringId) async {
    try {
      final user = _client.auth.currentUser;
      final response = await _client
          .from('hirings')
          .select('*, societies(name, logo_url), saved_hirings(user_id), applications(user_id)')
          .eq('id', hiringId)
          .maybeSingle();

      if (response == null) return null;
      return HiringModel.fromJson(response, currentUserId: user?.id);
    } catch (e) {
      AppLogger.error('Error fetching hiring details', e);
      throw ServerFailure('Could not load hiring details.');
    }
  }

  @override
  Future<HiringModel> createHiring({
    required String societyId,
    required String title,
    required String description,
    required List<String> positions,
    required DateTime deadline,
    required String requirements,
    required String selectionMethod,
    required int totalSeats,
    required List<Map<String, dynamic>> customQuestions,
  }) async {
    try {
      AppLogger.info('Publishing new recruitment post');
      final response = await _client
          .from('hirings')
          .insert({
            'society_id': societyId,
            'title': title.trim(),
            'description': description.trim(),
            'positions': positions,
            'deadline': deadline.toUtc().toIso8601String(),
            'requirements': requirements.trim(),
            'selection_method': selectionMethod,
            'total_seats': totalSeats,
            'custom_questions': customQuestions,
            'status': 'open',
          })
          .select('*, societies(name, logo_url)')
          .single();

      return HiringModel.fromJson(response);
    } catch (e) {
      AppLogger.error('Failed to create hiring post', e);
      throw ServerFailure('Failed to post recruitment: ${e.toString()}');
    }
  }

  @override
  Future<bool> checkHasApplied(String hiringId, String position) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return false;

      final existing = await _client
          .from('applications')
          .select('id')
          .eq('hiring_id', hiringId)
          .eq('user_id', user.id)
          .eq('position', position)
          .maybeSingle();

      return existing != null;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<ApplicationModel> applyToHiring({
    required String hiringId,
    required String position,
    required Map<String, dynamic> answers,
    String? resumeUrl,
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw const AuthFailure('Login required to apply.');
      }

      // Security Rule Check: Duplicate application block (FR-23)
      final hasAlreadyApplied = await checkHasApplied(hiringId, position);
      if (hasAlreadyApplied) {
        throw const ValidationFailure('Duplicate Application: You have already applied for the position of "$position".');
      }

      AppLogger.info('Submitting application for position: $position');
      final response = await _client
          .from('applications')
          .insert({
            'hiring_id': hiringId,
            'user_id': user.id,
            'position': position,
            'answers': answers,
            'resume_url': resumeUrl,
            'status': 'submitted',
          })
          .select('*, profiles(full_name, roll_number, department, semester, email, avatar_url)')
          .single();

      return ApplicationModel.fromJson(response);
    } on Failure {
      rethrow;
    } catch (e) {
      AppLogger.error('Application submission error', e);
      if (e.toString().contains('uq_user_hiring_position') || e.toString().contains('duplicate key')) {
        throw const ValidationFailure('You have already applied for this position.');
      }
      throw ServerFailure('Failed to submit application: ${e.toString()}');
    }
  }

  @override
  Future<void> toggleSaveHiring(String hiringId, bool currentlySaved) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw const AuthFailure('Login required to save opportunities.');
      }

      if (currentlySaved) {
        await _client
            .from('saved_hirings')
            .delete()
            .eq('hiring_id', hiringId)
            .eq('user_id', user.id);
      } else {
        await _client.from('saved_hirings').insert({
          'hiring_id': hiringId,
          'user_id': user.id,
        });
      }
    } catch (e) {
      AppLogger.error('Error toggling saved hiring', e);
      throw ServerFailure('Could not bookmark hiring.');
    }
  }

  @override
  Future<List<ApplicationModel>> getApplications(String hiringId, {String? status, String? position}) async {
    try {
      AppLogger.info('Fetching applications for hiring: $hiringId');
      var query = _client
          .from('applications')
          .select('*, profiles(full_name, roll_number, department, semester, email, avatar_url)')
          .eq('hiring_id', hiringId);

      if (status != null && status != 'All') {
        query = query.eq('status', status);
      }

      if (position != null && position != 'All') {
        query = query.eq('position', position);
      }

      final response = await query.order('created_at', ascending: false);

      return (response as List<dynamic>)
          .map((row) => ApplicationModel.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.error('Failed to get applications', e);
      throw ServerFailure('Could not load applications: ${e.toString()}');
    }
  }

  @override
  Future<void> updateApplicationStatus({
    required String applicationId,
    required String status,
    String? feedback,
  }) async {
    try {
      AppLogger.info('Updating application status via RPC: $status');
      await _client.rpc('update_application_status', params: {
        'p_application_id': applicationId,
        'p_status': status,
        'p_feedback': feedback,
      });
    } catch (e) {
      AppLogger.error('Error updating application status', e);
      throw ServerFailure('Could not update status: ${e.toString()}');
    }
  }

  @override
  Future<void> addApplicantToGroup({
    required String applicationId,
    required String groupId,
    String role = 'member',
  }) async {
    try {
      AppLogger.info('Adding selected applicant to group via RPC');
      await _client.rpc('add_applicant_to_group', params: {
        'p_application_id': applicationId,
        'p_group_id': groupId,
        'p_role': role,
      });
    } catch (e) {
      AppLogger.error('Error onboarding applicant to group', e);
      throw ServerFailure('Could not add to group: ${e.toString()}');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getSocietyGroups(String societyId) async {
    try {
      final response = await _client
          .from('groups')
          .select('id, name, description, is_private')
          .eq('society_id', societyId)
          .order('name');

      return (response as List<dynamic>)
          .map((g) => g as Map<String, dynamic>)
          .toList();
    } catch (e) {
      AppLogger.error('Failed to get society groups', e);
      return [];
    }
  }
}
