import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/enums.dart';
import '../models/models.dart';
import '../models/operator.dart';
import '../models/park_admin.dart';
import '../models/shift.dart';
import 'seed.dart';

class AppDatabase extends ChangeNotifier {
  static const _key = 'attrakontrol-v2';

  List<City> cities = [];
  List<ParkLocation> locations = [];
  List<Park> parks = [];
  List<Ride> rides = [];
  List<Technician> techs = [];
  List<Downtime> downtimes = [];
  List<Incident> incidents = [];
  List<Operator> operators = [];
  List<ParkAdmin> admins = [];

  Shift? activeShift;
  bool opSelectingRides = false;
  String? currentParkId;

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

  String cityOfPark(Park p) {
    final l = locById(p.locId);
    final c = l == null ? null : cityById(l.cityId);
    return c?.name ?? '—';
  }

  String ridePath(String rideId) {
    final r = rideById(rideId);
    if (r == null) return '—';
    final p = parkById(r.parkId);
    final l = p == null ? null : locById(p.locId);
    final c = l == null ? null : cityById(l.cityId);
    return [c?.name, l?.name, p?.name].where((x) => x != null).join(' · ');
  }

  // ---- shift ----
  void startShift(String parkId, {String? operatorId}) {
    activeShift = Shift(
      parkId: parkId,
      startedAt: DateTime.now(),
      operatorId: operatorId,
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

  // ---- analytics ----
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

  // ---- save/load ----
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
    // Если после загрузки операторов нет — заливаем seed (первый запуск или битые данные)
    if (operators.isEmpty) {
      _apply(_seedJson());
    }
    // Если админов нет — создаём дефолтного, иначе в админку не зайти
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
    };
  }

  /// Безопасный маппинг: возвращает [] если ключа нет или он не List.
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