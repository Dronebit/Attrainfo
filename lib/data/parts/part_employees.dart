part of '../app_database.dart';

// ═══════════ Сотрудники, иерархия, назначения, роли ═══════════

extension _EmployeesOps on AppDatabase {
  // ─── базовые геттеры ───

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

  ShiftVacancy? vacancyById(String? id) =>
      vacancies.firstWhereOrNull((v) => v.id == id);

  VacancyApplication? applicationById(String? id) =>
      applications.firstWhereOrNull((a) => a.id == id);

  // ─── списки по ролям ───

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

  // ─── иерархия ───

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

  // ─── нормализация ───

  void _backfillManagers() {
    for (final e in employees) {
      if (e.managerId != null) continue;
      _normalizeManager(e);
    }
  }

  void _addHistory(
    Employee e,
    EmployeeRole role, {
    String? parkId,
    String? regionId,
    String? reason,
  }) {
    final now = DateTime.now();
    e.history.add(RoleHistoryEntry(
      id: 'h${now.microsecondsSinceEpoch}_${e.history.length}',
      role: role,
      parkId: parkId,
      regionId: regionId,
      startedAt: now,
      reason: reason,
    ));
  }

  void _normalizeReportsOf(Employee e) {
    final reportIds = <String>{};
    for (final x in employees) {
      if (x.id == e.id) continue;
      if (x.managerId == e.id || x.additionalManagerIds.contains(e.id)) {
        reportIds.add(x.id);
      }
    }
    for (final id in reportIds) {
      final x = employeeById(id);
      if (x != null) _normalizeManager(x);
    }
  }

  void _normalizeParkStaff(String parkId) {
    for (final link in operatorLinks) {
      if (link.parkId == parkId && link.status == LinkStatus.approved) {
        final op = employeeById(link.operatorId);
        if (op != null) _normalizeManager(op);
      }
    }
    for (final e in employees) {
      if (e.hasRole(EmployeeRole.technician) && e.parkId == parkId) {
        _normalizeManager(e);
      }
    }
  }

  void _normalizeRegionStaff(String regionId) {
    final region = regionById(regionId);
    if (region == null) return;
    for (final pid in region.parkIds) {
      _normalizeParkStaff(pid);
      for (final pa in parkAdminsOf(pid)) {
        _normalizeManager(pa);
      }
    }
  }

  void _normalizeManager(Employee e) {
    if (e.status == EmployeeStatus.fired ||
        e.role == EmployeeRole.superAdmin) {
      e.managerId = null;
      e.additionalManagerIds.clear();
      return;
    }

    if (e.role == EmployeeRole.regionalAdmin) {
      final supers = superAdmins.where((s) => s.id != e.id).toList();
      if (supers.isNotEmpty) {
        e.managerId = supers.first.id;
        e.additionalManagerIds = supers.skip(1).map((s) => s.id).toList();
      } else {
        e.managerId = null;
        e.additionalManagerIds.clear();
      }
      return;
    }

    if (e.role == EmployeeRole.parkAdmin) {
      if (e.parkId != null) {
        final p = parkById(e.parkId);
        if (p != null) {
          final loc = locById(p.locId);
          if (loc != null) e.cityId = loc.cityId;
          final regs = regionsOfPark(e.parkId!);
          if (regs.isNotEmpty) e.regionId = regs.first.id;
        }

        final ras = <Employee>[];
        for (final reg in regionsOfPark(e.parkId!)) {
          for (final ra in regionalAdminsOf(reg.id)) {
            if (ra.id != e.id && !ras.any((x) => x.id == ra.id)) {
              ras.add(ra);
            }
          }
        }
        if (ras.isNotEmpty) {
          e.managerId = ras.first.id;
          e.additionalManagerIds = ras.skip(1).map((x) => x.id).toList();
          return;
        }
      }
      final supers = superAdmins.where((s) => s.id != e.id).toList();
      if (supers.isNotEmpty) {
        e.managerId = supers.first.id;
        e.additionalManagerIds = supers.skip(1).map((s) => s.id).toList();
      } else {
        e.managerId = null;
        e.additionalManagerIds.clear();
      }
      return;
    }

    String? parkForMgr;
    if (e.parkId != null) {
      parkForMgr = e.parkId;
    } else if (e.hasRole(EmployeeRole.operator)) {
      final approved = approvedParkIdsForOperator(e.id);
      if (approved.isNotEmpty) parkForMgr = approved.first;
    }

    if (parkForMgr != null) {
      final p = parkById(parkForMgr);
      if (p != null) {
        final loc = locById(p.locId);
        if (loc != null) e.cityId = loc.cityId;
        final regs = regionsOfPark(parkForMgr);
        if (regs.isNotEmpty) e.regionId = regs.first.id;
      }

      final pas = parkAdminsOf(parkForMgr)
          .where((x) => x.id != e.id)
          .toList();
      if (pas.isNotEmpty) {
        e.managerId = pas.first.id;
        e.additionalManagerIds = pas.skip(1).map((x) => x.id).toList();
        return;
      }

      final ras = <Employee>[];
      for (final reg in regionsOfPark(parkForMgr)) {
        for (final ra in regionalAdminsOf(reg.id)) {
          if (ra.id != e.id && !ras.any((x) => x.id == ra.id)) {
            ras.add(ra);
          }
        }
      }
      if (ras.isNotEmpty) {
        e.managerId = ras.first.id;
        e.additionalManagerIds = ras.skip(1).map((x) => x.id).toList();
        return;
      }
    }

    final supers = superAdmins.where((s) => s.id != e.id).toList();
    if (supers.isNotEmpty) {
      e.managerId = supers.first.id;
      e.additionalManagerIds = supers.skip(1).map((s) => s.id).toList();
    } else {
      e.managerId = null;
      e.additionalManagerIds.clear();
    }
  }

