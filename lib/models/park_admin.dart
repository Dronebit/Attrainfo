enum AdminRole { superAdmin, regionalAdmin, parkAdmin }

extension AdminRoleX on AdminRole {
  String get label => const {
        AdminRole.superAdmin: 'Super',
        AdminRole.regionalAdmin: 'Регион',
        AdminRole.parkAdmin: 'Парк',
      }[this]!;

  int get colorValue => const {
        AdminRole.superAdmin: 0xFFA78BFA,
        AdminRole.regionalAdmin: 0xFF60A5FA,
        AdminRole.parkAdmin: 0xFF34D399,
      }[this]!;
}

class ParkAdmin {
  final String id;
  String name;
  String pin;
  bool active;
  AdminRole role;
  String? parkId;
  String? regionId;
  DateTime createdAt;

  ParkAdmin({
    required this.id,
    required this.name,
    this.pin = '0000',
    this.active = true,
    this.role = AdminRole.parkAdmin,
    this.parkId,
    this.regionId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'pin': pin,
        'active': active,
        'role': role.name,
        'parkId': parkId,
        'regionId': regionId,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ParkAdmin.fromJson(Map<String, dynamic> j) => ParkAdmin(
        id: j['id'],
        name: j['name'],
        pin: j['pin'] ?? '0000',
        active: j['active'] ?? true,
        role: AdminRole.values.firstWhere(
          (e) => e.name == j['role'],
          orElse: () => AdminRole.parkAdmin,
        ),
        parkId: j['parkId'],
        regionId: j['regionId'],
        createdAt: j['createdAt'] != null
            ? DateTime.parse(j['createdAt'])
            : DateTime.now(),
      );
}