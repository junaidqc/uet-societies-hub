import '../models/user_model.dart';

abstract class AuthRepository {
  Stream<AppUser?> get authStateChanges;
  AppUser? get currentUser;
  bool get isGuest;

  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
    required String rollNumber,
    required String department,
    required int semester,
  });

  Future<void> verifyEmailOtp({
    required String email,
    required String token,
  });

  Future<void> signIn({
    required String email,
    required String password,
  });

  Future<void> sendPasswordResetOtp({
    required String email,
  });

  Future<void> resetPasswordWithOtp({
    required String email,
    required String token,
    required String newPassword,
  });

  Future<void> continueAsGuest();

  Future<void> signOut();
}