  // ─── права на изменение ролей ───

  RoleAssignmentPermissions getRoleAssignmentPermissions({
    required Employee currentUser,
    required Employee targetEmployee,
  }) {
    const noPermissions = RoleAssignmentPermissions(
      canChangePrimary: false,
      availablePrimaryRoles: [],
      availableExtraRoles: [],
    );

    if (currentUser.id == targetEmployee.id) return noPermissions;
    if (targetEmployee.role == EmployeeRole.superAdmin) return noPermissions;

    if (currentUser.role == EmployeeRole.superAdmin) {
      return const RoleAssignmentPermissions(
        canChangePrimary: true,
        availablePrimaryRoles: [
          EmployeeRole.regionalAdmin,
          EmployeeRole.parkAdmin,
          EmployeeRole.operator,
          EmployeeRole.technician,
        ],
        availableExtraRoles: [
          EmployeeRole.operator,
          EmployeeRole.technician,
        ],
      );
    }

    if (currentUser.role == EmployeeRole.regionalAdmin &&
        currentUser.regionId != null) {
      if (isEmployeeInRegion(targetEmployee, currentUser.regionId!)) {
        return const RoleAssignmentPermissions(
          canChangePrimary: true,
          availablePrimaryRoles: [
            EmployeeRole.parkAdmin,
            EmployeeRole.operator,
            EmployeeRole.technician,
          ],
          availableExtraRoles: [
            EmployeeRole.operator,
            EmployeeRole.technician,
          ],
        );
      }
    }

    if (currentUser.role == EmployeeRole.parkAdmin &&
        currentUser.parkId != null) {
      bool inPark = targetEmployee.parkId == currentUser.parkId;
      if (!inPark && targetEmployee.hasRole(EmployeeRole.operator)) {
        inPark = approvedParkIdsForOperator(targetEmployee.id)
            .contains(currentUser.parkId);
      }

      if (inPark) {
        return const RoleAssignmentPermissions(
          canChangePrimary: true,
          availablePrimaryRoles: [
            EmployeeRole.operator,
            EmployeeRole.technician,
          ],
          availableExtraRoles: [
            EmployeeRole.operator,
            EmployeeRole.technician,
          ],
        );
      }
    }

    return noPermissions;
  }

  // ─── назначение / снятие админов ───

  void _closeCurrentHistory(Employee e, String reason) {
    final now = DateTime.now();
    for (final h in e.history) {
      if (h.isCurrent) {
        h.endedAt = now;
        h.reason = reason;
      }
    }
  }

  void assignAdminToPark(Employee admin, Park park, {String? reason}) {
    final oldParkId = admin.parkId;

    _closeCurrentHistory(admin, reason ?? 'Назначен администратором');
    _addHistory(admin, EmployeeRole.parkAdmin, parkId: park.id);

    admin.role = EmployeeRole.parkAdmin;
    admin.parkId = park.id;

    final regs = regionsOfPark(park.id);
    admin.regionId = regs.isNotEmpty ? regs.first.id : null;
    final loc = locById(park.locId);
    admin.cityId = loc?.cityId;

    admin.status = EmployeeStatus.active;
    admin.statusChangedAt = DateTime.now();

    _normalizeManager(admin);

    if (oldParkId != null && oldParkId != park.id) {
      _normalizeParkStaff(oldParkId);
    }
    _normalizeParkStaff(park.id);

    save();
  }

