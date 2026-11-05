class SocietyModel {
  final String id;
  final String name;
  final String slug;
  final String category;
  final String description;
  final String? logoUrl;
  final String? bannerUrl;
  final String status;
  final String? email;
  final String? website;
  final Map<String, dynamic> socialLinks;
  final String? createdBy;
  final String? rejectionReason;
  final int followersCount;
  final bool isFollowed;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SocietyModel({
    required this.id,
    required this.name,
    required this.slug,
    required this.category,
    required this.description,
    this.logoUrl,
    this.bannerUrl,
    this.status = 'active',
    this.email,
    this.website,
    this.socialLinks = const {},
    this.createdBy,
    this.rejectionReason,
    this.followersCount = 0,
    this.isFollowed = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SocietyModel.fromJson(Map<String, dynamic> json, {bool isFollowed = false, int followersCount = 0}) {
    return SocietyModel(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      category: json['category'] as String? ?? 'Technical',
      description: json['description'] as String? ?? '',
      logoUrl: json['logo_url'] as String?,
      bannerUrl: json['banner_url'] as String?,
      status: json['status'] as String? ?? 'active',
      email: json['email'] as String?,
      website: json['website'] as String?,
      socialLinks: (json['social_links'] as Map<String, dynamic>?) ?? {},
      createdBy: json['created_by'] as String?,
      rejectionReason: json['rejection_reason'] as String?,
      followersCount: followersCount,
      isFollowed: isFollowed,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'category': category,
      'description': description,
      'logo_url': logoUrl,
      'banner_url': bannerUrl,
      'status': status,
      'email': email,
      'website': website,
      'social_links': socialLinks,
      'created_by': createdBy,
      'rejection_reason': rejectionReason,
    };
  }

  SocietyModel copyWith({
    String? name,
    String? slug,
    String? category,
    String? description,
    String? logoUrl,
    String? bannerUrl,
    String? status,
    String? email,
    String? website,
    Map<String, dynamic>? socialLinks,
    String? createdBy,
    String? rejectionReason,
    int? followersCount,
    bool? isFollowed,
  }) {
    return SocietyModel(
      id: id,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      category: category ?? this.category,
      description: description ?? this.description,
      logoUrl: logoUrl ?? this.logoUrl,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      status: status ?? this.status,
      email: email ?? this.email,
      website: website ?? this.website,
      socialLinks: socialLinks ?? this.socialLinks,
      createdBy: createdBy ?? this.createdBy,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      followersCount: followersCount ?? this.followersCount,
      isFollowed: isFollowed ?? this.isFollowed,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  bool get isActive => status == 'active';
  bool get isPending => status == 'pending';
  bool get isRejected => status == 'rejected';
}
