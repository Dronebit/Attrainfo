enum EmployeeRole {
  superAdmin,
  regionalAdmin,
  parkAdmin,
  operator,
  technician,
}

extension EmployeeRoleX on EmployeeRole {
  String get label => const {
        EmployeeRole.superAdmin: 'Super',
        EmployeeRole.regionalAdmin: 'Регион',
        EmployeeRole.parkAdmin: 'Парк',
        EmployeeRole.operator: 'Оператор',
        EmployeeRole.technician: 'Механик',
      }[this]!;

  int get colorValue => const {
        EmployeeRole.superAdmin: 0xFFA78BFA,
        EmployeeRole.regionalAdmin: 0xFF60A5FA,
        EmployeeRole.parkAdmin: 0xFF34D399,
        EmployeeRole.operator: 0xFFFBBF24,
        EmployeeRole.technician: 0xFFFF9F43,
      }[this]!;

  bool get canBeAdmin =>
      this == EmployeeRole.superAdmin ||
      this == EmployeeRole.regionalAdmin ||
      this == EmployeeRole.parkAdmin;

  bool get worksAtPark =>
      this == EmployeeRole.parkAdmin ||
      this == EmployeeRole.operator ||
      this == EmployeeRole.technician;
}

enum EmployeeStatus { active, vacation, sick, blocked, fired }

extension EmployeeStatusX on EmployeeStatus {
  String get label => const {
        EmployeeStatus.active: 'Работает',
        EmployeeStatus.vacation: 'Отпуск',
        EmployeeStatus.sick: 'Больничный',
        EmployeeStatus.blocked: 'Заблокирован',
        EmployeeStatus.fired: 'Уволен',
      }[this]!;

  int get colorValue => const {
        EmployeeStatus.active: 0xFF34D399,
        EmployeeStatus.vacation: 0xFF60A5FA,
        EmployeeStatus.sick: 0xFFA78BFA,
        EmployeeStatus.blocked: 0xFFFF5D55,
        EmployeeStatus.fired: 0xFF94A3B8,
      }[this]!;

  bool get canWork => this == EmployeeStatus.active;
}

class RoleHistoryEntry {
  final String id;
  EmployeeRole role;
  String? parkId;
  String? regionId;
  String? jobTitle;
  DateTime startedAt;
  DateTime? endedAt;
  String? reason;

  RoleHistoryEntry({
    required this.id,
    required this.role,
    this.parkId,
    this.regionId,
    this.jobTitle,
    required this.startedAt,
    this.endedAt,
    this.reason,
  });

  bool get isCurrent => endedAt == null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role.name,
        'parkId': parkId,
        'regionId': regionId,
        'jobTitle': jobTitle,
        'startedAt': startedAt.toIso8601String(),
        'endedAt': endedAt?.toIso8601String(),
        'reason': reason,
      };

  factory RoleHistoryEntry.fromJson(Map<String, dynamic> j) =>
      RoleHistoryEntry(
        id: j['id'],
        role: EmployeeRole.values.firstWhere(
          (e) => e.name == j['role'],
          orElse: () => EmployeeRole.operator,
        ),
        parkId: j['parkId'],
        regionId: j['regionId'],
        jobTitle: j['jobTitle'],
        startedAt: DateTime.parse(j['startedAt']),
        endedAt:
            j['endedAt'] != null ? DateTime.parse(j['endedAt']) : null,
        reason: j['reason'],
      );
}

class Employee {
  final String id;
  String name;
  String phone;
  String pin;
  String? badgeId;

  EmployeeRole role;
  EmployeeStatus status;

  String? parkId;
  String? regionId;
  String? jobTitle;
  String? address;

  // Последний известный город (вычисляется при назначении в парк,
  // сохраняется при снятии — чтобы «свободный админ» не терял город)
  String? lastCityId;

  DateTime createdAt;
  DateTime? statusChangedAt;
  String? statusNote;
  List<RoleHistoryEntry> history;

