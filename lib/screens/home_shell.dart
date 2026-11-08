import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/enums.dart';
import '../models/models.dart';
import '../models/employee.dart';
import '../models/permissions.dart';
import '../models/operator_park_link.dart';
import '../models/shift_vacancy.dart';
import '../models/shift.dart';
import '../models/region.dart';
import '../models/inventory.dart';
import 'seed.dart';

part 'parts/part_employees.dart';
part 'parts/part_operations.dart';
part 'parts/part_org_structure.dart';
part 'parts/part_inventory.dart';

class AppDatabase extends ChangeNotifier {
  static const _key = 'attrakontrol-v8';
  static const _oldKey = 'attrakontrol-v7';
  static const _legacyKey = 'attrakontrol-v6';
  static const _ancientKey = 'attrakontrol-v5';
  static const masterPin = '9999';

  // ═══════════ state ═══════════

  // ─── Орг. структура ───
  List<City> cities = [];
  List<ParkLocation> locations = [];
  List<Park> parks = [];
  List<Region> regions = [];

  // ─── Аттракционы и события ───
  List<Ride> rides = [];
  List<Downtime> downtimes = [];
  List<Incident> incidents = [];

  // ─── Сотрудники и управление ───
  List<Employee> employees = [];
  List<OperatorParkLink> operatorLinks = [];
  List<ShiftVacancy> vacancies = [];
  List<VacancyApplication> applications = [];

  // ─── Смена оператора ───
  Shift? activeShift;
  bool opSelectingRides = false;
  String? currentParkId;

  // ─── Склад ТМЦ ───
  List<InventoryItem> inventoryItems = [];
  List<StorageLocation> storageLocations = [];
  List<StockTransaction> stockTransactions = [];

  // ═══════════ методы с notifyListeners ═══════════

  // (нельзя выносить в extension, так как notifyListeners - protected)
  void setOpSelectingRides(bool v) {
    opSelectingRides = v;
    notifyListeners();
  }

