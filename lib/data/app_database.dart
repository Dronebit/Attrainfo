import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/enums.dart';
import '../models/models.dart';
import '../models/employee.dart';
import '../models/operator_park_link.dart';
import '../models/shift_vacancy.dart';
import '../models/shift.dart';
import '../models/region.dart';
import 'seed.dart';

class AppDatabase extends ChangeNotifier {
  static const _key = 'attrakontrol-v8';
  static const _oldKey = 'attrakontrol-v7';
  static const _legacyKey = 'attrakontrol-v6';
  static const _ancientKey = 'attrakontrol-v5';
  static const masterPin = '9999';

  List<City> cities = [];
  List<ParkLocation> locations = [];
  List<Park> parks = [];
  List<Ride> rides = [];
  List<Downtime> downtimes = [];
  List<Incident> incidents = [];
  List<Employee> employees = [];
  List<OperatorParkLink> operatorLinks = [];
  List<ShiftVacancy> vacancies = [];
  List<VacancyApplication> applications = [];
  List<Region> regions = [];

  Shift? activeShift;
  bool opSelectingRides = false;
  String? currentParkId;

  // ═══════════ базовые геттеры ═══════════

  City? cityById(String? id) => cities.firstWhereOrNull((c) => c.id == id);
  ParkLocation? locById(String? id) =>
      locations.firstWhereOrNull((l) => l.id == id);
  Park? parkById(String? id) => parks.firstWhereOrNull((p) => p.id == id);
  Ride? rideById(String? id) => rides.firstWhereOrNull((r) => r.id == id);
  ShiftVacancy? vacancyById(String? id) =>
      vacancies.firstWhereOrNull((v) => v.id == id);
  VacancyApplication? applicationById(String? id) =>
      applications.firstWhereOrNull((a) => a.id == id);
  Region? regionById(String? id) =>
      regions.firstWhereOrNull((r) => r.id == id);

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

  // ═══════════ сотрудники ═══════════

  Employee? employeeById(String? id) =>
      employees.firstWhereOrNull((e) => e.id == id);

  Employee? employeeByPin(String? pin) {
    if (pin == null || pin.isEmpty) return null;
    return employees.firstWhereOrNull(
        (e) => e.status == EmployeeStatus.active && e.pin == pin);
  }

  Employee? employeeByBadge(String? uid) {
    if (uid == null || uid.isEmpty) return null;
    return employees.firstWhereOrNull((e) => e.badgeId == uid);
  }

  Employee? operatorById(String? id) {
    final e = employeeById(id);
    return (e != null && e.hasRole(EmployeeRole.operator)) ? e : null;
  }

  Employee? operatorByBadge(String? uid) => employeeByBadge(uid);

  Employee? adminById(String? id) {
    final e = employeeById(id);
    return (e != null && e.isAdmin) ? e : null;
  }

  Employee? adminByPin(String? pin) {
    final e = employeeByPin(pin);
    return (e != null && e.isAdmin) ? e : null;
  }

  Employee? techById(String? id) {
    final e = employeeById(id);
    return (e != null && e.hasRole(EmployeeRole.technician)) ? e : null;
  }

  // ═══════════ списки по ролям ═══════════

  List<Employee> get operators =>
      employees.where((e) => e.hasRole(EmployeeRole.operator)).toList();

  List<Employee> get admins =>
      employees.where((e) => e.isAdmin).toList();

  List<Employee> get technicians =>
      employees.where((e) => e.hasRole(EmployeeRole.technician)).toList();

  List<Employee> get superAdmins => employees
      .where((e) =>
          e.role == EmployeeRole.superAdmin &&
          e.status == EmployeeStatus.active)
      .toList();

  List<Employee> regionalAdminsOf(String regId) => employees
      .where((e) =>
          e.role == EmployeeRole.regionalAdmin &&
          e.regionId == regId &&
          e.status == EmployeeStatus.active)
      .toList();

  List<Employee> parkAdminsOf(String parkId) => employees
      .where((e) =>
          e.role == EmployeeRole.parkAdmin &&
          e.parkId == parkId &&
          e.status == EmployeeStatus.active)
      .toList();

  // ═══════════ иерархия ═══════════

  List<Employee> allowedManagersFor(Employee e) {
    final roles = e.role.allowedManagerRoles;
    return employees
        .where((x) =>
            x.id != e.id &&
            x.status == EmployeeStatus.active &&
            roles.contains(x.role))
        .toList()
      ..sort((a, b) {
        if (a.role.level != b.role.level) {
          return b.role.level.compareTo(a.role.level);
        }
        return a.name.compareTo(b.name);
      });
  }

