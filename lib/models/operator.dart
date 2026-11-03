enum OperatorStatus { active, vacation, sick, blocked, fired }

extension OperatorStatusX on OperatorStatus {
  String get label => const {
        OperatorStatus.active: 'Работает',
        OperatorStatus.vacation: 'Отпуск',
        OperatorStatus.sick: 'Больничный',
        OperatorStatus.blocked: 'Заблокирован',
        OperatorStatus.fired: 'Уволен',
      }[this]!;

  int get colorValue => const {
        OperatorStatus.active: 0xFF34D399,
        OperatorStatus.vacation: 0xFF60A5FA,
        OperatorStatus.sick: 0xFFA78BFA,
        OperatorStatus.blocked: 0xFFFF5D55,
        OperatorStatus.fired: 0xFF94A3B8,
      }[this]!;

  bool get canWork => this == OperatorStatus.active;
}

class Operator {
  final String id;
  String name;
  String phone;
  String pin;
  String? badgeId;
  OperatorStatus status;
  DateTime createdAt;
  DateTime? statusChangedAt;
  String? statusNote;

  Operator({
    required this.id,
    required this.name,
    this.phone = '',
    this.pin = '0000',
    this.badgeId,
    this.status = OperatorStatus.active,
    DateTime? createdAt,
    this.statusChangedAt,
    this.statusNote,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'pin': pin,
        'badgeId': badgeId,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'statusChangedAt': statusChangedAt?.toIso8601String(),
        'statusNote': statusNote,
      };

  factory Operator.fromJson(Map<String, dynamic> j) => Operator(
        id: j['id'],
        name: j['name'],
        phone: j['phone'] ?? '',
        pin: j['pin'] ?? '0000',
        badgeId: j['badgeId'],
        status: OperatorStatus.values.firstWhere(
          (e) => e.name == j['status'],
          orElse: () => OperatorStatus.active,
        ),
        createdAt: DateTime.parse(j['createdAt']),
        statusChangedAt: j['statusChangedAt'] != null
            ? DateTime.parse(j['statusChangedAt'])
            : null,
        statusNote: j['statusNote'],
      );
}