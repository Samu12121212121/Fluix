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
      id: json['id'],
      name: json['name'],
      adminUserId: json['adminUserId'],
      createdAt: DateTime.parse(json['createdAt']),
      managerIds: List<String>.from(json['managerIds'] ?? []),
      isActive: json['isActive'] ?? true,
    );
  }
}
