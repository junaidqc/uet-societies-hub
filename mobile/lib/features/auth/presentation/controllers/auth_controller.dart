import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/supabase_config.dart';
import '../../domain/models/user_model.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../data/repositories/supabase_auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return SupabaseAuthRepository(SupabaseConfig.client);
});

final authStateProvider = StreamProvider<AppUser?>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return repo.authStateChanges;
});

final currentUserProvider = Provider<AppUser?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.value ?? ref.watch(authRepositoryProvider).currentUser;
});

class AuthState {
  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;
  final String? pendingVerificationEmail;

  const AuthState({
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
    this.pendingVerificationEmail,
  });

  AuthState copyWith({
    bool? isLoading,
    String? errorMessage,
    String? successMessage,
    String? pendingVerificationEmail,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      successMessage: successMessage,
      pendingVerificationEmail: pendingVerificationEmail ?? this.pendingVerificationEmail,
    );
  }
}

class AuthController extends StateNotifier<AuthState> {
  final AuthRepository _repository;

  AuthController(this._repository) : super(const AuthState());

  void clearMessages() {
    state = state.copyWith(errorMessage: null, successMessage: null);
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String fullName,
    required String rollNumber,
    required String department,
    required int semester,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repository.signUp(
        email: email,
        password: password,
        fullName: fullName,
        rollNumber: rollNumber,
        department: department,
        semester: semester,
      );
      state = state.copyWith(
        isLoading: false,
        pendingVerificationEmail: email,
        successMessage: 'Verification code sent to $email',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  Future<bool> verifyEmailOtp({
    required String email,
    required String token,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repository.verifyEmailOtp(email: email, token: token);
      state = state.copyWith(
        isLoading: false,
        successMessage: 'Email successfully verified! Welcome to UET Societies Hub.',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repository.signIn(email: email, password: password);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  Future<bool> sendPasswordResetOtp({required String email}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repository.sendPasswordResetOtp(email: email);
      state = state.copyWith(
        isLoading: false,
        pendingVerificationEmail: email,
        successMessage: 'Password reset code sent to your email.',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  Future<bool> resetPasswordWithOtp({
    required String email,
    required String token,
    required String newPassword,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repository.resetPasswordWithOtp(
        email: email,
        token: token,
        newPassword: newPassword,
      );
      state = state.copyWith(
        isLoading: false,
        successMessage: 'Password successfully updated! Please log in.',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  Future<void> continueAsGuest() async {
    await _repository.continueAsGuest();
  }

  Future<void> signOut() async {
    await _repository.signOut();
  }
}

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return AuthController(repo);
});
