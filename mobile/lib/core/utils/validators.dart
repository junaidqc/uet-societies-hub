class Validators {
  /// Strict validation for UET official domain: @uet.edu.pk
  static String? validateUetEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email address is required';
    }
    final trimmed = value.trim().toLowerCase();
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@uet\.edu\.pk$');
    if (!emailRegex.hasMatch(trimmed)) {
      return 'Must be an official @uet.edu.pk email address';
    }
    return null;
  }

  /// Validation for UET Roll Number format (e.g. 2022-CS-101 or 2021-EE-45)
  static String? validateRollNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Roll number is required';
    }
    final trimmed = value.trim().toUpperCase();
    final rollRegex = RegExp(r'^\d{4}-[A-Z0-9]+-\d+$');
    if (!rollRegex.hasMatch(trimmed)) {
      return 'Format must be YYYY-DEPT-ROLL (e.g. 2022-CS-101)';
    }
    return null;
  }

  /// Full name validation
  static String? validateFullName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Full name is required';
    }
    if (value.trim().length < 3) {
      return 'Name must be at least 3 characters';
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

  /// Password validation (min 8 chars, 1 letter, 1 number)
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    if (!RegExp(r'[A-Za-z]').hasMatch(value) || !RegExp(r'\d').hasMatch(value)) {
      return 'Must contain at least one letter and one number';
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
