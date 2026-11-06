import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/supabase_config.dart';
import '../../../../core/local/local_repositories.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../domain/models/society_model.dart';
import '../../domain/models/office_bearer_model.dart';
import '../../domain/repositories/society_repository.dart';
import '../../data/supabase_society_repository.dart';

final societyRepositoryProvider = Provider<SocietyRepository>((ref) {
  if (SupabaseConfig.isDemoHost) {
    return LocalSocietyRepository();
  }
  return SupabaseSocietyRepository(SupabaseConfig.client);
});

final societyCategoryFilterProvider = StateProvider<String>((ref) => 'All');
final societySearchQueryProvider = StateProvider<String>((ref) => '');

final societiesListProvider = FutureProvider.autoDispose<List<SocietyModel>>((ref) async {
  final repo = ref.watch(societyRepositoryProvider);
  final category = ref.watch(societyCategoryFilterProvider);
  final search = ref.watch(societySearchQueryProvider);
  return repo.getSocieties(category: category, search: search);
});

final pendingSocietiesProvider = FutureProvider.autoDispose<List<SocietyModel>>((ref) async {
  final repo = ref.watch(societyRepositoryProvider);
  return repo.getPendingRequests();
});

final societyDetailProvider = FutureProvider.family.autoDispose<SocietyModel?, String>((ref, id) async {
  final repo = ref.watch(societyRepositoryProvider);
  return repo.getSocietyById(id);
});

final societyOfficeBearersProvider = FutureProvider.family.autoDispose<List<OfficeBearerModel>, String>((ref, id) async {
  final repo = ref.watch(societyRepositoryProvider);
  return repo.getOfficeBearers(id);
});

final userSocietyRoleProvider = FutureProvider.family.autoDispose<String?, String>((ref, societyId) async {
  final user = ref.watch(currentUserProvider);
  if (user == null || user.isGuest) return null;
  final repo = ref.watch(societyRepositoryProvider);
  return repo.getUserSocietyRole(societyId, user.id);
});

class SocietyActionState {
  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;

  const SocietyActionState({
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
  });

  SocietyActionState copyWith({
    bool? isLoading,
    String? errorMessage,
    String? successMessage,
  }) {
    return SocietyActionState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      successMessage: successMessage,
    );
  }
}

class SocietyActionController extends StateNotifier<SocietyActionState> {
  final SocietyRepository _repo;
  final Ref _ref;

  SocietyActionController(this._repo, this._ref) : super(const SocietyActionState());

  Future<bool> toggleFollow(String societyId, bool currentlyFollowed) async {
    try {
      if (currentlyFollowed) {
        await _repo.unfollowSociety(societyId);
      } else {
        await _repo.followSociety(societyId);
      }
      _ref.invalidate(societiesListProvider);
      _ref.invalidate(societyDetailProvider(societyId));
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> submitRegistration({
    required String name,
    required String category,
    required String description,
    String? email,
    String? website,
    Map<String, dynamic>? socialLinks,
    String? logoUrl,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repo.submitRegistrationRequest(
        name: name,
        category: category,
        description: description,
        email: email,
        website: website,
        socialLinks: socialLinks,
        logoUrl: logoUrl,
      );
      state = state.copyWith(
        isLoading: false,
        successMessage: 'Society registration submitted for administrative review!',
      );
      _ref.invalidate(societiesListProvider);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> approveSociety(String societyId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repo.approveSociety(societyId);
      state = state.copyWith(
        isLoading: false,
        successMessage: 'Society approved successfully!',
      );
      _ref.invalidate(pendingSocietiesProvider);
      _ref.invalidate(societiesListProvider);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> rejectSociety(String societyId, String reason) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repo.rejectSociety(societyId, reason);
      state = state.copyWith(
        isLoading: false,
        successMessage: 'Society request rejected.',
      );
      _ref.invalidate(pendingSocietiesProvider);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> updateSociety(SocietyModel society) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repo.updateSociety(society);
      state = state.copyWith(
        isLoading: false,
        successMessage: 'Society profile updated successfully!',
      );
      _ref.invalidate(societyDetailProvider(society.id));
      _ref.invalidate(societiesListProvider);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> grantAdminRole({
    required String societyId,
    required String rollNumber,
    required String role,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repo.grantAdminRole(
        societyId: societyId,
        targetRollNumber: rollNumber,
        role: role,
      );
      state = state.copyWith(
        isLoading: false,
        successMessage: 'Admin rights successfully granted to $rollNumber!',
      );
      _ref.invalidate(societyOfficeBearersProvider(societyId));
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> revokeAdminRole({
    required String societyId,
    required String targetUserId,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repo.revokeAdminRole(
        societyId: societyId,
        targetUserId: targetUserId,
      );
      state = state.copyWith(
        isLoading: false,
        successMessage: 'Admin role revoked.',
      );
      _ref.invalidate(societyOfficeBearersProvider(societyId));
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }
}

final societyActionControllerProvider = StateNotifierProvider<SocietyActionController, SocietyActionState>((ref) {
  final repo = ref.watch(societyRepositoryProvider);
  return SocietyActionController(repo, ref);
});
