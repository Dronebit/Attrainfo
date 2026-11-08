part of '../app_database.dart';

// ═══════════ Орг. структура: города, локации, парки, регионы ═══════════

extension OrgStructureOps on AppDatabase {
  // ─── базовые геттеры ───

  City? cityById(String? id) => cities.firstWhereOrNull((c) => c.id == id);
  ParkLocation? locById(String? id) =>
      locations.firstWhereOrNull((l) => l.id == id);
  Park? parkById(String? id) => parks.firstWhereOrNull((p) => p.id == id);
  Region? regionById(String? id) =>
      regions.firstWhereOrNull((r) => r.id == id);

  String cityOfPark(Park p) {
    final l = locById(p.locId);
    final c = l == null ? null : cityById(l.cityId);
    return c?.name ?? '—';
  }

  // ─── иерархия регион → парки ───

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

  // ─── принадлежность сотрудника к региону/городу ───

  Region? regionOfAdmin(Employee admin) {
    if (admin.role == EmployeeRole.regionalAdmin) {
      return admin.regionId == null ? null : regionById(admin.regionId);
    }
    if (admin.role == EmployeeRole.parkAdmin && admin.parkId != null) {
      final regsOfPark = regionsOfPark(admin.parkId!);
      return regsOfPark.isEmpty ? null : regsOfPark.first;
    }
    return null;
  }

  City? cityOfAdmin(Employee admin) {
    return admin.cityId == null ? null : cityById(admin.cityId);
  }

  City? cityOfEmployee(Employee e) {
    if (e.cityId != null) return cityById(e.cityId);
    if (e.parkId != null) {
      final p = parkById(e.parkId);
      if (p != null) {
        final loc = locById(p.locId);
        if (loc != null) return cityById(loc.cityId);
      }
    }
    if (e.hasRole(EmployeeRole.operator)) {
      final approved = approvedParkIdsForOperator(e.id);
      if (approved.isNotEmpty) {
        final p = parkById(approved.first);
        if (p != null) {
          final loc = locById(p.locId);
          if (loc != null) return cityById(loc.cityId);
        }
      }
    }
    for (final h in e.history.reversed) {
      if (h.parkId != null) {
        final p = parkById(h.parkId);
        if (p != null) {
          final loc = locById(p.locId);
          if (loc != null) return cityById(loc.cityId);
        }
      }
    }
    return null;
  }

  bool isEmployeeInRegion(Employee e, String regionId) {
    if (e.regionId == regionId) return true;

    if (e.parkId != null) {
      if (regionsOfPark(e.parkId!).any((r) => r.id == regionId)) return true;
    }

    if (e.hasRole(EmployeeRole.operator)) {
      if (approvedParkIdsForOperator(e.id)
          .any((pid) => regionsOfPark(pid).any((r) => r.id == regionId))) {
        return true;
      }
    }

    if (e.cityId != null) {
      final region = regionById(regionId);
      if (region != null) {
        final locsInCity = locations
            .where((l) => l.cityId == e.cityId)
            .map((l) => l.id)
            .toSet();
        final parksInCity = parks
            .where((p) => locsInCity.contains(p.locId))
            .map((p) => p.id)
            .toSet();
        if (region.parkIds.any((pid) => parksInCity.contains(pid))) {
          return true;
        }
      }
    }

    for (final h in e.history) {
      if (h.regionId == regionId) return true;
      if (h.parkId != null &&
          regionsOfPark(h.parkId!).any((r) => r.id == regionId)) {
        return true;
      }
    }

    return false;
  }

  // ─── CRUD регионов ───

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
      _normalizeManager(e);
      _normalizeReportsOf(e);
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
}