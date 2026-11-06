import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/app_logger.dart';
import '../../domain/models/user_model.dart';
import '../../domain/repositories/auth_repository.dart';

class SupabaseAuthRepository implements AuthRepository {
  final SupabaseClient _client;
  bool _guestSessionActive = false;
  final _authStateController = StreamController<AppUser?>.broadcast();

  SupabaseAuthRepository(this._client) {
    _client.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      if (session != null) {
        _guestSessionActive = false;
        _authStateController.add(_mapUser(session.user));
      } else if (_guestSessionActive) {
        _authStateController.add(AppUser.guest());
      } else {
        _authStateController.add(null);
      }
    });
  }

  @override
  Stream<AppUser?> get authStateChanges => _authStateController.stream;

  @override
  AppUser? get currentUser {
    final supaUser = _client.auth.currentUser;
    if (supaUser != null) {
      return _mapUser(supaUser);
    }
    if (_guestSessionActive) {
      return AppUser.guest();
    }
    return null;
  }

  @override
  bool get isGuest => _guestSessionActive && _client.auth.currentUser == null;

  @override
  Future<void> continueAsGuest() async {
    _guestSessionActive = true;
    _authStateController.add(AppUser.guest());
  }

  @override
  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
    required String rollNumber,
    required String department,
    required int semester,
  }) async {
    try {
      _guestSessionActive = false;
      AppLogger.info('Attempting registration for roll: $rollNumber');

      await _client.auth.signUp(
        email: email.trim().toLowerCase(),
        password: password,
        data: {
          'full_name': fullName.trim(),
          'roll_number': rollNumber.trim().toUpperCase(),
          'department': department.trim(),
          'semester': semester,
        },
      );
    } on AuthException catch (e) {
      AppLogger.error('AuthException during registration: ${e.message}');
      throw AuthFailure(e.message);
    } catch (e) {
      AppLogger.error('Unexpected error during registration', e);
      final errorStr = e.toString();
      if (errorStr.contains('Failed host lookup') || errorStr.contains('No address associated with hostname')) {
        throw const ServerFailure(
          'Could not connect to Supabase backend (Host lookup failed). Tap the Database/Cloud icon at the top to configure your active Supabase URL & Anon Key.',
        );
      }
      throw ServerFailure('Registration failed: ${e.toString()}');
    }
  }

  @override
  Future<void> verifyEmailOtp({
    required String email,
    required String token,
  }) async {
    try {
      AppLogger.info('Verifying email OTP for account verification');
      final response = await _client.auth.verifyOTP(
        email: email.trim().toLowerCase(),
        token: token.trim(),
        type: OtpType.signup,
      );

      if (response.user == null) {
        throw const AuthFailure('Invalid or expired verification code.');
      }
      _guestSessionActive = false;
    } on AuthException catch (e) {
      AppLogger.error('OTP Verification AuthException: ${e.message}');
      throw AuthFailure(e.message);
    } catch (e) {
      AppLogger.error('OTP Verification unexpected error', e);
      throw const AuthFailure('Verification failed. Please check the code and try again.');
    }
  }

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    try {
      _guestSessionActive = false;
      AppLogger.info('Signing in student');
      await _client.auth.signInWithPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
    } on AuthException catch (e) {
      AppLogger.error('SignIn AuthException: ${e.message}');
      throw AuthFailure(e.message);
    } catch (e) {
      AppLogger.error('SignIn error', e);
      final errorStr = e.toString();
      if (errorStr.contains('Failed host lookup') || errorStr.contains('No address associated with hostname')) {
        throw const ServerFailure(
          'Could not connect to Supabase backend (Host lookup failed). Tap the Database/Cloud icon at the top to configure your active Supabase URL & Anon Key.',
        );
      }
      throw const ServerFailure('Login failed. Please verify credentials.');
    }
  }

  @override
  Future<void> sendPasswordResetOtp({required String email}) async {
    try {
      AppLogger.info('Sending password reset code');
      await _client.auth.resetPasswordForEmail(
        email.trim().toLowerCase(),
      );
    } on AuthException catch (e) {
      AppLogger.error('Password reset request failed: ${e.message}');
      throw AuthFailure(e.message);
    } catch (e) {
      throw const ServerFailure('Could not send reset code. Please try again.');
    }
  }

  @override
  Future<void> resetPasswordWithOtp({
    required String email,
    required String token,
    required String newPassword,
  }) async {
    try {
      AppLogger.info('Verifying recovery OTP and resetting password');
      final verifyResponse = await _client.auth.verifyOTP(
        email: email.trim().toLowerCase(),
        token: token.trim(),
        type: OtpType.recovery,
      );

      if (verifyResponse.user == null) {
        throw const AuthFailure('Invalid recovery code.');
      }

      await _client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
    } on AuthException catch (e) {
      AppLogger.error('Reset password AuthException: ${e.message}');
      throw AuthFailure(e.message);
    } catch (e) {
      throw const ServerFailure('Password update failed.');
    }
  }

  @override
  Future<void> signOut() async {
    _guestSessionActive = false;
    try {
      await _client.auth.signOut();
    } catch (e) {
      AppLogger.error('SignOut error', e);
    } finally {
      _authStateController.add(null);
    }
  }

  AppUser _mapUser(User user) {
    final meta = user.userMetadata ?? {};
    return AppUser(
      id: user.id,
      email: user.email ?? '',
      fullName: meta['full_name'] as String?,
      rollNumber: meta['roll_number'] as String?,
      department: meta['department'] as String?,
      semester: (meta['semester'] as num?)?.toInt(),
      isSystemAdmin: meta['is_system_admin'] == true,
      isGuest: false,
    );
  }
}
