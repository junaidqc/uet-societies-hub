import 'dart:convert';

/// Represents parsed data from a UET Student ID Card or Barcode.
class UetCardData {
  final String rollNumber;
  final String? fullName;
  final String department;
  final int semester;
  final String email;
  final String rawData;

  const UetCardData({
    required this.rollNumber,
    this.fullName,
    required this.department,
    required this.semester,
    required this.email,
    required this.rawData,
  });

  @override
  String toString() {
    return 'UetCardData(roll: $rollNumber, name: $fullName, dept: $department, sem: $semester, email: $email)';
  }
}

/// Intelligent parser for University of Engineering & Technology (UET) Lahore Student ID Cards.
/// Extracts Roll Number, Department, Semester, and official `@uet.edu.pk` Email from barcodes, QR codes, or text.
class UetCardParser {
  // Mapping of UET department abbreviations to standard department names
  static const Map<String, String> _deptMap = {
    'CS': 'Computer Science',
    'SE': 'Software Engineering',
    'EE': 'Electrical Engineering',
    'ME': 'Mechanical Engineering',
    'CE': 'Civil Engineering',
    'CIV': 'Civil Engineering',
    'CH': 'Chemical Engineering',
    'CHE': 'Chemical Engineering',
    'MCT': 'Mechatronics & Control Engineering',
    'MC': 'Mechatronics & Control Engineering',
    'IME': 'Industrial & Manufacturing Engineering',
    'IM': 'Industrial & Manufacturing Engineering',
    'ARCH': 'Architecture',
    'CRP': 'City & Regional Planning',
    'PET': 'Petroleum & Gas Engineering',
    'PE': 'Petroleum & Gas Engineering',
    'MIN': 'Mining Engineering',
    'ENV': 'Environmental Engineering',
    'BBA': 'Management Sciences',
    'PHY': 'Physics',
    'CHEM': 'Chemistry',
    'MATH': 'Mathematics',
  };

  /// Parses raw scanned string from camera barcode or QR code.
  static UetCardData? parse(String input) {
    if (input.trim().isEmpty) return null;
    final text = input.trim();

    // 1. Try JSON parsing if QR contains JSON payload
    if (text.startsWith('{') && text.endsWith('}')) {
      try {
        final Map<String, dynamic> json = jsonDecode(text);
        final roll = json['roll_number'] ?? json['roll'] ?? json['reg_no'] ?? json['reg'];
        if (roll != null) {
          final name = json['full_name'] ?? json['name'];
          return _buildCardData(
            rollStr: roll.toString(),
            nameStr: name?.toString(),
            raw: text,
          );
        }
      } catch (_) {}
    }

    // 2. Multi-line text analysis (e.g., student card OCR or formatted text)
    String? extractedName;
    for (final line in text.split('\n')) {
      final trimmed = line.trim();
      final lower = trimmed.toLowerCase();
      if (lower.startsWith('name:') || lower.startsWith('student name:')) {
        extractedName = trimmed.split(':').last.trim();
      }
    }

    // 3. Regular Expression extraction for UET roll number
    // Matches formats: 2022-CS-101, 2022 CS 101, 2022CS101, 22-CS-101
    final rollRegex = RegExp(
      r'(?:20)?(\d{2})[- ]?([a-zA-Z]{2,5})[- ]?(\d{1,4})',
      caseSensitive: false,
    );

    final match = rollRegex.firstMatch(text);
    if (match != null) {
      final shortYear = match.group(1)!;
      final fullYear = shortYear.length == 2 ? '20$shortYear' : shortYear;
      final deptCode = match.group(2)!.toUpperCase();
      final studentNum = match.group(3)!;

      final normalizedRoll = '$fullYear-$deptCode-$studentNum';
      return _buildCardData(
        rollStr: normalizedRoll,
        nameStr: extractedName,
        raw: text,
      );
    }

    return null;
  }

  static UetCardData _buildCardData({
    required String rollStr,
    String? nameStr,
    required String raw,
  }) {
    final parts = rollStr.toUpperCase().split(RegExp(r'[- ]'));
    final yearStr = parts.isNotEmpty ? parts[0] : '2023';
    final deptCode = parts.length > 1 ? parts[1] : 'CS';
    final numStr = parts.length > 2 ? parts[2] : '01';

    final year = int.tryParse(yearStr) ?? 2023;
    final deptName = _deptMap[deptCode] ?? 'Computer Science';

    // Calculate current semester based on session year
    final now = DateTime.now();
    int currentSemester = ((now.year - year) * 2) + (now.month >= 9 ? 1 : 0);
    if (currentSemester < 1) currentSemester = 1;
    if (currentSemester > 8) currentSemester = 8;

    // Official UET email pattern: e.g. 2022cs101@uet.edu.pk
    final email = '${yearStr}${deptCode.toLowerCase()}${numStr.padLeft(1, '0')}@uet.edu.pk';

    return UetCardData(
      rollNumber: '$yearStr-$deptCode-$numStr',
      fullName: nameStr?.trim(),
      department: deptName,
      semester: currentSemester,
      email: email,
      rawData: raw,
    );
  }

  /// Provides sample student card data for testing or demo purposes.
  static UetCardData getSampleCard() {
    return const UetCardData(
      rollNumber: '2022-CS-101',
      fullName: 'Muhammad Junaid',
      department: 'Computer Science',
      semester: 6,
      email: '2022cs101@uet.edu.pk',
      rawData: '2022-CS-101',
    );
  }
}
