import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/supabase_config.dart';
import '../../domain/models/hiring_model.dart';
import '../../domain/models/application_model.dart';
import '../../domain/repositories/hiring_repository.dart';
import '../../data/supabase_hiring_repository.dart';

final hiringRepositoryProvider = Provider<HiringRepository>((ref) {
  return SupabaseHiringRepository(SupabaseConfig.client);
});

final hiringSocietyFilterProvider = StateProvider<String>((ref) => 'All');
final hiringSavedOnlyProvider = StateProvider<bool>((ref) => false);

final hiringsListProvider = FutureProvider.autoDispose<List<HiringModel>>((ref) async {
  final repo = ref.watch(hiringRepositoryProvider);
  final society = ref.watch(hiringSocietyFilterProvider);
  final savedOnly = ref.watch(hiringSavedOnlyProvider);
  return repo.getHirings(societyId: society, onlySaved: savedOnly);
});

final hiringDetailProvider = FutureProvider.family.autoDispose<HiringModel?, String>((ref, id) async {
  final repo = ref.watch(hiringRepositoryProvider);
  return repo.getHiringById(id);
});

class ApplicationFilterParams {
  final String hiringId;
  final String? status;
  final String? position;

  const ApplicationFilterParams({
    required this.hiringId,
    this.status,
    this.position,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ApplicationFilterParams &&
          runtimeType == other.runtimeType &&
          hiringId == other.hiringId &&
          status == other.status &&
          position == other.position;

  @override
  int get hashCode => hiringId.hashCode ^ status.hashCode ^ position.hashCode;
}

final hiringApplicationsProvider = FutureProvider.family.autoDispose<List<ApplicationModel>, ApplicationFilterParams>((ref, params) async {
  final repo = ref.watch(hiringRepositoryProvider);
  return repo.getApplications(
    params.hiringId,
    status: params.status,
    position: params.position,
  );
});

final societyGroupsProvider = FutureProvider.family.autoDispose<List<Map<String, dynamic>>, String>((ref, societyId) async {
  final repo = ref.watch(hiringRepositoryProvider);
  return repo.getSocietyGroups(societyId);
});

class HiringActionState {
  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;

  const HiringActionState({
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
  });

  HiringActionState copyWith({
    bool? isLoading,
    String? errorMessage,
    String? successMessage,
  }) {
    return HiringActionState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      successMessage: successMessage,
    );
  }
}

class HiringActionController extends StateNotifier<HiringActionState> {
  final HiringRepository _repo;
  final Ref _ref;

  HiringActionController(this._repo, this._ref) : super(const HiringActionState());

  Future<bool> toggleSave(String hiringId, bool currentlySaved) async {
    try {
      await _repo.toggleSaveHiring(hiringId, currentlySaved);
      _ref.invalidate(hiringsListProvider);
      _ref.invalidate(hiringDetailProvider(hiringId));
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> applyToHiring({
    required String hiringId,
    required String position,
    required Map<String, dynamic> answers,
    String? resumeUrl,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repo.applyToHiring(
        hiringId: hiringId,
        position: position,
        answers: answers,
        resumeUrl: resumeUrl,
      );
      state = state.copyWith(
        isLoading: false,
        successMessage: 'Application submitted successfully!',
      );
      _ref.invalidate(hiringsListProvider);
      _ref.invalidate(hiringDetailProvider(hiringId));
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  Future<bool> createHiring({
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
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repo.createHiring(
        societyId: societyId,
        title: title,
        description: description,
        positions: positions,
        deadline: deadline,
        requirements: requirements,
        selectionMethod: selectionMethod,
        totalSeats: totalSeats,
        customQuestions: customQuestions,
      );
      state = state.copyWith(
        isLoading: false,
        successMessage: 'Recruitment post published successfully!',
      );
      _ref.invalidate(hiringsListProvider);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> updateStatus({
    required String applicationId,
    required String hiringId,
    required String status,
    String? feedback,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repo.updateApplicationStatus(
        applicationId: applicationId,
        status: status,
        feedback: feedback,
      );
      state = state.copyWith(
        isLoading: false,
        successMessage: 'Applicant status updated to ${status.toUpperCase()}!',
      );
      // Invalidate applications list
      _ref.invalidate(hiringApplicationsProvider);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> addApplicantToGroup({
    required String applicationId,
    required String groupId,
    String role = 'member',
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repo.addApplicantToGroup(
        applicationId: applicationId,
        groupId: groupId,
        role: role,
      );
      state = state.copyWith(
        isLoading: false,
        successMessage: 'Applicant added to committee group!',
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }
}

final hiringActionControllerProvider = StateNotifierProvider<HiringActionController, HiringActionState>((ref) {
  final repo = ref.watch(hiringRepositoryProvider);
  return HiringActionController(repo, ref);
});
