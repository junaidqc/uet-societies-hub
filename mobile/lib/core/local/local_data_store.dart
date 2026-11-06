import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../features/auth/domain/models/user_model.dart';
import '../../features/profile/domain/models/profile_model.dart';
import '../../features/societies/domain/models/society_model.dart';
import '../../features/societies/domain/models/office_bearer_model.dart';
import '../../features/feed/domain/models/post_model.dart';
import '../../features/feed/domain/models/comment_model.dart';
import '../../features/feed/domain/models/event_model.dart';
import '../../features/hiring/domain/models/hiring_model.dart';
import '../../features/hiring/domain/models/application_model.dart';
import '../../features/groups/domain/models/group_model.dart';
import '../../features/groups/domain/models/group_message_model.dart';
import '../../features/groups/domain/models/poll_and_task_models.dart';

/// Autonomous Local Data Store & Engine
/// Provides complete in-memory & persistent mock database for UET Societies Hub.
/// Allows full offline functionality without any dependency on external cloud servers.
class LocalDataStore {
  static final LocalDataStore _instance = LocalDataStore._internal();
  factory LocalDataStore() => _instance;

  LocalDataStore._internal() {
    _initSampleData();
  }

  // --- Auth & Session State ---
  AppUser? _currentUser;
  bool _isGuest = false;
  final _authStreamController = StreamController<AppUser?>.broadcast();

  Stream<AppUser?> get authStateChanges => _authStreamController.stream;
  AppUser? get currentUser => _currentUser;
  bool get isGuest => _isGuest;

  // --- Tables / Entities ---
  final List<AppUser> _users = [];
  final Map<String, StudentProfile> _profiles = {};
  final List<SocietyModel> _societies = [];
  final List<SocietyModel> _pendingSocieties = [];
  final Map<String, List<OfficeBearerModel>> _officeBearers = {};
  final Set<String> _followedSocieties = {'soc-acm', 'soc-ieee'};
  final Map<String, Map<String, String>> _societyRoles = {}; // societyId -> (userId -> role)

  final List<PostModel> _posts = [];
  final Map<String, List<CommentModel>> _comments = {};
  final Set<String> _likedPostIds = {'post-1'};
  final List<EventModel> _events = [];
  final Set<String> _interestedEventIds = {'event-1'};

  final List<HiringModel> _hirings = [];
  final Set<String> _savedHiringIds = {'hiring-1'};
  final List<ApplicationModel> _applications = [];

  final List<GroupModel> _groups = [];
  final Map<String, List<GroupMemberModel>> _groupMembers = {};
  final Map<String, List<GroupMessageModel>> _groupMessages = {};
  final Map<String, StreamController<List<GroupMessageModel>>> _groupMessageStreams = {};

  final List<Map<String, dynamic>> _notifications = [];

