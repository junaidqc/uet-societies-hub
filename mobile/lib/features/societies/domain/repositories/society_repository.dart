import '../models/society_model.dart';
import '../models/office_bearer_model.dart';

abstract class SocietyRepository {
  Future<List<SocietyModel>> getSocieties({String? category, String? search});
  Future<List<SocietyModel>> getPendingRequests();
  Future<SocietyModel?> getSocietyById(String id);
  Future<String?> getUserSocietyRole(String societyId, String userId);
  Future<List<OfficeBearerModel>> getOfficeBearers(String societyId);

  Future<SocietyModel> submitRegistrationRequest({
    required String name,
    required String category,
    required String description,
    String? email,
    String? website,
    Map<String, dynamic>? socialLinks,
    String? logoUrl,
  });

  Future<void> approveSociety(String societyId);
  Future<void> rejectSociety(String societyId, String reason);

  Future<void> followSociety(String societyId);
  Future<void> unfollowSociety(String societyId);

  Future<void> updateSociety(SocietyModel society);
  Future<void> grantAdminRole({
    required String societyId,
    required String targetRollNumber,
    required String role,
  });
  Future<void> revokeAdminRole({
    required String societyId,
    required String targetUserId,
  });

  Future<String> uploadLogo({
    required List<int> fileBytes,
    required String fileName,
    required String mimeType,
  });
}
