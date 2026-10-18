class Company {
  final String id;
  final String name;
  final String adminUserId;
  final DateTime createdAt;
  final List<String> managerIds;
  final bool isActive;

  Company({
    required this.id,
    required this.name,
    required this.adminUserId,
    required this.createdAt,
    this.managerIds = const [],
    this.isActive = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'adminUserId': adminUserId,
      'createdAt': createdAt.toIso8601String(),
      'managerIds': managerIds,
      'isActive': isActive,
    };
  }

  factory Company.fromJson(Map<String, dynamic> json) {
    return Company(
      id:          json['id'] as String? ?? '',
      name:        json['name'] as String? ?? '',
      adminUserId: json['adminUserId'] as String? ?? '',
      createdAt:   json['createdAt'] != null
          ? (DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now())
          : DateTime.now(),
      managerIds: List<String>.from(json['managerIds'] ?? []),
      isActive:   json['isActive'] as bool? ?? true,
    );
  }
}