  void removeAdminFromPark(Employee admin, {String? byAdminId}) {
    final removedParkId = admin.parkId;

    _closeCurrentHistory(admin, 'Снят с должности');

    admin.role = EmployeeRole.parkAdmin;
    admin.parkId = null;
    admin.status = EmployeeStatus.active;
    admin.statusChangedAt = DateTime.now();

    _normalizeManager(admin);

    if (removedParkId != null) {
      _normalizeParkStaff(removedParkId);
    }

    save();
  }

  void assignRegionalAdmin(Employee admin, Region region, {String? reason}) {
    final oldParkId = admin.parkId;
    final oldRegionId = admin.regionId;

    _closeCurrentHistory(
        admin, reason ?? 'Назначен региональным администратором');
    _addHistory(admin, EmployeeRole.regionalAdmin, regionId: region.id);

    admin.role = EmployeeRole.regionalAdmin;
    admin.regionId = region.id;
    admin.parkId = null;
    admin.status = EmployeeStatus.active;
    admin.statusChangedAt = DateTime.now();

    _normalizeManager(admin);

    if (oldParkId != null) _normalizeParkStaff(oldParkId);
    if (oldRegionId != null && oldRegionId != region.id) {
      _normalizeRegionStaff(oldRegionId);
    }
    _normalizeRegionStaff(region.id);

    save();
  }

  void removeRegionalAdmin(Employee admin, {String? byAdminId}) {
    final removedRegionId = admin.regionId;

    _closeCurrentHistory(admin, 'Снят с должности');

    admin.role = EmployeeRole.regionalAdmin;
    admin.regionId = null;
    admin.parkId = null;
    admin.status = EmployeeStatus.active;
    admin.statusChangedAt = DateTime.now();

    _normalizeManager(admin);

    if (removedRegionId != null) {
      _normalizeRegionStaff(removedRegionId);
    }

    save();
  }

  // ─── действия с сотрудниками ───

  bool setManagers(Employee e, String? primaryId, List<String> extras) {
    if (primaryId != null && wouldCreateCycle(e.id, primaryId)) return false;
    e.managerId = primaryId;
    e.additionalManagerIds = extras.where((id) => id != primaryId).toList();
    save();
    return true;
  }

  void setRoles(Employee e, EmployeeRole primary, List<EmployeeRole> extras) {
    final oldPrimary = e.role;
    final oldExtras = List<EmployeeRole>.from(e.additionalRoles);
    final wasParkAdmin = oldPrimary == EmployeeRole.parkAdmin;
    final wasRegionalAdmin = oldPrimary == EmployeeRole.regionalAdmin;
    final oldParkId = e.parkId;
    final oldRegionId = e.regionId;

    if (oldPrimary != primary) {
      _closeCurrentHistory(
          e, 'Смена основной роли: ${oldPrimary.label} → ${primary.label}');
      _addHistory(e, primary, parkId: e.parkId, regionId: e.regionId);
    }

    e.role = primary;
    e.additionalRoles = List.from(extras);

    for (final r in extras) {
      if (!oldExtras.contains(r)) {
        _addHistory(e, r,
            parkId: e.parkId,
            regionId: e.regionId,
            reason: 'Добавлена дополнительная роль');
      }
    }

    for (final r in oldExtras) {
      if (!extras.contains(r) && r != primary) {
        final now = DateTime.now();
        for (final h in e.history) {
          if (h.isCurrent && h.role == r) {
            h.endedAt = now;
            h.reason = 'Снята дополнительная роль';
          }
        }
      }
    }

    if (wasParkAdmin && primary != EmployeeRole.parkAdmin) {
      e.parkId = null;
    }

    if (wasRegionalAdmin && primary != EmployeeRole.regionalAdmin) {
      e.regionId = null;
    }

    if (primary == EmployeeRole.parkAdmin &&
        !wasParkAdmin &&
        e.parkId == null) {
      final approvedParks = approvedParkIdsForOperator(e.id);
      if (approvedParks.isNotEmpty) {
        e.parkId = approvedParks.first;
      }
    }

    _normalizeManager(e);

    if (wasParkAdmin && oldParkId != null) {
      _normalizeParkStaff(oldParkId);
    }
    if (wasRegionalAdmin && oldRegionId != null) {
      _normalizeRegionStaff(oldRegionId);
    }
    if (e.role == EmployeeRole.parkAdmin && e.parkId != null) {
      _normalizeParkStaff(e.parkId!);
    }

    save();
  }

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
          id: 'lnk${now.microsecondsSinceEpoch}',
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