  Employee({
    required this.id,
    required this.name,
    this.phone = '',
    this.pin = '0000',
    this.badgeId,
    this.role = EmployeeRole.operator,
    this.status = EmployeeStatus.active,
    this.parkId,
    this.regionId,
    this.jobTitle,
    this.address,
    this.lastCityId,
    DateTime? createdAt,
    this.statusChangedAt,
    this.statusNote,
    List<RoleHistoryEntry>? history,
  })  : createdAt = createdAt ?? DateTime.now(),
        history = history ?? [];

  bool get isAdmin => role.canBeAdmin;
  bool get canWork => status.canWork;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'pin': pin,
        'badgeId': badgeId,
        'role': role.name,
        'status': status.name,
        'parkId': parkId,
        'regionId': regionId,
        'jobTitle': jobTitle,
        'address': address,
        'lastCityId': lastCityId,
        'createdAt': createdAt.toIso8601String(),
        'statusChangedAt': statusChangedAt?.toIso8601String(),
        'statusNote': statusNote,
        'history': history.map((e) => e.toJson()).toList(),
      };

  factory Employee.fromJson(Map<String, dynamic> j) => Employee(
        id: j['id'],
        name: j['name'],
        phone: j['phone'] ?? '',
        pin: j['pin'] ?? '0000',
        badgeId: j['badgeId'],
        role: EmployeeRole.values.firstWhere(
          (e) => e.name == j['role'],
          orElse: () => EmployeeRole.operator,
        ),
        status: EmployeeStatus.values.firstWhere(
          (e) => e.name == j['status'],
          orElse: () => EmployeeStatus.active,
        ),
        parkId: j['parkId'],
        regionId: j['regionId'],
        jobTitle: j['jobTitle'],
        address: j['address'],
        lastCityId: j['lastCityId'],
        createdAt: j['createdAt'] != null
            ? DateTime.parse(j['createdAt'])
            : DateTime.now(),
        statusChangedAt: j['statusChangedAt'] != null
            ? DateTime.parse(j['statusChangedAt'])
            : null,
        statusNote: j['statusNote'],
        history: (j['history'] as List?)
                ?.map((e) => RoleHistoryEntry.fromJson(e))
                .toList() ??
            [],
      );

  factory Employee.fromOldOperator(Map<String, dynamic> j) => Employee(
        id: j['id'],
        name: j['name'],
        phone: j['phone'] ?? '',
        pin: j['pin'] ?? '0000',
        badgeId: j['badgeId'],
        role: EmployeeRole.operator,
        status: EmployeeStatus.values.firstWhere(
          (e) => e.name == j['status'],
          orElse: () => EmployeeStatus.active,
        ),
        createdAt: j['createdAt'] != null
            ? DateTime.parse(j['createdAt'])
            : DateTime.now(),
        statusChangedAt: j['statusChangedAt'] != null
            ? DateTime.parse(j['statusChangedAt'])
            : null,
        statusNote: j['statusNote'],
      );

  factory Employee.fromOldAdmin(Map<String, dynamic> j) {
    final roleName = j['role'] as String? ?? 'parkAdmin';
    final role = EmployeeRole.values.firstWhere(
      (e) => e.name == roleName,
      orElse: () => EmployeeRole.parkAdmin,
    );
    final active = j['active'] as bool? ?? true;
    return Employee(
      id: j['id'],
      name: j['name'],
      pin: j['pin'] ?? '0000',
      role: role,
      status: active ? EmployeeStatus.active : EmployeeStatus.fired,
      parkId: j['parkId'],
      regionId: j['regionId'],
      createdAt: j['createdAt'] != null
          ? DateTime.parse(j['createdAt'])
          : DateTime.now(),
    );
  }

  factory Employee.fromOldTech(Map<String, dynamic> j) => Employee(
        id: j['id'],
        name: j['name'],
        phone: j['phone'] ?? '',
        role: EmployeeRole.technician,
        jobTitle: j['role'] ?? 'Механик',
        createdAt: DateTime.now(),
      );
}