  void _initSampleData() {
    // 1. Pre-configure Sample Student User
    final defaultStudent = const AppUser(
      id: 'usr-student-1',
      email: '2022cs101@uet.edu.pk',
      fullName: 'Muhammad Junaid',
      rollNumber: '2022-CS-101',
      department: 'Computer Science',
      semester: 6,
      isSystemAdmin: false,
    );
    _currentUser = defaultStudent;
    _users.add(defaultStudent);

    // Additional sample users
    final adminUser = const AppUser(
      id: 'usr-admin-1',
      email: 'admin@uet.edu.pk',
      fullName: 'Dr. Muhammad Tahir',
      rollNumber: 'FAC-DIR-01',
      department: 'Computer Science',
      semester: 12,
      isSystemAdmin: true,
    );
    final presidentUser = const AppUser(
      id: 'usr-president-1',
      email: 'president.acm@uet.edu.pk',
      fullName: 'Hamza Ali',
      rollNumber: '2021-CS-45',
      department: 'Computer Science',
      semester: 8,
      isSystemAdmin: false,
    );
    _users.addAll([adminUser, presidentUser]);

    // Student profile
    _profiles['usr-student-1'] = StudentProfile(
      id: 'usr-student-1',
      fullName: 'Muhammad Junaid',
      rollNumber: '2022-CS-101',
      department: 'Computer Science',
      semester: 6,
      email: '2022cs101@uet.edu.pk',
      bio: 'Junior Developer & AI enthusiast at UET Lahore. Active in societies and hackathons.',
      phoneNumber: '+92 300 1234567',
    );

    // 2. Pre-configure Societies
    final now = DateTime.now();
    _societies.addAll([
      SocietyModel(
        id: 'soc-acm',
        name: 'ACM UET Lahore Student Chapter',
        slug: 'acm-uet',
        category: 'Technical',
        description: 'Empowering computing students with competitive programming, hackathons, and software engineering workshops.',
        logoUrl: 'https://images.unsplash.com/photo-1517694712202-14dd9538aa97?w=150',
        followersCount: 480,
        isFollowed: true,
        email: 'acm@uet.edu.pk',
        website: 'https://acm.uet.edu.pk',
        createdAt: now.subtract(const Duration(days: 365)),
        updatedAt: now,
      ),
      SocietyModel(
        id: 'soc-ieee',
        name: 'IEEE UET Student Branch',
        slug: 'ieee-uet',
        category: 'Engineering',
        description: 'Advancing technology for humanity. World-class conferences, robotics challenges, and research seminars.',
        logoUrl: 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=150',
        followersCount: 620,
        isFollowed: true,
        email: 'ieee@uet.edu.pk',
        website: 'https://ieee.uet.edu.pk',
        createdAt: now.subtract(const Duration(days: 400)),
        updatedAt: now,
      ),
      SocietyModel(
        id: 'soc-bds',
        name: 'Blood Donating Society (BDS UET)',
        slug: 'bds-uet',
        category: 'Social / Welfare',
        description: 'Non-profit student volunteer corps dedicated to saving lives across Lahore hospitals with 24/7 emergency blood donation.',
        logoUrl: 'https://images.unsplash.com/photo-1615461066841-6116e61058f4?w=150',
        followersCount: 890,
        isFollowed: true,
        email: 'bds@uet.edu.pk',
        createdAt: now.subtract(const Duration(days: 500)),
        updatedAt: now,
      ),
      SocietyModel(
        id: 'soc-lds',
        name: 'Literary & Debating Society (LDS)',
        slug: 'lds-uet',
        category: 'Literary',
        description: 'The premier debating, public speaking, and declamation society representing UET nationwide.',
        logoUrl: 'https://images.unsplash.com/photo-1455390582262-044cdead277a?w=150',
        followersCount: 340,
        isFollowed: false,
        email: 'lds@uet.edu.pk',
        createdAt: now.subtract(const Duration(days: 200)),
        updatedAt: now,
      ),
      SocietyModel(
        id: 'soc-eps',
        name: 'Environmental Protection Society (EPS)',
        slug: 'eps-uet',
        category: 'Environmental',
        description: 'Campaigning for clean air, renewable campus solutions, tree plantation drives, and green engineering.',
        logoUrl: 'https://images.unsplash.com/photo-1542601906990-b4d3fb778b09?w=150',
        followersCount: 295,
        isFollowed: false,
        email: 'eps@uet.edu.pk',
        createdAt: now.subtract(const Duration(days: 150)),
        updatedAt: now,
      ),
      SocietyModel(
        id: 'soc-dramatics',
        name: 'UET Dramatics Society',
        slug: 'dramatics-uet',
        category: 'Arts & Culture',
        description: 'Inspiring artistic expression, stage plays, acting workshops, and campus cultural performances.',
        logoUrl: 'https://images.unsplash.com/photo-1507676184212-d03ab07a01bf?w=150',
        followersCount: 410,
        isFollowed: false,
        email: 'dramatics@uet.edu.pk',
        createdAt: now.subtract(const Duration(days: 300)),
        updatedAt: now,
      ),
    ]);

    // Roles: Student has roles in ACM and IEEE
    _societyRoles['soc-acm'] = {
      'usr-president-1': 'president',
      'usr-student-1': 'admin',
    };
    _societyRoles['soc-ieee'] = {
      'usr-student-1': 'member',
    };

    // Office Bearers
    _officeBearers['soc-acm'] = [
      OfficeBearerModel(
        id: 'ob-1',
        societyId: 'soc-acm',
        userId: 'usr-president-1',
        fullName: 'Hamza Ali',
        role: 'President',
        rollNumber: '2021-CS-45',
        department: 'Computer Science',
        appointmentDate: now.subtract(const Duration(days: 120)),
      ),
      OfficeBearerModel(
        id: 'ob-2',
        societyId: 'soc-acm',
        userId: 'usr-student-1',
        fullName: 'Muhammad Junaid',
        role: 'Technical Lead',
        rollNumber: '2022-CS-101',
        department: 'Computer Science',
        appointmentDate: now.subtract(const Duration(days: 90)),
      ),
    ];

    // 3. Pre-configure Feed Posts
    _posts.addAll([
      PostModel(
        id: 'post-1',
        societyId: 'soc-acm',
        authorId: 'usr-president-1',
        title: 'TechnoFest 2026 Registration is now LIVE! 🚀',
        content: 'ACM UET Lahore proudly presents TechnoFest 2026 — Pakistan’s largest university tech symposium! Featuring competitive programming, speed debugging, AI agent showcase, and UI design sprint. Over PKR 500,000 in prizes!\n\nSign up today through the Hiring & Events portal.',
        societyName: 'ACM UET Lahore Student Chapter',
        authorName: 'Hamza Ali (President)',
        isPinned: true,
        isPublic: true,
        likesCount: 52,
        commentsCount: 3,
        isLiked: true,
        canManage: true,
        createdAt: now.subtract(const Duration(hours: 4)),
        updatedAt: now,
      ),
      PostModel(
        id: 'post-2',
        societyId: 'soc-ieee',
        authorId: 'usr-admin-1',
        title: 'IEEE Hands-On Workshop: Deep Learning with PyTorch',
        content: 'Join us this Friday at CS Lab 3 for an intensive workshop on Convolutional Neural Networks and Transformers. Open to all engineering students. Certificates will be awarded.',
        societyName: 'IEEE UET Student Branch',
        authorName: 'Dr. Muhammad Tahir',
        isPinned: false,
        isPublic: true,
        likesCount: 38,
        commentsCount: 1,
        isLiked: false,
        canManage: false,
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now,
      ),
      PostModel(
        id: 'post-3',
        societyId: 'soc-bds',
        authorId: 'usr-president-1',
        title: 'Annual Blood Donation Camp 2026 Scheduled',
        content: 'Give the gift of life! BDS UET will be hosting the annual blood donation drive in collaboration with Fatimid Foundation and Sundas Foundation at Student Center Lawn.',
        societyName: 'Blood Donating Society (BDS UET)',
        authorName: 'BDS Executive Team',
        isPinned: false,
        isPublic: true,
        likesCount: 89,
        commentsCount: 2,
        isLiked: false,
        canManage: false,
        createdAt: now.subtract(const Duration(days: 2)),
        updatedAt: now,
      ),
    ]);

    _comments['post-1'] = [
      CommentModel(
        id: 'cmt-1',
        postId: 'post-1',
        authorId: 'usr-student-1',
        authorName: 'Muhammad Junaid',
        content: 'Excited for the AI Agent hackathon! Will registration be open for freshers?',
        createdAt: now.subtract(const Duration(hours: 3)),
      ),
      CommentModel(
        id: 'cmt-2',
        postId: 'post-1',
        authorId: 'usr-president-1',
        authorName: 'Hamza Ali',
        content: 'Yes! Freshers have a dedicated track with beginner-friendly mentorship.',
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
    ];

    // 4. Pre-configure Events
    _events.addAll([
      EventModel(
        id: 'event-1',
        societyId: 'soc-acm',
        title: 'TechnoFest 2026: 48-Hour Hackathon',
        description: 'Build impactful AI, Web3, and mobile software in a 48-hour continuous hackathon challenge with industry judges.',
        venue: 'Main Auditorium & CS Labs',
        startTime: now.add(const Duration(days: 5, hours: 9)),
        endTime: now.add(const Duration(days: 7, hours: 18)),
        societyName: 'ACM UET Lahore Student Chapter',
        interestedCount: 135,
        isInterested: true,
      ),
      EventModel(
        id: 'event-2',
        societyId: 'soc-ieee',
        title: 'RoboQuest 2026: Line Following & Maze Solver',
        description: 'Test your embedded robotics and sensor design skills against the best teams from universities across Punjab.',
        venue: 'Electrical Engineering Lawn',
        startTime: now.add(const Duration(days: 12, hours: 10)),
        endTime: now.add(const Duration(days: 12, hours: 16)),
        societyName: 'IEEE UET Student Branch',
        interestedCount: 78,
        isInterested: false,
      ),
      EventModel(
        id: 'event-3',
        societyId: 'soc-bds',
        title: 'Mega Blood Donation Camp',
        description: 'Doctors and sterile collection units on site. All donors receive free blood screening reports and certificate.',
        venue: 'Student Center Ground',
        startTime: now.add(const Duration(days: 2, hours: 10)),
        endTime: now.add(const Duration(days: 2, hours: 17)),
        societyName: 'Blood Donating Society (BDS UET)',
        interestedCount: 195,
        isInterested: false,
      ),
    ]);

    // 5. Pre-configure Hirings
    _hirings.addAll([
      HiringModel(
        id: 'hiring-1',
        societyId: 'soc-acm',
        societyName: 'ACM UET Lahore Student Chapter',
        title: 'ACM Core Executive Council Recruitment Fall 2026',
        description: 'Join the team driving the largest student tech community at UET Lahore. We are hiring passionate individuals across multiple domains.',
        positions: ['Technical Lead (Flutter/Python)', 'UI/UX Designer', 'PR & Social Media Manager', 'Event Executive'],
        deadline: now.add(const Duration(days: 8)),
        status: 'open',
        requirements: 'Active student of UET Lahore (Semester 2-6). Good communication skills and passion for technology.',
        selectionMethod: 'Interview & Practical Task',
        totalSeats: 15,
        customQuestions: [
          {'question': 'Why do you want to join ACM UET?', 'type': 'text'},
          {'question': 'Portfolio or GitHub profile link (if applying for Tech/Design)', 'type': 'text'},
          {'question': 'Prior event management experience?', 'type': 'text'},
        ],
        isSaved: true,
        hasApplied: true,
        createdAt: now.subtract(const Duration(days: 2)),
      ),
      HiringModel(
        id: 'hiring-2',
        societyId: 'soc-ieee',
        societyName: 'IEEE UET Student Branch',
        title: 'IEEE Media, Logistics & Design Team Hiring',
        description: 'Be the creative voice and organizational engine behind national engineering conferences and robot exhibitions.',
        positions: ['Video Editor & Animator', 'Graphic Designer', 'Logistics Coordinator'],
        deadline: now.add(const Duration(days: 5)),
        status: 'open',
        requirements: 'Proficiency in Adobe Premier/AfterEffects or Figma/Canva.',
        selectionMethod: 'Portfolio Review',
        totalSeats: 8,
        customQuestions: [
          {'question': 'Link to your design/video portfolio', 'type': 'text'},
        ],
        isSaved: false,
        hasApplied: false,
        createdAt: now.subtract(const Duration(days: 3)),
      ),
      HiringModel(
        id: 'hiring-3',
        societyId: 'soc-bds',
        societyName: 'Blood Donating Society (BDS UET)',
        title: 'Emergency Response Volunteer Wing 2026',
        description: 'Volunteers required to coordinate blood drives, handle hospital emergency dispatch calls, and manage donor logs.',
        positions: ['Emergency Dispatcher', 'Camp Coordinator', 'Social Media Lead'],
        deadline: now.add(const Duration(days: 14)),
        status: 'open',
        requirements: 'Dedicated, empathetic, and available on campus during study sessions.',
        selectionMethod: 'Personal Interview',
        totalSeats: 20,
        customQuestions: [
          {'question': 'Can you respond to urgent calls during campus hours?', 'type': 'text'},
        ],
        isSaved: false,
        hasApplied: false,
        createdAt: now.subtract(const Duration(days: 1)),
      ),
    ]);

    // 6. Pre-configure Applications
    _applications.add(
      ApplicationModel(
        id: 'app-1',
        hiringId: 'hiring-1',
        userId: 'usr-student-1',
        position: 'Technical Lead (Flutter/Python)',
        status: 'shortlisted',
        answers: {
          'Why do you want to join ACM UET?': 'I love building software and want to contribute to the developer ecosystem at UET.',
          'Portfolio or GitHub profile link': 'https://github.com/junaidqc',
        },
        feedback: 'Strong technical profile with excellent Flutter and Python skills. Scheduled for panel interview.',
        createdAt: now.subtract(const Duration(days: 1)),
        applicantName: 'Muhammad Junaid',
        applicantRoll: '2022-CS-101',
        applicantDept: 'Computer Science',
        applicantSemester: 6,
        applicantEmail: '2022cs101@uet.edu.pk',
      ),
    );

    // 7. Pre-configure Groups & Chat
    final acmGroup = GroupModel(
      id: 'grp-acm-core',
      societyId: 'soc-acm',
      societyName: 'ACM UET Lahore Student Chapter',
      name: 'ACM Executive Council 2026',
      description: 'Official collaboration channel for ACM UET office bearers and event leads.',
      isPrivate: true,
      createdAt: now.subtract(const Duration(days: 30)),
      memberCount: 14,
    );
    _groups.add(acmGroup);

    _groupMembers['grp-acm-core'] = [
      GroupMemberModel(
        id: 'gm-1',
        groupId: 'grp-acm-core',
        userId: 'usr-president-1',
        role: 'admin',
        joinedAt: now.subtract(const Duration(days: 30)),
        fullName: 'Hamza Ali',
        email: 'president.acm@uet.edu.pk',
        rollNumber: '2021-CS-45',
      ),
      GroupMemberModel(
        id: 'gm-2',
        groupId: 'grp-acm-core',
        userId: 'usr-student-1',
        role: 'member',
        joinedAt: now.subtract(const Duration(days: 20)),
        fullName: 'Muhammad Junaid',
        email: '2022cs101@uet.edu.pk',
        rollNumber: '2022-CS-101',
      ),
    ];

    _groupMessages['grp-acm-core'] = [
      GroupMessageModel(
        id: 'msg-1',
        groupId: 'grp-acm-core',
        senderId: 'usr-president-1',
        senderName: 'Hamza Ali',
        content: 'Welcome everyone! The venue booking for TechnoFest 2026 has been approved by DSA.',
        messageType: 'text',
        createdAt: now.subtract(const Duration(hours: 6)),
      ),
      GroupMessageModel(
        id: 'msg-2',
        groupId: 'grp-acm-core',
        senderId: 'usr-president-1',
        senderName: 'Hamza Ali',
        content: 'TechnoFest Kickoff Schedule',
        messageType: 'poll',
        poll: const PollModel(
          question: 'Vote for the best day to host the opening keynote:',
          options: [
            'Friday Afternoon (3:00 PM)',
            'Saturday Morning (10:00 AM)',
          ],
          votes: {'usr-president-1': 1, 'usr-student-1': 1},
        ),
        createdAt: now.subtract(const Duration(hours: 4)),
      ),
      GroupMessageModel(
        id: 'msg-3',
        groupId: 'grp-acm-core',
        senderId: 'usr-president-1',
        senderName: 'Hamza Ali',
        content: 'Task: Prepare Registration Booth & Badges',
        messageType: 'task',
        task: TaskModel(
          title: 'Prepare Registration Booth & Badges',
          description: 'Coordinate with DSA for sound system & desk placement.',
          assignedTo: 'usr-student-1',
          assignedToName: 'Technical & Event Leads',
          dueDate: now.add(const Duration(days: 3)),
          isCompleted: false,
        ),
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
      GroupMessageModel(
        id: 'msg-4',
        groupId: 'grp-acm-core',
        senderId: 'usr-student-1',
        senderName: 'Muhammad Junaid',
        content: 'Got it! I am finalizing the QR verification portal for badges.',
        messageType: 'text',
        createdAt: now.subtract(const Duration(minutes: 45)),
      ),
    ];

    // 8. Pre-configure Notifications
    _notifications.addAll([
      {
        'id': 'notif-1',
        'title': 'Welcome to UET Societies Hub!',
        'body': 'Your student profile is active. Discover events, browse societies, and apply for recruitments.',
        'created_at': now.subtract(const Duration(hours: 1)).toIso8601String(),
        'is_read': false,
      },
      {
        'id': 'notif-2',
        'title': 'Application Shortlisted 🎯',
        'body': 'ACM UET shortlisted your application for Technical Lead (Flutter/Python).',
        'created_at': now.subtract(const Duration(hours: 3)).toIso8601String(),
        'is_read': false,
      },
      {
        'id': 'notif-3',
        'title': 'New Event Announced',
        'body': 'IEEE UET announced "Deep Learning with PyTorch" workshop for Friday.',
        'created_at': now.subtract(const Duration(days: 1)).toIso8601String(),
        'is_read': true,
      },
    ]);
  }

  // =========================================================================
  // Auth Operations
  // =========================================================================

  Future<void> signIn({required String email, required String password}) async {
    final cleanEmail = email.trim().toLowerCase();
    _isGuest = false;

    // Check if user exists
    final found = _users.firstWhere(
      (u) => u.email.toLowerCase() == cleanEmail,
      orElse: () {
        // Automatically create a valid user session for any UET email entered
        final rollGuess = cleanEmail.split('@').first.toUpperCase();
        final newUser = AppUser(
          id: 'usr-${DateTime.now().millisecondsSinceEpoch}',
          email: cleanEmail,
          fullName: 'UET Student ($rollGuess)',
          rollNumber: rollGuess,
          department: 'Engineering',
          semester: 4,
          isSystemAdmin: cleanEmail.contains('admin'),
        );
        _users.add(newUser);
        return newUser;
      },
    );

    _currentUser = found;
    _authStreamController.add(_currentUser);
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
    required String rollNumber,
    required String department,
    required int semester,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    _isGuest = false;

    final newUser = AppUser(
      id: 'usr-${DateTime.now().millisecondsSinceEpoch}',
      email: cleanEmail,
      fullName: fullName,
      rollNumber: rollNumber,
      department: department,
      semester: semester,
      isSystemAdmin: cleanEmail.contains('admin'),
    );

    _users.removeWhere((u) => u.email.toLowerCase() == cleanEmail);
    _users.add(newUser);
    _currentUser = newUser;

    _profiles[newUser.id] = StudentProfile(
      id: newUser.id,
      fullName: fullName,
      rollNumber: rollNumber,
      department: department,
      semester: semester,
      email: cleanEmail,
    );

    _authStreamController.add(_currentUser);
  }

  Future<void> continueAsGuest() async {
    _isGuest = true;
    _currentUser = AppUser.guest();
    _authStreamController.add(_currentUser);
  }

  Future<void> signOut() async {
    _currentUser = null;
    _isGuest = false;
    _authStreamController.add(null);
  }

  // =========================================================================
  // Societies Operations
  // =========================================================================

  List<SocietyModel> getSocieties({String? category, String? search}) {
    return _societies.where((s) {
      if (category != null && category != 'All' && s.category != category) {
        return false;
      }
      if (search != null && search.trim().isNotEmpty) {
        final q = search.toLowerCase();
        return s.name.toLowerCase().contains(q) || s.description.toLowerCase().contains(q);
      }
      return true;
    }).map((s) {
      final isF = _followedSocieties.contains(s.id);
      return SocietyModel(
        id: s.id,
        name: s.name,
        slug: s.slug,
        category: s.category,
        description: s.description,
        logoUrl: s.logoUrl,
        bannerUrl: s.bannerUrl,
        status: s.status,
        email: s.email,
        website: s.website,
        socialLinks: s.socialLinks,
        followersCount: s.followersCount + (isF ? 1 : 0),
        isFollowed: isF,
        createdAt: s.createdAt,
        updatedAt: s.updatedAt,
      );
    }).toList();
  }

  SocietyModel? getSocietyById(String id) {
    try {
      final s = _societies.firstWhere((item) => item.id == id);
      final isF = _followedSocieties.contains(s.id);
      return SocietyModel(
        id: s.id,
        name: s.name,
        slug: s.slug,
        category: s.category,
        description: s.description,
        logoUrl: s.logoUrl,
        bannerUrl: s.bannerUrl,
        status: s.status,
        email: s.email,
        website: s.website,
        socialLinks: s.socialLinks,
        followersCount: s.followersCount + (isF ? 1 : 0),
        isFollowed: isF,
        createdAt: s.createdAt,
        updatedAt: s.updatedAt,
      );
    } catch (_) {
      return null;
    }
  }

  List<OfficeBearerModel> getOfficeBearers(String societyId) {
    return _officeBearers[societyId] ?? [];
  }

  String? getUserSocietyRole(String societyId, String userId) {
    return _societyRoles[societyId]?[userId];
  }

  void toggleFollow(String societyId) {
    if (_followedSocieties.contains(societyId)) {
      _followedSocieties.remove(societyId);
    } else {
      _followedSocieties.add(societyId);
    }
  }

  Future<SocietyModel> submitRegistrationRequest({
    required String name,
    required String category,
    required String description,
    String? email,
    String? website,
    String? logoUrl,
  }) async {
    final now = DateTime.now();
    final newSoc = SocietyModel(
      id: 'soc-pending-${now.millisecondsSinceEpoch}',
      name: name,
      slug: name.toLowerCase().replaceAll(' ', '-'),
      category: category,
      description: description,
      email: email,
      website: website,
      logoUrl: logoUrl,
      status: 'pending',
      createdAt: now,
      updatedAt: now,
    );
    _pendingSocieties.add(newSoc);
    return newSoc;
  }

  List<SocietyModel> getPendingRequests() => List.unmodifiable(_pendingSocieties);

  // =========================================================================
  // Feed & Events Operations
  // =========================================================================

  List<PostModel> getPosts({bool onlyFollowed = false}) {
    return _posts.where((p) {
      if (onlyFollowed) {
        return _followedSocieties.contains(p.societyId);
      }
      return true;
    }).map((p) {
      final isL = _likedPostIds.contains(p.id);
      return PostModel(
        id: p.id,
        societyId: p.societyId,
        authorId: p.authorId,
        title: p.title,
        content: p.content,
        mediaUrls: p.mediaUrls,
        isPinned: p.isPinned,
        isPublic: p.isPublic,
        createdAt: p.createdAt,
        updatedAt: p.updatedAt,
        societyName: p.societyName,
        societyLogo: p.societyLogo,
        authorName: p.authorName,
        likesCount: p.likesCount + (isL ? 1 : 0),
        commentsCount: _comments[p.id]?.length ?? p.commentsCount,
        isLiked: isL,
        canManage: p.canManage,
      );
    }).toList();
  }

  void toggleLikePost(String postId) {
    if (_likedPostIds.contains(postId)) {
      _likedPostIds.remove(postId);
    } else {
      _likedPostIds.add(postId);
    }
  }

  List<CommentModel> getComments(String postId) => _comments[postId] ?? [];

  CommentModel addComment(String postId, String content) {
    final cmt = CommentModel(
      id: 'cmt-${DateTime.now().millisecondsSinceEpoch}',
      postId: postId,
      authorId: _currentUser?.id ?? 'usr-student-1',
      authorName: _currentUser?.fullName ?? 'UET Student',
      content: content,
      createdAt: DateTime.now(),
    );
    _comments.putIfAbsent(postId, () => []).insert(0, cmt);
    return cmt;
  }

  PostModel createPost({
    required String societyId,
    required String title,
    required String content,
    List<String> mediaUrls = const [],
    bool isPublic = true,
    bool isPinned = false,
  }) {
    final soc = getSocietyById(societyId);
    final now = DateTime.now();
    final newPost = PostModel(
      id: 'post-${now.millisecondsSinceEpoch}',
      societyId: societyId,
      authorId: _currentUser?.id ?? 'usr-student-1',
      title: title,
      content: content,
      mediaUrls: mediaUrls,
      isPinned: isPinned,
      isPublic: isPublic,
      societyName: soc?.name ?? 'UET Society',
      authorName: _currentUser?.fullName ?? 'Society Executive',
      createdAt: now,
      updatedAt: now,
      canManage: true,
    );
    _posts.insert(0, newPost);
    return newPost;
  }

  List<EventModel> getEvents() {
    return _events.map((e) {
      final isInt = _interestedEventIds.contains(e.id);
      return EventModel(
        id: e.id,
        societyId: e.societyId,
        title: e.title,
        description: e.description,
        venue: e.venue,
        startTime: e.startTime,
        endTime: e.endTime,
        societyName: e.societyName,
        societyLogo: e.societyLogo,
        interestedCount: e.interestedCount + (isInt ? 1 : 0),
        isInterested: isInt,
      );
    }).toList();
  }

  void toggleEventInterest(String eventId) {
    if (_interestedEventIds.contains(eventId)) {
      _interestedEventIds.remove(eventId);
    } else {
      _interestedEventIds.add(eventId);
    }
  }

  // =========================================================================
  // Hiring Operations
  // =========================================================================

  List<HiringModel> getHirings({String? societyId, bool onlySaved = false}) {
    return _hirings.where((h) {
      if (societyId != null && societyId != 'All' && h.societyId != societyId) {
        return false;
      }
      if (onlySaved && !_savedHiringIds.contains(h.id)) {
        return false;
      }
      return true;
    }).map((h) {
      final isS = _savedHiringIds.contains(h.id);
      final hasApp = _applications.any((a) => a.hiringId == h.id && a.userId == (_currentUser?.id ?? ''));
      return HiringModel(
        id: h.id,
        societyId: h.societyId,
        societyName: h.societyName,
        societyLogo: h.societyLogo,
        title: h.title,
        description: h.description,
        positions: h.positions,
        deadline: h.deadline,
        status: h.status,
        requirements: h.requirements,
        selectionMethod: h.selectionMethod,
        totalSeats: h.totalSeats,
        customQuestions: h.customQuestions,
        isSaved: isS,
        hasApplied: hasApp,
        createdAt: h.createdAt,
      );
    }).toList();
  }

  void toggleSaveHiring(String hiringId) {
    if (_savedHiringIds.contains(hiringId)) {
      _savedHiringIds.remove(hiringId);
    } else {
      _savedHiringIds.add(hiringId);
    }
  }

  ApplicationModel applyToHiring({
    required String hiringId,
    required String position,
    required Map<String, dynamic> answers,
  }) {
    final now = DateTime.now();
    final app = ApplicationModel(
      id: 'app-${now.millisecondsSinceEpoch}',
      hiringId: hiringId,
      userId: _currentUser?.id ?? 'usr-student-1',
      position: position,
      status: 'submitted',
      answers: answers,
      createdAt: now,
      applicantName: _currentUser?.fullName ?? 'UET Student',
      applicantRoll: _currentUser?.rollNumber ?? '2022-CS-101',
      applicantDept: _currentUser?.department ?? 'Computer Science',
      applicantSemester: _currentUser?.semester ?? 6,
      applicantEmail: _currentUser?.email ?? '2022cs101@uet.edu.pk',
    );
    _applications.insert(0, app);
    return app;
  }

  List<ApplicationModel> getApplications(String hiringId, {String? status, String? position}) {
    return _applications.where((a) {
      if (a.hiringId != hiringId) return false;
      if (status != null && status != 'All' && a.status != status) return false;
      if (position != null && position != 'All' && a.position != position) return false;
      return true;
    }).toList();
  }

  // =========================================================================
  // Groups & Chat Operations
  // =========================================================================

  List<GroupModel> getUserGroups() => List.unmodifiable(_groups);

  List<GroupMemberModel> getGroupMembers(String groupId) => _groupMembers[groupId] ?? [];

  Stream<List<GroupMessageModel>> getGroupMessagesStream(String groupId) {
    if (!_groupMessageStreams.containsKey(groupId)) {
      _groupMessageStreams[groupId] = StreamController<List<GroupMessageModel>>.broadcast();
    }
    // Emit initial messages immediately
    Future.microtask(() {
      _groupMessageStreams[groupId]?.add(_groupMessages[groupId] ?? []);
    });
    return _groupMessageStreams[groupId]!.stream;
  }

  void sendMessage({
    required String groupId,
    required String content,
    String messageType = 'text',
    PollModel? poll,
    TaskModel? task,
  }) {
    final now = DateTime.now();
    final msg = GroupMessageModel(
      id: 'msg-${now.millisecondsSinceEpoch}',
      groupId: groupId,
      senderId: _currentUser?.id ?? 'usr-student-1',
      senderName: _currentUser?.fullName ?? 'Muhammad Junaid',
      content: content,
      messageType: messageType,
      poll: poll,
      task: task,
      createdAt: now,
    );

    _groupMessages.putIfAbsent(groupId, () => []).add(msg);
    _groupMessageStreams[groupId]?.add(_groupMessages[groupId] ?? []);

    // Simulate friendly auto-reply after 2 seconds if user sends a message
    if (messageType == 'text') {
      Future.delayed(const Duration(seconds: 2), () {
        final reply = GroupMessageModel(
          id: 'reply-${DateTime.now().millisecondsSinceEpoch}',
          groupId: groupId,
          senderId: 'usr-president-1',
          senderName: 'Hamza Ali (President)',
          content: 'Acknowledged! Keep up the great work.',
          messageType: 'text',
          createdAt: DateTime.now(),
        );
        _groupMessages[groupId]?.add(reply);
        _groupMessageStreams[groupId]?.add(_groupMessages[groupId] ?? []);
      });
    }
  }

  // =========================================================================
  // Notifications & Profile Operations
  // =========================================================================

  List<Map<String, dynamic>> getNotifications() => List.unmodifiable(_notifications);

  StudentProfile? getProfile(String userId) {
    return _profiles[userId] ??
        StudentProfile(
          id: userId,
          fullName: _currentUser?.fullName ?? 'UET Student',
          rollNumber: _currentUser?.rollNumber ?? '2022-CS-101',
          department: _currentUser?.department ?? 'Computer Science',
          semester: _currentUser?.semester ?? 6,
          email: _currentUser?.email ?? '2022cs101@uet.edu.pk',
        );
  }

  void updateProfile({
    required String userId,
    required String fullName,
    required int semester,
    String? bio,
    String? phoneNumber,
  }) {
    final existing = getProfile(userId);
    _profiles[userId] = StudentProfile(
      id: userId,
      fullName: fullName,
      rollNumber: existing?.rollNumber ?? '2022-CS-101',
      department: existing?.department ?? 'Computer Science',
      semester: semester,
      email: existing?.email ?? '2022cs101@uet.edu.pk',
      bio: bio,
      phoneNumber: phoneNumber,
    );
  }
}
