enum UserRole {
  companyAdmin,
  companyManager,
  normalUser,
}

class AppUser {
  final String id;
  final String email;
  final String name;
  final UserRole role;
  final String? companyId;
  final DateTime createdAt;
  final bool isActive;

  AppUser({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    this.companyId,
    required this.createdAt,
    this.isActive = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'role': role.name,
      'companyId': companyId,
      'createdAt': createdAt.toIso8601String(),
      'isActive': isActive,
    };
  }

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'],
      email: json['email'],
      name: json['name'],
      role: UserRole.values.firstWhere((e) => e.name == json['role']),
      companyId: json['companyId'],
      createdAt: DateTime.parse(json['createdAt']),
      isActive: json['isActive'] ?? true,
    );
  }

  // Métodos de utilidad para verificar roles
  bool get isCompanyAdmin => role == UserRole.companyAdmin;
  bool get isCompanyManager => role == UserRole.companyManager;
  bool get isNormalUser => role == UserRole.normalUser;
}
