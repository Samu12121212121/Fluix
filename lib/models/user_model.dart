enum UserRole {
  companyAdmin,
  companyManager,
  normalUser,
  clienteFinal,
}

class AppUser {
  final String id;
  final String email;
  final String name;
  final UserRole role;
  final String? companyId;
  final DateTime createdAt;
  final bool isActive;
  final String? telefono;

  AppUser({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    this.companyId,
    required this.createdAt,
    this.isActive = true,
    this.telefono,
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
      'telefono': telefono,
    };
  }

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      name: json['name'] as String? ?? '',
      role: UserRole.values.firstWhere(
            (e) => e.name == (json['role'] as String? ?? ''),
        orElse: () => UserRole.normalUser,
      ),
      companyId: json['companyId'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      isActive: json['isActive'] as bool? ?? true,
      telefono: json['telefono'] as String?,
    );
  }

  bool get isCompanyAdmin => role == UserRole.companyAdmin;
  bool get isCompanyManager => role == UserRole.companyManager;
  bool get isNormalUser => role == UserRole.normalUser;
  bool get isClienteFinal => role == UserRole.clienteFinal;
  bool get isCompanyUser => isCompanyAdmin || isCompanyManager || isNormalUser;
}