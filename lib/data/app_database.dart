import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/enums.dart';
import '../models/models.dart';
import '../models/operator.dart';
import '../models/park_admin.dart';
import '../models/operator_park_link.dart';
import '../models/shift_vacancy.dart';
import '../models/shift.dart';
import 'seed.dart';

class AppDatabase extends ChangeNotifier {
  static const _key = 'attrakontrol-v4';
  static const masterPin = '9999';

  List<City> cities = [];
  List<ParkLocation> locations = [];
  List<Park> parks = [];
  List<Ride> rides = [];
  List<Technician> techs = [];
  List<Downtime> downtimes = [];
  List<Incident> incidents = [];
  List<Operator> operators = [];
  List<ParkAdmin> admins = [];
  List<OperatorParkLink> operatorLinks = [];
  List<ShiftVacancy> vacancies = [];
  List<VacancyApplication> applications = [];

  Shift? activeShift;
  bool opSelectingRides = false;
  String? currentParkId;

  // ─── базовые геттеры ───
  City? cityById(String? id) => cities.firstWhereOrNull((c) => c.id == id);
  ParkLocation? locById(String? id) =>
      locations.firstWhereOrNull((l) => l.id == id);
  Park? parkById(String? id) => parks.firstWhereOrNull((p) => p.id == id);
  Ride? rideById(String? id) => rides.firstWhereOrNull((r) => r.id == id);
  Technician? techById(String? id) =>
      techs.firstWhereOrNull((t) => t.id == id);
  Operator? operatorById(String? id) =>
      operators.firstWhereOrNull((o) => o.id == id);
  Operator? operatorByBadge(String? uid) =>
      operators.firstWhereOrNull((o) => o.badgeId == uid);
  ParkAdmin? adminById(String? id) =>
      admins.firstWhereOrNull((a) => a.id == id);
  ShiftVacancy? vacancyById(String? id) =>
      vacancies.firstWhereOrNull((v) => v.id == id);
  VacancyApplication? applicationById(String? id) =>
      applications.firstWhereOrNull((a) => a.id == id);

  String cityOfPark(Park p) {
    final l = locById(p.locId);
    final c = l == null ? null : cityById(l.cityId);
    return c?.name ?? '—';
  }

  String? cityIdOfPark(Park? p) {
    if (p == null) return null;
    final l = locById(p.locId);
    return l?.cityId;
  }

  String ridePath(String rideId) {
    final r = rideById(rideId);
    if (r == null) return '—';
    final p = parkById(r.parkId);
    final l = p == null ? null : locById(p.locId);
    final c = l == null ? null : cityById(l.cityId);
    return [c?.name, l?.name, p?.name].where((x) => x != null).join(' · ');
  }

  // ─── связи оператор ↔ парк ───
  List<OperatorParkLink> linksForOperator(String opId) =>
      operatorLinks.where((l) => l.operatorId == opId).toList();

  List<String> approvedParkIdsForOperator(String opId) => operatorLinks
      .where((l) => l.operatorId == opId && l.status == LinkStatus.approved)
      .map((l) => l.parkId)
      .toList();

  List<Park> approvedParksForOperator(String opId) => approvedParkIdsForOperator(opId)
      .map(parkById)
      .whereType<Park>()
      .toList();

  List<OperatorParkLink> pendingLinksForPark(String parkId) => operatorLinks
      .where((l) => l.parkId == parkId && l.status == LinkStatus.pending)
      .toList();

  List<Operator> operatorsOfPark(String parkId) => operatorLinks
      .where((l) => l.parkId == parkId && l.status == LinkStatus.approved)
      .map((l) => operatorById(l.operatorId))
      .whereType<Operator>()
      .toList();

