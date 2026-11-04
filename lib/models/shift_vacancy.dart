enum VacancyStatus { open, filled, cancelled }
enum ApplicationStatus { pending, approved, rejected, cancelled }

extension VacancyStatusX on VacancyStatus {
  String get label => const {
        VacancyStatus.open: 'Открыта',
        VacancyStatus.filled: 'Заполнена',
        VacancyStatus.cancelled: 'Отменена',
      }[this]!;

  int get colorValue => const {
        VacancyStatus.open: 0xFF34D399,
        VacancyStatus.filled: 0xFF60A5FA,
        VacancyStatus.cancelled: 0xFF94A3B8,
      }[this]!;
}

extension ApplicationStatusX on ApplicationStatus {
  String get label => const {
        ApplicationStatus.pending: 'Ожидает',
        ApplicationStatus.approved: 'Одобрена',
        ApplicationStatus.rejected: 'Отклонена',
        ApplicationStatus.cancelled: 'Отменена',
      }[this]!;

  int get colorValue => const {
        ApplicationStatus.pending: 0xFFFFB224,
        ApplicationStatus.approved: 0xFF34D399,
        ApplicationStatus.rejected: 0xFFFF5D55,
        ApplicationStatus.cancelled: 0xFF94A3B8,
      }[this]!;
}

class ShiftVacancy {
  final String id;
  final String parkId;
  DateTime date;
  String shiftName;
  String startTime; // "09:00"
  String endTime;   // "17:00"
  List<String> rideIds;
  int needCount;
  String reason;
  String? comment;
  VacancyStatus status;
  String? createdByAdminId;
  DateTime createdAt;

  ShiftVacancy({
    required this.id,
    required this.parkId,
    required this.date,
    required this.shiftName,
    required this.startTime,
    required this.endTime,
    List<String>? rideIds,
    this.needCount = 1,
    this.reason = '',
    this.comment,
    this.status = VacancyStatus.open,
    this.createdByAdminId,
    DateTime? createdAt,
  })  : rideIds = rideIds ?? [],
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'parkId': parkId,
        'date': date.toIso8601String(),
        'shiftName': shiftName,
        'startTime': startTime,
        'endTime': endTime,
        'rideIds': rideIds,
        'needCount': needCount,
        'reason': reason,
        'comment': comment,
        'status': status.name,
        'createdByAdminId': createdByAdminId,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ShiftVacancy.fromJson(Map<String, dynamic> j) => ShiftVacancy(
        id: j['id'],
        parkId: j['parkId'],
        date: DateTime.parse(j['date']),
        shiftName: j['shiftName'],
        startTime: j['startTime'],
        endTime: j['endTime'],
        rideIds: List<String>.from(j['rideIds'] ?? []),
        needCount: j['needCount'] ?? 1,
        reason: j['reason'] ?? '',
        comment: j['comment'],
        status: VacancyStatus.values.firstWhere(
          (e) => e.name == j['status'],
          orElse: () => VacancyStatus.open,
        ),
        createdByAdminId: j['createdByAdminId'],
        createdAt: DateTime.parse(j['createdAt']),
      );
}

class VacancyApplication {
  final String id;
  final String vacancyId;
  final String operatorId;
  ApplicationStatus status;
  DateTime createdAt;
  String? decidedByAdminId;
  DateTime? decidedAt;
  String? note;

  VacancyApplication({
    required this.id,
    required this.vacancyId,
    required this.operatorId,
    this.status = ApplicationStatus.pending,
    DateTime? createdAt,
    this.decidedByAdminId,
    this.decidedAt,
    this.note,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'vacancyId': vacancyId,
        'operatorId': operatorId,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'decidedByAdminId': decidedByAdminId,
        'decidedAt': decidedAt?.toIso8601String(),
        'note': note,
      };

  factory VacancyApplication.fromJson(Map<String, dynamic> j) =>
      VacancyApplication(
        id: j['id'],
        vacancyId: j['vacancyId'],
        operatorId: j['operatorId'],
        status: ApplicationStatus.values.firstWhere(
          (e) => e.name == j['status'],
          orElse: () => ApplicationStatus.pending,
        ),
        createdAt: DateTime.parse(j['createdAt']),
        decidedByAdminId: j['decidedByAdminId'],
        decidedAt:
            j['decidedAt'] != null ? DateTime.parse(j['decidedAt']) : null,
        note: j['note'],
      );
}