import 'package:flutter/material.dart';
import '../theme.dart';

enum IncidentType { breakdown, defect, noise, minor }
enum Severity { critical, major, minor, info }
enum DowntimeReason { diagnostics, repair, parts, retired }
enum RideStatus { active, downtime, retired }
enum IncidentStatus { isNew, inProgress, resolved }
enum RideType { coaster, ferris, carousel, swing, water, drop, extreme, family, other }

extension IncidentTypeX on IncidentType {
  String get label => const {
    IncidentType.breakdown: 'Поломка',
    IncidentType.defect: 'Дефект',
    IncidentType.noise: 'Посторонний шум',
    IncidentType.minor: 'Мелкий сбой',
  }[this]!;
  Color get color => const {
    IncidentType.breakdown: AppColors.red,
    IncidentType.defect: AppColors.org,
    IncidentType.noise: AppColors.pur,
    IncidentType.minor: AppColors.cyn,
  }[this]!;
  IconData get icon => const {
    IncidentType.breakdown: Icons.build,
    IncidentType.defect: Icons.warning_amber_rounded,
    IncidentType.noise: Icons.volume_up,
    IncidentType.minor: Icons.flash_on,
  }[this]!;
}

extension SeverityX on Severity {
  String get label => const {
    Severity.critical: 'Критическая',
    Severity.major: 'Значительная',
    Severity.minor: 'Незначительная',
    Severity.info: 'Информационная',
  }[this]!;
  Color get color => const {
    Severity.critical: AppColors.red,
    Severity.major: AppColors.org,
    Severity.minor: Color(0xFFFFD166),
    Severity.info: AppColors.mut,
  }[this]!;
}

extension DowntimeReasonX on DowntimeReason {
  String get label => const {
    DowntimeReason.diagnostics: 'Диагностика',
    DowntimeReason.repair: 'Ремонт',
    DowntimeReason.parts: 'Ожидание запчастей',
    DowntimeReason.retired: 'Вывод из эксплуатации',
  }[this]!;
  Color get color => const {
    DowntimeReason.diagnostics: AppColors.blu,
    DowntimeReason.repair: AppColors.org,
    DowntimeReason.parts: AppColors.pur,
    DowntimeReason.retired: Color(0xFF94A3B8),
  }[this]!;
  IconData get icon => const {
    DowntimeReason.diagnostics: Icons.search,
    DowntimeReason.repair: Icons.build,
    DowntimeReason.parts: Icons.inventory_2_outlined,
    DowntimeReason.retired: Icons.power_settings_new,
  }[this]!;
}

extension RideStatusX on RideStatus {
  String get label => const {
    RideStatus.active: 'В работе',
    RideStatus.downtime: 'Простой',
    RideStatus.retired: 'Выведен',
  }[this]!;
  Color get color => const {
    RideStatus.active: AppColors.grn,
    RideStatus.downtime: AppColors.amb,
    RideStatus.retired: Color(0xFF94A3B8),
  }[this]!;
}

extension IncidentStatusX on IncidentStatus {
  String get label => const {
    IncidentStatus.isNew: 'Новое',
    IncidentStatus.inProgress: 'В работе',
    IncidentStatus.resolved: 'Устранено',
  }[this]!;
  Color get color => const {
    IncidentStatus.isNew: AppColors.red,
    IncidentStatus.inProgress: AppColors.amb,
    IncidentStatus.resolved: AppColors.grn,
  }[this]!;
}

extension RideTypeX on RideType {
  String get label => const {
    RideType.coaster: 'Американские горки',
    RideType.ferris: 'Колесо обозрения',
    RideType.carousel: 'Карусель',
    RideType.swing: 'Качели / маятник',
    RideType.water: 'Водный аттракцион',
    RideType.drop: 'Башня падения',
    RideType.extreme: 'Экстремальный',
    RideType.family: 'Семейный',
    RideType.other: 'Другой',
  }[this]!;
}