  bool wouldCreateCycle(String employeeId, String managerId) {
    String? current = managerId;
    final visited = <String>{};
    while (current != null) {
      if (current == employeeId) return true;
      if (!visited.add(current)) return true;
      current = employeeById(current)?.managerId;
    }
    return false;
  }

  List<Employee> directReports(String managerId) => employees
      .where((e) =>
          e.status != EmployeeStatus.fired &&
          e.id != managerId &&
          (e.managerId == managerId ||
              e.additionalManagerIds.contains(managerId)))
      .toList()
    ..sort((a, b) {
      if (a.role.level != b.role.level) {
        return b.role.level.compareTo(a.role.level);
      }
      return a.name.compareTo(b.name);
    });

  List<Employee> managersOf(Employee e) {
    final ids = e.allManagerIds.toSet();
    return ids
        .map(employeeById)
        .whereType<Employee>()
        .where((m) => m.status != EmployeeStatus.fired)
        .toList()
      ..sort((a, b) {
        if (a.role.level != b.role.level) {
          return b.role.level.compareTo(a.role.level);
        }
        return a.name.compareTo(b.name);
      });
  }

  List<Employee> rootEmployees() {
    return employees.where((e) {
      if (e.status == EmployeeStatus.fired) return false;
      if (e.managerId == null) return true;
      final mgr = employeeById(e.managerId);
      if (mgr == null) return true;
      if (mgr.status == EmployeeStatus.fired) return true;
      return false;
    }).toList()
      ..sort((a, b) {
        if (a.role.level != b.role.level) {
          return b.role.level.compareTo(a.role.level);
        }
        return a.name.compareTo(b.name);
      });
  }

  void _backfillManagers() {
    for (final e in employees) {
      if (e.managerId != null) continue;
      if (e.role == EmployeeRole.superAdmin) continue;

      if (e.role == EmployeeRole.regionalAdmin && e.regionId != null) {
        final superAdmin = employees.firstWhereOrNull((x) =>
            x.role == EmployeeRole.superAdmin &&
            x.status == EmployeeStatus.active);
        if (superAdmin != null) e.managerId = superAdmin.id;
      } else if (e.role == EmployeeRole.parkAdmin && e.parkId != null) {
        final regions = regionsOfPark(e.parkId!);
        if (regions.isNotEmpty) {
          final regionAdmin = employees.firstWhereOrNull((x) =>
              x.role == EmployeeRole.regionalAdmin &&
              x.regionId == regions.first.id &&
              x.status == EmployeeStatus.active);
          if (regionAdmin != null) {
            e.managerId = regionAdmin.id;
          } else {
            final superAdmin = employees.firstWhereOrNull((x) =>
                x.role == EmployeeRole.superAdmin &&
                x.status == EmployeeStatus.active);
            if (superAdmin != null) e.managerId = superAdmin.id;
          }
        }
      } else if (e.role == EmployeeRole.operator ||
          e.role == EmployeeRole.technician) {
        String? parkForManager = e.parkId;
        if (parkForManager == null && e.role == EmployeeRole.operator) {
          final links = linksForOperator(e.id)
              .where((l) => l.status == LinkStatus.approved)
              .toList();
          if (links.isNotEmpty) parkForManager = links.first.parkId;
        }
        if (parkForManager != null) {
          final parkAdmin = employees.firstWhereOrNull((x) =>
              x.role == EmployeeRole.parkAdmin &&
              x.parkId == parkForManager &&
              x.status == EmployeeStatus.active);
          if (parkAdmin != null) e.managerId = parkAdmin.id;
        }
      }
    }
  }

  // ═══════════ регионы ═══════════

  List<Park> parksOfRegion(String regId) {
    final region = regionById(regId);
    if (region == null) return [];
    return region.parkIds.map(parkById).whereType<Park>().toList();
  }

  List<Region> regionsOfPark(String parkId) =>
      regions.where((r) => r.parkIds.contains(parkId)).toList();

  List<Park> get unassignedParks {
    final assigned = <String>{};
    for (final r in regions) {
      assigned.addAll(r.parkIds);
    }
    return parks.where((p) => !assigned.contains(p.id)).toList();
  }