  /// Создать запрос на привязку. Если оператор уже привязан к другому парку —
  /// нужен второй подтверждающий админ.
  void createLinkRequest(
    String operatorId,
    String parkId, {
    String? initiatorAdminId,
    String? note,
  }) {
    // Уже есть pending или approved?
    final existing = operatorLinks.firstWhereOrNull((l) =>
        l.operatorId == operatorId &&
        l.parkId == parkId &&
        (l.status == LinkStatus.pending || l.status == LinkStatus.approved));
    if (existing != null) return;

    operatorLinks.add(OperatorParkLink(
      id: 'lnk${DateTime.now().microsecondsSinceEpoch}',
      operatorId: operatorId,
      parkId: parkId,
      initiatorAdminId: initiatorAdminId,
      note: note,
    ));
    save();
  }

  /// Одобрить привязку. Если у оператора уже есть approved в этом парке —
  /// не дублируем.
  void approveLink(String linkId, String approverAdminId) {
    final l = operatorLinks.firstWhereOrNull((x) => x.id == linkId);
    if (l == null) return;
    l.status = LinkStatus.approved;
    l.approverAdminId = approverAdminId;
    l.approvedAt = DateTime.now();
    save();
  }

  void rejectLink(String linkId, String approverAdminId) {
    final l = operatorLinks.firstWhereOrNull((x) => x.id == linkId);
    if (l == null) return;
    l.status = LinkStatus.rejected;
    l.approverAdminId = approverAdminId;
    save();
  }

  void removeLink(String linkId) {
    operatorLinks.removeWhere((l) => l.id == linkId);
    save();
  }

  // ─── вакансии ───
  List<ShiftVacancy> vacanciesForPark(String parkId) => vacancies
      .where((v) => v.parkId == parkId)
      .toList()
    ..sort((a, b) => a.date.compareTo(b.date));

