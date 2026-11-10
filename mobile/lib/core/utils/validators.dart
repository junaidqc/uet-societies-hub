import '../config/supabase_config.dart';

class Validators {
  /// Validation for UET email or user identifier
  static String? validateUetEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email or Roll Number is required';
    }
    final trimmed = value.trim().toLowerCase();
    // Allow either email format or username/roll format (like 2022-cs-101, student, admin)
    if (!trimmed.contains('@')) {
      return null;
    }
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(trimmed)) {
      return 'Please enter a valid email address';
    }
    if (!SupabaseConfig.isDemoHost &&
        !trimmed.endsWith('@uet.edu.pk') &&
        !trimmed.endsWith('@student.uet.edu.pk')) {
      return 'Must be an official @uet.edu.pk or @student.uet.edu.pk email address';
    }
    return null;
  }

  /// Validation for UET Roll Number format (e.g. 2022-CS-101 or 2021-EE-45 or 2022CS101)
  static String? validateRollNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Roll number is required';
    }
    final trimmed = value.trim().toUpperCase();
    final rollRegex = RegExp(r'^\d{4}-?[A-Z0-9]+-?\d+$');
    if (!rollRegex.hasMatch(trimmed) && trimmed.length < 4) {
      return 'Format: e.g. 2022-CS-101 or 2022CS101';
    }
    return null;
  }

  /// Full name validation
  static String? validateFullName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Full name is required';
    }
    if (value.trim().length < 2) {
      return 'Name must be at least 2 characters';
    }
    return null;
  }

  /// Semester validation: 1 to 12
  static String? validateSemester(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Semester is required';
    }
    final sem = int.tryParse(value.trim());
    if (sem == null || sem < 1 || sem > 12) {
      return 'Semester must be between 1 and 12';
    }
    return null;
  }

  /// Department validation
  static String? validateDepartment(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please select or enter your department';
    }
    return null;
  }

  /// Password validation (min 6 chars)
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  /// OTP validation (6 digits)
  static String? validateOtp(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Verification code is required';
    }
    if (value.trim().length != 6 || int.tryParse(value.trim()) == null) {
      return 'Enter the valid 6-digit code';
    }
    return null;
  }
}
