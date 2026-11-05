import '../models/profile_model.dart';

abstract class ProfileRepository {
  Future<StudentProfile?> getProfile(String userId);
  Future<void> updateProfile({
    required String userId,
    required String fullName,
    required int semester,
    String? bio,
    String? phoneNumber,
    String? avatarUrl,
  });
}
