import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/supabase_config.dart';
import '../../../../core/local/local_repositories.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../domain/models/profile_model.dart';
import '../../domain/repositories/profile_repository.dart';
import '../../data/supabase_profile_repository.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  if (SupabaseConfig.isDemoHost) {
    return LocalProfileRepository();
  }
  return SupabaseProfileRepository(SupabaseConfig.client);
});

final currentProfileProvider = FutureProvider.autoDispose<StudentProfile?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null || user.isGuest) {
    return null;
  }
  final repo = ref.watch(profileRepositoryProvider);
  return repo.getProfile(user.id);
});

class ProfileEditState {
  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;

  const ProfileEditState({
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
  });

  ProfileEditState copyWith({
    bool? isLoading,
    String? errorMessage,
    String? successMessage,
  }) {
    return ProfileEditState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      successMessage: successMessage,
    );
  }
}

class ProfileController extends StateNotifier<ProfileEditState> {
  final ProfileRepository _repository;
  final Ref _ref;

  ProfileController(this._repository, this._ref) : super(const ProfileEditState());

  Future<bool> updateProfile({
    required String userId,
    required String fullName,
    required int semester,
    String? bio,
    String? phoneNumber,
    String? avatarUrl,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null, successMessage: null);
    try {
      await _repository.updateProfile(
        userId: userId,
        fullName: fullName,
        semester: semester,
        bio: bio,
        phoneNumber: phoneNumber,
        avatarUrl: avatarUrl,
      );
      state = state.copyWith(
        isLoading: false,
        successMessage: 'Profile updated successfully!',
      );
      _ref.invalidate(currentProfileProvider);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
      return false;
    }
  }
}

final profileControllerProvider = StateNotifierProvider<ProfileController, ProfileEditState>((ref) {
  final repo = ref.watch(profileRepositoryProvider);
  return ProfileController(repo, ref);
});