    final park = parkById(parkId);
    if (park != null) {
      final loc = locById(park.locId);
      e.cityId = loc?.cityId;
      final regs = regionsOfPark(park.id);
      e.regionId = regs.isNotEmpty ? regs.first.id : null;

      if (wasParkAdmin) e.parkId = parkId;
    }

    e.status = EmployeeStatus.active;
    e.statusChangedAt = now;

    _normalizeManager(e);

    if (wasParkAdmin && oldParkId != null && oldParkId != parkId) {
      _normalizeParkStaff(oldParkId);
    }
    if (e.role == EmployeeRole.parkAdmin && e.parkId != null) {
      _normalizeParkStaff(e.parkId!);
    }

    _addHistory(e, e.role, parkId: parkId);

    save();
  }

  void moveToRegion(Employee e, String regionId, {String? byAdminId}) {
    final oldParkId = e.parkId;
    final oldRegionId = e.regionId;
    final wasParkAdmin = e.role == EmployeeRole.parkAdmin;
    final wasRegionalAdmin = e.role == EmployeeRole.regionalAdmin;

    _closeCurrentHistory(e, 'Переведён в другой регион');
    _addHistory(e, EmployeeRole.regionalAdmin, regionId: regionId);

    e.role = EmployeeRole.regionalAdmin;
    e.regionId = regionId;
    e.parkId = null;
    e.status = EmployeeStatus.active;
    e.statusChangedAt = DateTime.now();

    _normalizeManager(e);

    if (wasParkAdmin && oldParkId != null) _normalizeParkStaff(oldParkId);
    if (wasRegionalAdmin && oldRegionId != null && oldRegionId != regionId) {
      _normalizeRegionStaff(oldRegionId);
    }
    _normalizeRegionStaff(regionId);

    save();
  }

  void detachFromPark(Employee e, {bool clearManager = false}) {
    final wasParkAdmin = e.role == EmployeeRole.parkAdmin;
    final wasRegionalAdmin = e.role == EmployeeRole.regionalAdmin;
    final oldParkId = e.parkId;
    final oldRegionId = e.regionId;

    _closeCurrentHistory(e, 'Отвязан от парка');

    if (e.hasRole(EmployeeRole.operator)) {
      for (final l in linksForOperator(e.id).toList()) {
        l.status = LinkStatus.rejected;
      }
    }

    e.parkId = null;
    e.status = EmployeeStatus.active;
    e.statusChangedAt = DateTime.now();

    _normalizeManager(e);

    if (wasParkAdmin && oldParkId != null) _normalizeParkStaff(oldParkId);
    if (wasRegionalAdmin && oldRegionId != null) {
      _normalizeRegionStaff(oldRegionId);
    }
    _normalizeReportsOf(e);

    if (clearManager) {
      e.managerId = null;
      e.additionalManagerIds.clear();
    }

    _addHistory(e, e.role);

    save();
  }

  void clearManager(Employee e) {
    e.managerId = null;
    e.additionalManagerIds.clear();
    save();
  }

  void fireEmployee(Employee e) {
    final wasParkAdmin = e.role == EmployeeRole.parkAdmin;
    final wasRegionalAdmin = e.role == EmployeeRole.regionalAdmin;
    final oldParkId = e.parkId;
    final oldRegionId = e.regionId;

    _closeCurrentHistory(e, 'Уволен');

    if (e.hasRole(EmployeeRole.operator)) {
      for (final l in linksForOperator(e.id).toList()) {
        l.status = LinkStatus.rejected;
      }
    }

    e.status = EmployeeStatus.fired;
    e.statusChangedAt = DateTime.now();
    e.parkId = null;
    e.regionId = null;
    e.cityId = null;

    _normalizeManager(e);

    if (wasParkAdmin && oldParkId != null) _normalizeParkStaff(oldParkId);
    if (wasRegionalAdmin && oldRegionId != null) {
      _normalizeRegionStaff(oldRegionId);
    }
    _normalizeReportsOf(e);

    save();
  }

  // ─── связи оператор ↔ парк ───

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

  // ─── вакансии и заявки ───

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
      if (approved >= v.needCount) v.status = VacancyStatus.filled;
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

  // ─── смена оператора ───

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

  void setShiftRides(List<String> ids) {
    activeShift?.rideIds = ids;
    save();
  }

  void toggleRelief() {
    if (activeShift == null) return;
    activeShift!.isRelief = !activeShift!.isRelief;
    save();
  }
}