  // ═══════════ save / load / reset ═══════════

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key,
        jsonEncode({
          'cities': cities.map((e) => e.toJson()).toList(),
          'locations': locations.map((e) => e.toJson()).toList(),
          'parks': parks.map((e) => e.toJson()).toList(),
          'regions': regions.map((e) => e.toJson()).toList(),
          'rides': rides.map((e) => e.toJson()).toList(),
          'downtimes': downtimes.map((e) => e.toJson()).toList(),
          'incidents': incidents.map((e) => e.toJson()).toList(),
          'employees': employees.map((e) => e.toJson()).toList(),
          'operatorLinks': operatorLinks.map((e) => e.toJson()).toList(),
          'vacancies': vacancies.map((e) => e.toJson()).toList(),
          'applications': applications.map((e) => e.toJson()).toList(),
          'inventoryItems': inventoryItems.map((e) => e.toJson()).toList(),
          'storageLocations':
              storageLocations.map((e) => e.toJson()).toList(),
          'stockTransactions':
              stockTransactions.map((e) => e.toJson()).toList(),
          'activeShift': activeShift?.toJson(),
          'opSelectingRides': opSelectingRides,
          'currentParkId': currentParkId,
        }));
    notifyListeners();
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    final v8Raw = prefs.getString(_key);
    if (v8Raw != null) {
      try {
        _applyV6(jsonDecode(v8Raw));
        _backfillManagers();
        notifyListeners();
        return;
      } catch (e) {
        debugPrint('Failed to load v8: $e');
      }
    }

    final v7Raw = prefs.getString(_oldKey);
    if (v7Raw != null) {
      try {
        _applyV6(jsonDecode(v7Raw));
        _backfillManagers();
        await save();
        notifyListeners();
        return;
      } catch (e) {
        debugPrint('Failed to migrate v7: $e');
      }
    }

    final v6Raw = prefs.getString(_legacyKey);
    if (v6Raw != null) {
      try {
        _applyV6(jsonDecode(v6Raw));
        _backfillManagers();
        await save();
        notifyListeners();
        return;
      } catch (e) {
        debugPrint('Failed to migrate v6: $e');
      }
    }

    final v5Raw = prefs.getString(_ancientKey);
    if (v5Raw != null) {
      try {
        _applyV5AndMigrate(jsonDecode(v5Raw));
        _backfillManagers();
        await save();
        notifyListeners();
        return;
      } catch (e) {
        debugPrint('Failed to migrate v5: $e');
      }
    }

    _applyV6(_seedJson());
    if (employees.isEmpty) {
      _applyV6(_seedJson());
    }
    _backfillManagers();
    await save();
    notifyListeners();
  }

  Future<void> resetToSeed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    await prefs.remove(_oldKey);
    await prefs.remove(_legacyKey);
    await prefs.remove(_ancientKey);
    _applyV6(_seedJson());
    _backfillManagers();
    activeShift = null;
    opSelectingRides = false;
    currentParkId = null;
    await save();
  }

  // ═══════════ seed / migrate ═══════════

  Map<String, dynamic> _seedJson() {
    final s = buildSeed();
    return {
      'cities': _safeList(s['cities'], (e) => (e as City).toJson()),
      'locations':
          _safeList(s['locations'], (e) => (e as ParkLocation).toJson()),
      'parks': _safeList(s['parks'], (e) => (e as Park).toJson()),
      'regions': _safeList(s['regions'], (e) => (e as Region).toJson()),
      'rides': _safeList(s['rides'], (e) => (e as Ride).toJson()),
      'downtimes':
          _safeList(s['downtimes'], (e) => (e as Downtime).toJson()),
      'incidents':
          _safeList(s['incidents'], (e) => (e as Incident).toJson()),
      'employees':
          _safeList(s['employees'], (e) => (e as Employee).toJson()),
      'operatorLinks': _safeList(
          s['operatorLinks'], (e) => (e as OperatorParkLink).toJson()),
      'vacancies':
          _safeList(s['vacancies'], (e) => (e as ShiftVacancy).toJson()),
      'applications': _safeList(
          s['applications'], (e) => (e as VacancyApplication).toJson()),
      'inventoryItems': _safeList(
          s['inventoryItems'], (e) => (e as InventoryItem).toJson()),
      'storageLocations': _safeList(
          s['storageLocations'], (e) => (e as StorageLocation).toJson()),
      'stockTransactions': _safeList(
          s['stockTransactions'], (e) => (e as StockTransaction).toJson()),
    };
  }

  static List<Map<String, dynamic>> _safeList(
    dynamic raw,
    Map<String, dynamic> Function(Object?) mapper,
  ) {
    if (raw is! List) return [];
    return raw.map(mapper).toList();
  }

  void _applyV6(Map<String, dynamic> j) {
    cities =
        (j['cities'] as List?)?.map((e) => City.fromJson(e)).toList() ?? [];
    locations = (j['locations'] as List?)
            ?.map((e) => ParkLocation.fromJson(e))
            .toList() ??
        [];
    parks =
        (j['parks'] as List?)?.map((e) => Park.fromJson(e)).toList() ?? [];
    regions =
        (j['regions'] as List?)?.map((e) => Region.fromJson(e)).toList() ??
            [];
    rides =
        (j['rides'] as List?)?.map((e) => Ride.fromJson(e)).toList() ?? [];
    downtimes = (j['downtimes'] as List?)
            ?.map((e) => Downtime.fromJson(e))
            .toList() ??
        [];
    incidents = (j['incidents'] as List?)
            ?.map((e) => Incident.fromJson(e))
            .toList() ??
        [];
    employees = (j['employees'] as List?)
            ?.map((e) => Employee.fromJson(e))
            .toList() ??
        [];
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
    inventoryItems = (j['inventoryItems'] as List?)
            ?.map((e) => InventoryItem.fromJson(e))
            .toList() ??
        [];
    storageLocations = (j['storageLocations'] as List?)
            ?.map((e) => StorageLocation.fromJson(e))
            .toList() ??
        [];
    stockTransactions = (j['stockTransactions'] as List?)
            ?.map((e) => StockTransaction.fromJson(e))
            .toList() ??
        [];

    final sh = j['activeShift'];
    activeShift = sh is Map<String, dynamic> ? Shift.fromJson(sh) : null;
    opSelectingRides = j['opSelectingRides'] ?? false;
    currentParkId = j['currentParkId'];
  }

  void _applyV5AndMigrate(Map<String, dynamic> j) {
    cities =
        (j['cities'] as List?)?.map((e) => City.fromJson(e)).toList() ?? [];
    locations = (j['locations'] as List?)
            ?.map((e) => ParkLocation.fromJson(e))
            .toList() ??
        [];
    parks =
        (j['parks'] as List?)?.map((e) => Park.fromJson(e)).toList() ?? [];
    regions =
        (j['regions'] as List?)?.map((e) => Region.fromJson(e)).toList() ??
            [];
    rides =
        (j['rides'] as List?)?.map((e) => Ride.fromJson(e)).toList() ?? [];
    downtimes = (j['downtimes'] as List?)
            ?.map((e) => Downtime.fromJson(e))
            .toList() ??
        [];
    incidents = (j['incidents'] as List?)
            ?.map((e) => Incident.fromJson(e))
            .toList() ??
        [];
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

    final emps = <Employee>[];
    final oldOperators = j['operators'] as List?;
    if (oldOperators != null) {
      for (final o in oldOperators) {
        try {
          emps.add(Employee.fromOldOperator(
              Map<String, dynamic>.from(o as Map)));
        } catch (e) {
          debugPrint('Failed to migrate operator: $e');
        }
      }
    }
    final oldAdmins = j['admins'] as List?;
    if (oldAdmins != null) {
      for (final a in oldAdmins) {
        try {
          emps.add(
              Employee.fromOldAdmin(Map<String, dynamic>.from(a as Map)));
        } catch (e) {
          debugPrint('Failed to migrate admin: $e');
        }
      }
    }
    final oldTechs = j['techs'] as List?;
    if (oldTechs != null) {
      for (final t in oldTechs) {
        try {
          emps.add(Employee.fromOldTech(Map<String, dynamic>.from(t as Map)));
        } catch (e) {
          debugPrint('Failed to migrate tech: $e');
        }
      }
    }
    employees = emps;
    final sh = j['activeShift'];
    activeShift = sh is Map<String, dynamic> ? Shift.fromJson(sh) : null;
    opSelectingRides = j['opSelectingRides'] ?? false;
    currentParkId = j['currentParkId'];
    debugPrint('Migration v5→v8: migrated ${emps.length} employees');
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