  List<City> citiesOfRegion(String regId) {
    final region = regionById(regId);
    if (region == null) return [];
    final cityIds = <String>{};
    for (final parkId in region.parkIds) {
      final park = parkById(parkId);
      if (park == null) continue;
      final loc = locById(park.locId);
      if (loc == null) continue;
      cityIds.add(loc.cityId);
    }
    return cityIds
        .map(cityById)
        .whereType<City>()
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  Map<City, Map<ParkLocation, List<Park>>> parksOfRegionHierarchy(
      String regId) {
    final region = regionById(regId);
    if (region == null) return {};
    final result = <City, Map<ParkLocation, List<Park>>>{};

    for (final parkId in region.parkIds) {
      final park = parkById(parkId);
      if (park == null) continue;
      final loc = locById(park.locId);
      if (loc == null) continue;
      final city = cityById(loc.cityId);
      if (city == null) continue;

      result.putIfAbsent(city, () => {});
      result[city]!.putIfAbsent(loc, () => []);
      result[city]![loc]!.add(park);
    }
    return result;
  }

  Region? regionOfAdmin(Employee admin) {
    if (admin.role == EmployeeRole.regionalAdmin) {
      return admin.regionId == null ? null : regionById(admin.regionId);
    }
    if (admin.role == EmployeeRole.parkAdmin && admin.parkId != null) {
      final regionsOfPark = this.regionsOfPark(admin.parkId!);
      return regionsOfPark.isEmpty ? null : regionsOfPark.first;
    }
    return null;
  }

  City? cityOfAdmin(Employee admin) {
    if (admin.role == EmployeeRole.parkAdmin && admin.parkId != null) {
      final park = parkById(admin.parkId);
      if (park == null) return null;
      final loc = locById(park.locId);
      return loc == null ? null : cityById(loc.cityId);
    }
    if (admin.lastCityId != null) {
      return cityById(admin.lastCityId);
    }
    return null;
  }

  // ═══════════ регионы CRUD ═══════════

  Region createRegion(String name, {List<String>? parkIds}) {
    final region = Region(
      id: 'reg${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      parkIds: parkIds ?? [],
    );
    for (final pid in region.parkIds) {
      _detachParkFromOtherRegions(pid, region.id);
    }
    regions.add(region);
    save();
    return region;
  }

  void updateRegion(String regId, String name, List<String> parkIds) {
    final region = regionById(regId);
    if (region == null) return;
    region.name = name;
    for (final pid in parkIds) {
      _detachParkFromOtherRegions(pid, regId);
    }
    region.parkIds = List.from(parkIds);
    save();
  }

  void deleteRegion(String regId) {
    regions.removeWhere((r) => r.id == regId);
    for (final e in employees.where(
        (e) => e.role == EmployeeRole.regionalAdmin && e.regionId == regId)) {
      e.status = EmployeeStatus.fired;
      e.statusChangedAt = DateTime.now();
    }
    save();
  }

  void _detachParkFromOtherRegions(String parkId, String exceptRegId) {
    for (final r in regions) {
      if (r.id == exceptRegId) continue;
      r.parkIds.remove(parkId);
    }
  }

  void addParkToRegion(String regId, String parkId) {
    final region = regionById(regId);
    if (region == null) return;
    _detachParkFromOtherRegions(parkId, regId);
    if (!region.parkIds.contains(parkId)) {
      region.parkIds.add(parkId);
      save();
    }
  }

  void removeParkFromRegion(String regId, String parkId) {
    final region = regionById(regId);
    if (region == null) return;
    region.parkIds.remove(parkId);
    save();
  }

  // ═══════════ назначение / снятие админов ═══════════

  void assignAdminToPark(Employee admin, Park park, {String? reason}) {
    final now = DateTime.now();
    final oldParkId = admin.parkId;

    _closeCurrentHistory(admin, reason ?? 'Назначен администратором');

    if (oldParkId != null && oldParkId != park.id) {
      final oldPark = parkById(oldParkId);
      if (oldPark != null) {
        _detachFromParkStaff(admin, oldPark);
      }
    }

    admin.history.add(RoleHistoryEntry(
      id: 'h${DateTime.now().microsecondsSinceEpoch}',
      role: EmployeeRole.parkAdmin,
      parkId: park.id,
      startedAt: now,
    ));

    admin.role = EmployeeRole.parkAdmin;
    admin.parkId = park.id;
    admin.regionId = null;
    admin.status = EmployeeStatus.active;
    admin.statusChangedAt = now;

    final loc = locById(park.locId);
    if (loc != null) admin.lastCityId = loc.cityId;

    if (oldParkId != null &&
        oldParkId != park.id &&
        parkAdminsOf(oldParkId).isEmpty) {
      for (final reg in regionsOfPark(oldParkId)) {
        for (final ra in regionalAdminsOf(reg.id)) {
          _subordinateOrphanParkStaff(ra, reg);
        }
      }
    }

    _autoAssignManager(admin, park);
    _subordinateParkStaffTo(admin, park);

    save();
  }

  void removeAdminFromPark(Employee admin, {String? byAdminId}) {
    final now = DateTime.now();
    final removedParkId = admin.parkId;

    _closeCurrentHistory(admin, 'Снят с должности');

    admin.role = EmployeeRole.parkAdmin;
    admin.parkId = null;
    admin.regionId = null;
    admin.status = EmployeeStatus.active;
    admin.statusChangedAt = now;

    if (byAdminId != null) {
      admin.managerId = byAdminId;
    }

    if (removedParkId != null) {
      final park = parkById(removedParkId);
      if (park != null) {
        _detachFromParkStaff(admin, park);

        if (parkAdminsOf(removedParkId).isEmpty) {
          for (final reg in regionsOfPark(removedParkId)) {
            for (final ra in regionalAdminsOf(reg.id)) {
              _subordinateOrphanParkStaff(ra, reg);
            }
          }
        }
      }
    }

    save();
  }

  void assignRegionalAdmin(Employee admin, Region region, {String? reason}) {
    final now = DateTime.now();
    final oldParkId = admin.parkId;
    final oldRegionId = admin.regionId;

    _closeCurrentHistory(
        admin, reason ?? 'Назначен региональным администратором');

    if (oldParkId != null) {
      final oldPark = parkById(oldParkId);
      if (oldPark != null) _detachFromParkStaff(admin, oldPark);
    }
    if (oldRegionId != null && oldRegionId != region.id) {
      final oldRegion = regionById(oldRegionId);
      if (oldRegion != null) _detachFromRegionStaff(admin, oldRegion);
    }

    admin.history.add(RoleHistoryEntry(
      id: 'h${DateTime.now().microsecondsSinceEpoch}',
      role: EmployeeRole.regionalAdmin,
      regionId: region.id,
      startedAt: now,
    ));

    admin.role = EmployeeRole.regionalAdmin;
    admin.regionId = region.id;
    admin.parkId = null;
    admin.status = EmployeeStatus.active;
    admin.statusChangedAt = now;

    final superAdmin = superAdmins.firstWhereOrNull((s) => s.id != admin.id);
    if (superAdmin != null) admin.managerId = superAdmin.id;

    _subordinateOrphanParkStaff(admin, region);

    final superId = superAdmin?.id;
    for (final pid in region.parkIds) {
      for (final pa in parkAdminsOf(pid)) {
        if (pa.id == admin.id) continue;
        if (pa.managerId == null || pa.managerId == superId) {
          pa.managerId = admin.id;
        }
      }
    }

    save();
  }

  void removeRegionalAdmin(Employee admin, {String? byAdminId}) {
    final now = DateTime.now();
    final removedRegionId = admin.regionId;

    _closeCurrentHistory(admin, 'Снят с должности');

    admin.role = EmployeeRole.regionalAdmin;
    admin.regionId = null;
    admin.parkId = null;
    admin.status = EmployeeStatus.active;
    admin.statusChangedAt = now;

    if (byAdminId != null) {
      admin.managerId = byAdminId;
    }

    if (removedRegionId != null) {
      final region = regionById(removedRegionId);
      if (region != null) {
        _detachFromRegionStaff(admin, region);

        final replacementRegAdmin = regionalAdminsOf(region.id)
            .firstWhereOrNull((x) => x.id != admin.id);
        final replacementSuper = superAdmins
            .firstWhereOrNull((x) => x.id != admin.id);
        final replacementId =
            replacementRegAdmin?.id ?? replacementSuper?.id;

        for (final pid in region.parkIds) {
          for (final pa in parkAdminsOf(pid)) {
            if (pa.id == admin.id) continue;
            if (pa.managerId == admin.id) {
              pa.managerId = replacementId;
            }
            pa.additionalManagerIds.remove(admin.id);
          }
        }
      }
    }

    save();
  }

  void _closeCurrentHistory(Employee e, String reason) {
    final now = DateTime.now();
    for (final h in e.history) {
      if (h.isCurrent) {
        h.endedAt = now;
        h.reason = reason;
      }
    }
  }

  void _autoAssignManager(Employee admin, Park park) {
    final regs = regionsOfPark(park.id);
    if (regs.isNotEmpty) {
      final regionAdmin = employees.firstWhereOrNull((x) =>
          x.role == EmployeeRole.regionalAdmin &&
          x.regionId == regs.first.id &&
          x.status == EmployeeStatus.active);
      if (regionAdmin != null) {
        admin.managerId = regionAdmin.id;
        return;
      }
    }
    final superAdmin = superAdmins.isNotEmpty ? superAdmins.first : null;
    if (superAdmin != null) {
      admin.managerId = superAdmin.id;
    }
  }

  void _subordinateParkStaffTo(Employee admin, Park park) {
    bool needsAdditional(Employee e) {
      if (e.managerId == null) return false;
      if (e.managerId == admin.id) return false;
      final cur = employeeById(e.managerId);
      return cur != null && cur.status != EmployeeStatus.fired;
    }

    void addManager(Employee e) {
      if (e.id == admin.id) return;
      if (e.managerId == admin.id) return;
      if (e.additionalManagerIds.contains(admin.id)) return;
      if (needsAdditional(e)) {
        e.additionalManagerIds.add(admin.id);
      } else {
        e.managerId = admin.id;
        e.additionalManagerIds.remove(admin.id);
      }
    }

    final regionAdminIds = <String>{};
    for (final reg in regionsOfPark(park.id)) {
      for (final ra in regionalAdminsOf(reg.id)) {
        if (ra.id != admin.id) regionAdminIds.add(ra.id);
      }
    }

    void removeRegionAdmins(Employee e) {
      for (final id in regionAdminIds) {
        if (e.managerId == id) e.managerId = null;
        e.additionalManagerIds.remove(id);
      }
    }

    for (final link in operatorLinks) {
      if (link.parkId == park.id && link.status == LinkStatus.approved) {
        final op = employeeById(link.operatorId);
        if (op != null && op.status != EmployeeStatus.fired) {
          removeRegionAdmins(op);
          addManager(op);
        }
      }
    }

    for (final e in employees) {
      if (e.status == EmployeeStatus.fired) continue;
      if (e.hasRole(EmployeeRole.technician) && e.parkId == park.id) {
        removeRegionAdmins(e);
        addManager(e);
      }
    }
  }

  void _subordinateOrphanParkStaff(Employee admin, Region region) {
    bool needsAdditional(Employee e) {
      if (e.managerId == null) return false;
      if (e.managerId == admin.id) return false;
      final cur = employeeById(e.managerId);
      return cur != null && cur.status != EmployeeStatus.fired;
    }

    void addManager(Employee e) {
      if (e.id == admin.id) return;
      if (e.managerId == admin.id) return;
      if (e.additionalManagerIds.contains(admin.id)) return;
      if (needsAdditional(e)) {
        e.additionalManagerIds.add(admin.id);
      } else {
        e.managerId = admin.id;
        e.additionalManagerIds.remove(admin.id);
      }
    }

    for (final pid in region.parkIds) {
      if (parkAdminsOf(pid).isNotEmpty) continue;

      for (final link in operatorLinks) {
        if (link.parkId == pid && link.status == LinkStatus.approved) {
          final op = employeeById(link.operatorId);
          if (op != null && op.status != EmployeeStatus.fired) {
            addManager(op);
          }
        }
      }

      for (final e in employees) {
        if (e.status == EmployeeStatus.fired) continue;
        if (e.hasRole(EmployeeRole.technician) && e.parkId == pid) {
          addManager(e);
        }
      }
    }
  }

  void _detachFromParkStaff(Employee admin, Park park) {
    for (final link in operatorLinks) {
      if (link.parkId == park.id && link.status == LinkStatus.approved) {
        final op = employeeById(link.operatorId);
        if (op != null) {
          if (op.managerId == admin.id) op.managerId = null;
          op.additionalManagerIds.remove(admin.id);
        }
      }
    }
    for (final e in employees) {
      if (e.hasRole(EmployeeRole.technician) && e.parkId == park.id) {
        if (e.managerId == admin.id) e.managerId = null;
        e.additionalManagerIds.remove(admin.id);
      }
    }
  }

  void _detachFromRegionStaff(Employee admin, Region region) {
    for (final pid in region.parkIds) {
      final park = parkById(pid);
      if (park != null) _detachFromParkStaff(admin, park);
    }
  }

  // ═══════════ операции с сотрудниками ═══════════

  bool setManagers(Employee e, String? primaryId, List<String> extras) {
    if (primaryId != null && wouldCreateCycle(e.id, primaryId)) return false;
    e.managerId = primaryId;
    e.additionalManagerIds =
        extras.where((id) => id != primaryId).toList();
    save();
    return true;
  }

  /// Меняет роли сотрудника (основную + дополнительные), ведёт историю.
  ///
  /// При понижении с parkAdmin — отвязывает операторов/техников парка.
  /// При понижении с regionalAdmin — отвязывает операторов/техников региона.
  /// При повышении до parkAdmin (был operator/technician) — если есть
  /// approved-парк оператора, привязывает к нему и подчиняет сотрудников.
  void setRoles(Employee e, EmployeeRole primary, List<EmployeeRole> extras) {
    final now = DateTime.now();
    final oldPrimary = e.role;
    final oldExtras = List<EmployeeRole>.from(e.additionalRoles);

    if (oldPrimary != primary) {
      _closeCurrentHistory(
          e, 'Смена основной роли: ${oldPrimary.label} → ${primary.label}');
      e.history.add(RoleHistoryEntry(
        id: 'h${DateTime.now().microsecondsSinceEpoch}',
        role: primary,
        parkId: e.parkId,
        regionId: e.regionId,
        startedAt: now,
      ));
    }

    e.role = primary;
    e.additionalRoles = List.from(extras);

    for (final r in extras) {
      if (!oldExtras.contains(r)) {
        e.history.add(RoleHistoryEntry(
          id: 'h${DateTime.now().microsecondsSinceEpoch}_${r.name}',
          role: r,
          parkId: e.parkId,
          regionId: e.regionId,
          startedAt: now,
          reason: 'Добавлена дополнительная роль',
        ));
      }
    }

    for (final r in oldExtras) {
      if (!extras.contains(r) && r != primary) {
        for (final h in e.history) {
          if (h.isCurrent && h.role == r) {
            h.endedAt = now;
            h.reason = 'Снята дополнительная роль';
          }
        }
      }
    }

    // Понижение с parkAdmin — отвязываем парк и подчинённых
    if (oldPrimary == EmployeeRole.parkAdmin &&
        primary != EmployeeRole.parkAdmin) {
      final oldParkId = e.parkId;
      if (oldParkId != null) {
        final oldPark = parkById(oldParkId);
        if (oldPark != null) _detachFromParkStaff(e, oldPark);
        e.parkId = null;
      }
    }

    // Понижение с regionalAdmin — отвязываем регион и подчинённых
    if (oldPrimary == EmployeeRole.regionalAdmin &&
        primary != EmployeeRole.regionalAdmin) {
      final oldRegionId = e.regionId;
      if (oldRegionId != null) {
        final oldRegion = regionById(oldRegionId);
        if (oldRegion != null) _detachFromRegionStaff(e, oldRegion);
        e.regionId = null;
      }
    }

    // Повышение до parkAdmin — если parkId ещё не установлен,
    // взять approved-парк оператора (чтобы не остался «свободным»)
    if (primary == EmployeeRole.parkAdmin &&
        oldPrimary != EmployeeRole.parkAdmin &&
        e.parkId == null) {
      final approvedParks = approvedParkIdsForOperator(e.id);
      if (approvedParks.isNotEmpty) {
        e.parkId = approvedParks.first;
        e.regionId = null;
      }
    }

    // Стал parkAdmin с известным parkId — подчинить парк
    if (e.role == EmployeeRole.parkAdmin && e.parkId != null) {
      final park = parkById(e.parkId!);
      if (park != null) {
        _autoAssignManager(e, park);
        _subordinateParkStaffTo(e, park);
      }
    }

    save();
  }

  /// Переводит сотрудника в парк.
  ///
  /// Для операторов — переоформляет связь (reject старых + create новой).
  /// Если сотрудник — админ парка, ему проставляется parkId, назначается
  /// руководитель (рег. админ/super) и подчиняются операторы/техники парка.
  /// Если он переезжает из другого парка — отвязывается от старого,
  /// а старый парк, если остался без админа, возвращается под рег. админа.
  void moveToPark(Employee e, String parkId, {String? byAdminId}) {
    final now = DateTime.now();
    final oldParkId = e.parkId;
    _closeCurrentHistory(e, 'Переведён в другой парк');

    final wasParkAdmin = e.hasRole(EmployeeRole.parkAdmin);

    if (e.hasRole(EmployeeRole.operator)) {
      for (final l in linksForOperator(e.id).toList()) {
        if (l.status == LinkStatus.approved) {
          l.status = LinkStatus.rejected;
        }
      }
      operatorLinks.removeWhere((l) =>
          l.operatorId == e.id &&
          l.parkId == parkId &&
          l.status == LinkStatus.rejected);

      if (byAdminId != null) {
        operatorLinks.add(OperatorParkLink(
          id: 'lnk${DateTime.now().microsecondsSinceEpoch}',
          operatorId: e.id,
          parkId: parkId,
          status: LinkStatus.approved,
          initiatorAdminId: byAdminId,
          approverAdminId: byAdminId,
          approvedAt: now,
        ));
      } else {
        createLinkRequest(e.id, parkId, initiatorAdminId: byAdminId);
      }
      e.parkId = null;
    } else {
      e.parkId = parkId;
    }

    e.regionId = null;
    e.status = EmployeeStatus.active;
    e.statusChangedAt = now;

    final park = parkById(parkId);
    if (park != null) {
      final loc = locById(park.locId);
      if (loc != null) e.lastCityId = loc.cityId;

      if (wasParkAdmin) {
        if (oldParkId != null && oldParkId != parkId) {
          final oldPark = parkById(oldParkId);
          if (oldPark != null) {
            _detachFromParkStaff(e, oldPark);
            if (parkAdminsOf(oldParkId).isEmpty) {
              for (final reg in regionsOfPark(oldParkId)) {
                for (final ra in regionalAdminsOf(reg.id)) {
                  _subordinateOrphanParkStaff(ra, reg);
                }
              }
            }
          }
        }

        e.parkId = parkId;
        _autoAssignManager(e, park);
        _subordinateParkStaffTo(e, park);
      } else {
        final parkAdmin =
            parkAdminsOf(parkId).firstWhereOrNull((a) => a.id != e.id);
        if (parkAdmin != null) e.managerId = parkAdmin.id;
      }
    }

    e.history.add(RoleHistoryEntry(
      id: 'h${DateTime.now().microsecondsSinceEpoch}',
      role: e.role,
      parkId: parkId,
      startedAt: now,
    ));

    save();
  }

  void moveToRegion(Employee e, String regionId, {String? byAdminId}) {
    final now = DateTime.now();
    final oldParkId = e.parkId;
    final oldRegionId = e.regionId;

    _closeCurrentHistory(e, 'Переведён в другой регион');

    if (oldParkId != null) {
      final oldPark = parkById(oldParkId);
      if (oldPark != null) {
        _detachFromParkStaff(e, oldPark);
        if (parkAdminsOf(oldParkId).isEmpty) {
          for (final reg in regionsOfPark(oldParkId)) {
            for (final ra in regionalAdminsOf(reg.id)) {
              _subordinateOrphanParkStaff(ra, reg);
            }
          }
        }
      }
    }
    if (oldRegionId != null && oldRegionId != regionId) {
      final oldRegion = regionById(oldRegionId);
      if (oldRegion != null) _detachFromRegionStaff(e, oldRegion);
    }

    e.history.add(RoleHistoryEntry(
      id: 'h${DateTime.now().microsecondsSinceEpoch}',
      role: EmployeeRole.regionalAdmin,
      regionId: regionId,
      startedAt: now,
    ));
    e.role = EmployeeRole.regionalAdmin;
    e.regionId = regionId;
    e.parkId = null;
    e.status = EmployeeStatus.active;
    e.statusChangedAt = now;

    if (byAdminId != null) {
      e.managerId = byAdminId;
    } else {
      final superAdmin = superAdmins.isNotEmpty ? superAdmins.first : null;
      if (superAdmin != null) e.managerId = superAdmin.id;
    }

    final newRegion = regionById(regionId);
    if (newRegion != null) _subordinateOrphanParkStaff(e, newRegion);

    save();
  }

  /// Отвязывает сотрудника от парка/региона.
  ///
  /// [clearManager] — если true, сразу очистить руководителя и доп.
  /// руководителей. По умолчанию менеджер не трогается — UI может
  /// спросить об этом отдельно.
  void detachFromPark(Employee e, {bool clearManager = false}) {
    final now = DateTime.now();
    _closeCurrentHistory(e, 'Отвязан от парка');

    if (e.hasRole(EmployeeRole.operator)) {
      for (final l in linksForOperator(e.id).toList()) {
        l.status = LinkStatus.rejected;
      }
    }

    e.parkId = null;
    e.regionId = null;
    e.status = EmployeeStatus.active;
    e.statusChangedAt = now;

    if (clearManager) {
      e.managerId = null;
      e.additionalManagerIds.clear();
    }

    e.history.add(RoleHistoryEntry(
      id: 'h${DateTime.now().microsecondsSinceEpoch}',
      role: e.role,
      startedAt: now,
    ));

    save();
  }

  /// Очищает руководителя у сотрудника (без отвязки от парка).
  void clearManager(Employee e) {
    e.managerId = null;
    e.additionalManagerIds.clear();
    save();
  }

  void fireEmployee(Employee e) {
    final now = DateTime.now();
    _closeCurrentHistory(e, 'Уволен');

    if (e.hasRole(EmployeeRole.operator)) {
      for (final l in linksForOperator(e.id).toList()) {
        l.status = LinkStatus.rejected;
      }
    }

    e.status = EmployeeStatus.fired;
    e.statusChangedAt = now;
    e.parkId = null;
    e.regionId = null;

    save();
  }

  // ═══════════ связи оператор ↔ парк ═══════════

  List<OperatorParkLink> linksForOperator(String opId) =>
      operatorLinks.where((l) => l.operatorId == opId).toList();

  List<String> approvedParkIdsForOperator(String opId) => operatorLinks
      .where((l) => l.operatorId == opId && l.status == LinkStatus.approved)
      .map((l) => l.parkId)
      .toList();

  List<Park> approvedParksForOperator(String opId) =>
      approvedParkIdsForOperator(opId)
          .map(parkById)
          .whereType<Park>()
          .toList();

  List<OperatorParkLink> pendingLinksForPark(String parkId) => operatorLinks
      .where((l) => l.parkId == parkId && l.status == LinkStatus.pending)
      .toList();

  List<Employee> operatorsOfPark(String parkId) => operatorLinks
      .where((l) => l.parkId == parkId && l.status == LinkStatus.approved)
      .map((l) => operatorById(l.operatorId))
      .whereType<Employee>()
      .toList();

  void createLinkRequest(
    String operatorId,
    String parkId, {
    String? initiatorAdminId,
    String? note,
  }) {
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

  // ═══════════ вакансии ═══════════

  List<ShiftVacancy> vacanciesForPark(String parkId) => vacancies
      .where((v) => v.parkId == parkId)
      .toList()
    ..sort((a, b) => a.date.compareTo(b.date));

  List<ShiftVacancy> openVacanciesForOperator(String opId) {
    final myParks = approvedParksForOperator(opId);
    final myCityIds = myParks
        .map((p) {
          final l = locById(p.locId);
          return l?.cityId;
        })
        .whereType<String>()
        .toSet();
    return vacancies.where((v) {
      if (v.status != VacancyStatus.open) return false;
      if (!v.date.isAfter(
          DateTime.now().subtract(const Duration(days: 1)))) {
        return false;
      }
      final p = parkById(v.parkId);
      if (p == null) return false;
      final l = locById(p.locId);
      if (l == null) return false;
      return myCityIds.contains(l.cityId);
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  List<VacancyApplication> applicationsForVacancy(String vacancyId) =>
      applications.where((a) => a.vacancyId == vacancyId).toList();

  List<VacancyApplication> applicationsForOperator(String opId) =>
      applications.where((a) => a.operatorId == opId).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  bool canOperatorApply(String opId, String vacancyId) {
    final v = vacancyById(vacancyId);
    if (v == null || v.status != VacancyStatus.open) return false;
    final already = applications.firstWhereOrNull((a) =>
        a.vacancyId == vacancyId &&
        a.operatorId == opId &&
        (a.status == ApplicationStatus.pending ||
            a.status == ApplicationStatus.approved));
    if (already != null) return false;
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
    final v = vacancyById(a.vacancyId);
    if (v != null) {
      final approved = applications
          .where((x) =>
              x.vacancyId == v.id &&
              x.status == ApplicationStatus.approved)
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

  // ═══════════ смена (реальная) ═══════════

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

  // ═══════════ аналитика ═══════════

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

  // ═══════════ save / load / migrate ═══════════

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key,
        jsonEncode({
          'cities': cities.map((e) => e.toJson()).toList(),
          'locations': locations.map((e) => e.toJson()).toList(),
          'parks': parks.map((e) => e.toJson()).toList(),
          'rides': rides.map((e) => e.toJson()).toList(),
          'downtimes': downtimes.map((e) => e.toJson()).toList(),
          'incidents': incidents.map((e) => e.toJson()).toList(),
          'employees': employees.map((e) => e.toJson()).toList(),
          'operatorLinks': operatorLinks.map((e) => e.toJson()).toList(),
          'vacancies': vacancies.map((e) => e.toJson()).toList(),
          'applications': applications.map((e) => e.toJson()).toList(),
          'regions': regions.map((e) => e.toJson()).toList(),
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
        final j = jsonDecode(v7Raw);
        _applyV6(j);
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
        final j = jsonDecode(v6Raw);
        _applyV6(j);
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
        final j = jsonDecode(v5Raw);
        _applyV5AndMigrate(j);
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

  Map<String, dynamic> _seedJson() {
    final s = buildSeed();
    return {
      'cities': _safeList(s['cities'], (e) => (e as City).toJson()),
      'locations':
          _safeList(s['locations'], (e) => (e as ParkLocation).toJson()),
      'parks': _safeList(s['parks'], (e) => (e as Park).toJson()),
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
      'regions': _safeList(s['regions'], (e) => (e as Region).toJson()),
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
    regions =
        (j['regions'] as List?)?.map((e) => Region.fromJson(e)).toList() ??
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
    regions =
        (j['regions'] as List?)?.map((e) => Region.fromJson(e)).toList() ??
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