  /// Открытые вакансии, видимые оператору (в городах его привязанных парков)
  List<ShiftVacancy> openVacanciesForOperator(String opId) {
    final myParks = approvedParksForOperator(opId);
    final myCityIds = myParks
        .map((p) => cityIdOfPark(p))
        .whereType<String>()
        .toSet();
    return vacancies.where((v) {
      if (v.status != VacancyStatus.open) return false;
      if (!v.date.isAfter(DateTime.now().subtract(const Duration(days: 1)))) {
        return false; // прошедшие
      }
      final p = parkById(v.parkId);
      final cid = cityIdOfPark(p);
      return cid != null && myCityIds.contains(cid);
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  List<VacancyApplication> applicationsForVacancy(String vacancyId) =>
      applications.where((a) => a.vacancyId == vacancyId).toList();

  List<VacancyApplication> applicationsForOperator(String opId) => applications
      .where((a) => a.operatorId == opId)
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  bool canOperatorApply(String opId, String vacancyId) {
    final v = vacancyById(vacancyId);
    if (v == null || v.status != VacancyStatus.open) return false;

    // Уже подал?
    final already = applications.firstWhereOrNull((a) =>
        a.vacancyId == vacancyId &&
        a.operatorId == opId &&
        (a.status == ApplicationStatus.pending ||
            a.status == ApplicationStatus.approved));
    if (already != null) return false;

    // Есть другая approved-заявка на этот же день?
    final conflict = applications.any((a) {
      if (a.operatorId != opId) return false;
      if (a.status != ApplicationStatus.approved) return false;
      final otherV = vacancyById(a.vacancyId);
      if (otherV == null) return false;
      return _sameDay(otherV.date, v.date);
    });
    return !conflict;
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void createVacancy(ShiftVacancy v) {
    vacancies.add(v);
    save();
  }

  void cancelVacancy(String vacancyId) {
    final v = vacancyById(vacancyId);
    if (v == null) return;
    v.status = VacancyStatus.cancelled;
    // Отменяем pending-заявки
    for (final a in applications.where((x) =>
        x.vacancyId == vacancyId && x.status == ApplicationStatus.pending)) {
      a.status = ApplicationStatus.cancelled;
    }
    save();
  }

  void applyForVacancy(String vacancyId, String operatorId) {
    if (!canOperatorApply(operatorId, vacancyId)) return;
    applications.add(VacancyApplication(
      id: 'app${DateTime.now().microsecondsSinceEpoch}',
      vacancyId: vacancyId,
      operatorId: operatorId,
    ));
    save();
  }

  void approveApplication(String appId, String adminId) {
    final a = applicationById(appId);
    if (a == null) return;
    a.status = ApplicationStatus.approved;
    a.decidedByAdminId = adminId;
    a.decidedAt = DateTime.now();

    // Если набрали needCount — закрываем вакансию
    final v = vacancyById(a.vacancyId);
    if (v != null) {
      final approved = applications
          .where((x) =>
              x.vacancyId == v.id && x.status == ApplicationStatus.approved)
          .length;
      if (approved >= v.needCount) {
        v.status = VacancyStatus.filled;
      }
    }
    save();
  }

  void rejectApplication(String appId, String adminId) {
    final a = applicationById(appId);
    if (a == null) return;
    a.status = ApplicationStatus.rejected;
    a.decidedByAdminId = adminId;
    a.decidedAt = DateTime.now();
    save();
  }

  // ─── смена (реальная, по факту) ───
  void startShift(String parkId, {String? operatorId, String? vacancyId}) {
    activeShift = Shift(
      parkId: parkId,
      startedAt: DateTime.now(),
      operatorId: operatorId,
      vacancyId: vacancyId,
    );
    currentParkId = parkId;
    opSelectingRides = true;
    save();
  }

  void endShift() {
    activeShift = null;
    opSelectingRides = false;
    save();
  }

  void setOpSelectingRides(bool v) {
    opSelectingRides = v;
    notifyListeners();
  }

  void setShiftRides(List<String> ids) {
    activeShift?.rideIds = ids;
    save();
  }

  void toggleRelief() {
    if (activeShift == null) return;
    activeShift!.isRelief = !activeShift!.isRelief;
    save();
  }

  // ─── аналитика ───
  List<({String rideId, double total, Map<DowntimeReason, double> byReason})>
      downtimeByRide(int periodDays) {
    final now = DateTime.now();
    final from = now.subtract(Duration(days: periodDays));
    final map = <String,
        ({double total, Map<DowntimeReason, double> byReason})>{};
    for (final d in downtimes) {
      final s = d.start.isAfter(from) ? d.start : from;
      final e = (d.end ?? now).isBefore(now) ? (d.end ?? now) : now;
      if (!e.isAfter(s)) continue;
      final hrs = e.difference(s).inMinutes / 60.0;
      final cur =
          map[d.rideId] ?? (total: 0.0, byReason: <DowntimeReason, double>{});
      final br = Map<DowntimeReason, double>.from(cur.byReason);
      br[d.reason] = (br[d.reason] ?? 0) + hrs;
      map[d.rideId] = (total: cur.total + hrs, byReason: br);
    }
    return map.entries
        .map((e) =>
            (rideId: e.key, total: e.value.total, byReason: e.value.byReason))
        .toList()
      ..sort((a, b) => b.total.compareTo(a.total));
  }

  // ─── save/load ───
  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key,
        jsonEncode({
          'cities': cities.map((e) => e.toJson()).toList(),
          'locations': locations.map((e) => e.toJson()).toList(),
          'parks': parks.map((e) => e.toJson()).toList(),
          'rides': rides.map((e) => e.toJson()).toList(),
          'techs': techs.map((e) => e.toJson()).toList(),
          'downtimes': downtimes.map((e) => e.toJson()).toList(),
          'incidents': incidents.map((e) => e.toJson()).toList(),
          'operators': operators.map((e) => e.toJson()).toList(),
          'admins': admins.map((e) => e.toJson()).toList(),
          'operatorLinks': operatorLinks.map((e) => e.toJson()).toList(),
          'vacancies': vacancies.map((e) => e.toJson()).toList(),
          'applications': applications.map((e) => e.toJson()).toList(),
          'activeShift': activeShift?.toJson(),
          'opSelectingRides': opSelectingRides,
          'currentParkId': currentParkId,
        }));
    notifyListeners();
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    Map<String, dynamic>? json;
    if (raw != null) {
      try {
        json = jsonDecode(raw);
      } catch (_) {}
    }
    json ??= _seedJson();
    _apply(json);
    if (operators.isEmpty) {
      _apply(_seedJson());
    }
    if (admins.isEmpty) {
      admins.add(ParkAdmin(
        id: 'adm-default',
        name: 'Администратор',
        pin: '0000',
      ));
    }
    notifyListeners();
  }

  Future<void> resetToSeed() async {
    _apply(_seedJson());
    activeShift = null;
    opSelectingRides = false;
    currentParkId = null;
    await save();
  }

  Map<String, dynamic> _seedJson() {
    final s = buildSeed();
    return {
      'cities': _safeList(s['cities'], (e) => (e as City).toJson()),
      'locations': _safeList(s['locations'], (e) => (e as ParkLocation).toJson()),
      'parks': _safeList(s['parks'], (e) => (e as Park).toJson()),
      'rides': _safeList(s['rides'], (e) => (e as Ride).toJson()),
      'techs': _safeList(s['techs'], (e) => (e as Technician).toJson()),
      'downtimes': _safeList(s['downtimes'], (e) => (e as Downtime).toJson()),
      'incidents': _safeList(s['incidents'], (e) => (e as Incident).toJson()),
      'operators': _safeList(s['operators'], (e) => (e as Operator).toJson()),
      'admins': _safeList(s['admins'], (e) => (e as ParkAdmin).toJson()),
      'operatorLinks': _safeList(s['operatorLinks'],
          (e) => (e as OperatorParkLink).toJson()),
      'vacancies': _safeList(
          s['vacancies'], (e) => (e as ShiftVacancy).toJson()),
      'applications': _safeList(
          s['applications'], (e) => (e as VacancyApplication).toJson()),
    };
  }

  static List<Map<String, dynamic>> _safeList(
    dynamic raw,
    Map<String, dynamic> Function(Object?) mapper,
  ) {
    if (raw is! List) return [];
    return raw.map(mapper).toList();
  }

  void _apply(Map<String, dynamic> j) {
    cities = (j['cities'] as List?)?.map((e) => City.fromJson(e)).toList() ?? [];
    locations = (j['locations'] as List?)
            ?.map((e) => ParkLocation.fromJson(e))
            .toList() ??
        [];
    parks = (j['parks'] as List?)?.map((e) => Park.fromJson(e)).toList() ?? [];
    rides = (j['rides'] as List?)?.map((e) => Ride.fromJson(e)).toList() ?? [];
    techs =
        (j['techs'] as List?)?.map((e) => Technician.fromJson(e)).toList() ?? [];
    downtimes = (j['downtimes'] as List?)
            ?.map((e) => Downtime.fromJson(e))
            .toList() ??
        [];
    incidents = (j['incidents'] as List?)
            ?.map((e) => Incident.fromJson(e))
            .toList() ??
        [];
    operators = (j['operators'] as List?)
            ?.map((e) => Operator.fromJson(e))
            .toList() ??
        [];
    admins =
        (j['admins'] as List?)?.map((e) => ParkAdmin.fromJson(e)).toList() ?? [];
    operatorLinks = (j['operatorLinks'] as List?)
            ?.map((e) => OperatorParkLink.fromJson(e))
            .toList() ??
        [];
    vacancies = (j['vacancies'] as List?)
            ?.map((e) => ShiftVacancy.fromJson(e))
            .toList() ??
        [];
    applications = (j['applications'] as List?)
            ?.map((e) => VacancyApplication.fromJson(e))
            .toList() ??
        [];
    final sh = j['activeShift'];
    activeShift = sh is Map<String, dynamic> ? Shift.fromJson(sh) : null;
    opSelectingRides = j['opSelectingRides'] ?? false;
    currentParkId = j['currentParkId'];
  }
}

extension _FirstWhereOrNull<E> on List<E> {
  E? firstWhereOrNull(bool Function(E) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}