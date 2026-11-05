import '../models/hiring_model.dart';
import '../models/application_model.dart';

abstract class HiringRepository {
  Future<List<HiringModel>> getHirings({String? societyId, bool onlySaved = false});
  Future<HiringModel?> getHiringById(String hiringId);

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
  });

  Future<ApplicationModel> applyToHiring({
    required String hiringId,
    required String position,
    required Map<String, dynamic> answers,
    String? resumeUrl,
  });

  Future<bool> checkHasApplied(String hiringId, String position);

  Future<void> toggleSaveHiring(String hiringId, bool currentlySaved);

  Future<List<ApplicationModel>> getApplications(String hiringId, {String? status, String? position});

  Future<void> updateApplicationStatus({
    required String applicationId,
    required String status,
    String? feedback,
  });

  Future<void> addApplicantToGroup({
    required String applicationId,
    required String groupId,
    String role = 'member',
  });

  Future<List<Map<String, dynamic>>> getSocietyGroups(String societyId);
}
