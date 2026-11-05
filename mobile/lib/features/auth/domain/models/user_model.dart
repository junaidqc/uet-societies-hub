class AppUser {
  final String id;
  final String email;
  final String? fullName;
  final String? rollNumber;
  final String? department;
  final int? semester;
  final bool isSystemAdmin;
  final bool isGuest;

  const AppUser({
    required this.id,
    required this.email,
    this.fullName,
    this.rollNumber,
    this.department,
    this.semester,
    this.isSystemAdmin = false,
    this.isGuest = false,
  });

  /// Factory for a Guest User session
  factory AppUser.guest() {
    return const AppUser(
      id: 'guest-session-id',
      email: 'guest@uet.edu.pk',
      fullName: 'Guest Explorer',
      isGuest: true,
    );
  }

  bool get isAuthenticated => !isGuest;
}
