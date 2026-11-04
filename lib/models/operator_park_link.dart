enum LinkStatus { pending, approved, rejected }

extension LinkStatusX on LinkStatus {
  String get label => const {
        LinkStatus.pending: 'Ожидает',
        LinkStatus.approved: 'Одобрено',
        LinkStatus.rejected: 'Отклонено',
      }[this]!;

  int get colorValue => const {
        LinkStatus.pending: 0xFFFFB224,
        LinkStatus.approved: 0xFF34D399,
        LinkStatus.rejected: 0xFFFF5D55,
      }[this]!;
}

class OperatorParkLink {
  final String id;
  final String operatorId;
  final String parkId;
  LinkStatus status;
  String? initiatorAdminId;
  String? approverAdminId;
  DateTime createdAt;
  DateTime? approvedAt;
  String? note;

  OperatorParkLink({
    required this.id,
    required this.operatorId,
    required this.parkId,
    this.status = LinkStatus.pending,
    this.initiatorAdminId,
    this.approverAdminId,
    DateTime? createdAt,
    this.approvedAt,
    this.note,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'operatorId': operatorId,
        'parkId': parkId,
        'status': status.name,
        'initiatorAdminId': initiatorAdminId,
        'approverAdminId': approverAdminId,
        'createdAt': createdAt.toIso8601String(),
        'approvedAt': approvedAt?.toIso8601String(),
        'note': note,
      };

  factory OperatorParkLink.fromJson(Map<String, dynamic> j) => OperatorParkLink(
        id: j['id'],
        operatorId: j['operatorId'],
        parkId: j['parkId'],
        status: LinkStatus.values.firstWhere(
          (e) => e.name == j['status'],
          orElse: () => LinkStatus.pending,
        ),
        initiatorAdminId: j['initiatorAdminId'],
        approverAdminId: j['approverAdminId'],
        createdAt: DateTime.parse(j['createdAt']),
        approvedAt:
            j['approvedAt'] != null ? DateTime.parse(j['approvedAt']) : null,
        note: j['note'],
      );
}