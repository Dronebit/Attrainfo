import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/app_database.dart';
import '../data/debug_log.dart';
import '../data/nfc_helper.dart';
import '../models/models.dart';
import '../models/employee.dart';
import '../models/region.dart';
import '../models/operator_park_link.dart';
import '../models/shift_vacancy.dart';
import '../theme.dart';

class AdminPersonnelTab extends StatefulWidget {
  final AppDatabase db;
  final Employee currentAdmin;
  const AdminPersonnelTab({
    super.key,
    required this.db,
    required this.currentAdmin,
  });

  @override
  State<AdminPersonnelTab> createState() => _AdminPersonnelTabState();
}

class _AdminPersonnelTabState extends State<AdminPersonnelTab> {
  // 'list' | 'tree'
  String _viewMode = 'list';
  // 'operators' | 'technicians'
  String _section = 'operators';

  String? _filterRegionId;
  String? _filterCityId;
  EmployeeStatus? _filterStatus;
  String _query = '';
  final _searchCtrl = TextEditingController();

  final Set<String> _collapsedTree = {};
  final Set<String> _collapsedRegions = {};
  final Set<String> _collapsedCities = {};
  final Set<String> _collapsedParks = {};
  bool _superCollapsed = true;
  bool _looseCollapsed = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  AppDatabase get db => widget.db;
  Employee get me => widget.currentAdmin;

  // ═══════════ фильтры ═══════════

  List<Region> get _visibleRegions {
    if (me.role == EmployeeRole.superAdmin) return db.regions;
    if (me.role == EmployeeRole.regionalAdmin && me.regionId != null) {
      final r = db.regionById(me.regionId);
      return r == null ? [] : [r];
    }
    return [];
  }

  List<City> get _visibleCities {
    if (_filterRegionId != null) return db.citiesOfRegion(_filterRegionId!);
    if (me.role == EmployeeRole.superAdmin) {
      return List<City>.from(db.cities)
        ..sort((a, b) => a.name.compareTo(b.name));
    }
    final cityIds = <String>{};
    for (final r in _visibleRegions) {
      for (final c in db.citiesOfRegion(r.id)) {
        cityIds.add(c.id);
      }
    }
    return cityIds
        .map(db.cityById)
        .whereType<City>()
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  List<Employee> _filteredAll() {
    final q = _query.toLowerCase().trim();
    final visibleRegionIds = _visibleRegions.map((r) => r.id).toSet();

    return db.employees.where((e) {
      if (_section == 'operators') {
        if (e.role != EmployeeRole.operator &&
            e.role != EmployeeRole.parkAdmin &&
            e.role != EmployeeRole.regionalAdmin &&
            e.role != EmployeeRole.superAdmin) {
          return false;
        }
      } else if (_section == 'technicians') {
        if (e.role != EmployeeRole.technician) return false;
      }

      if (me.role != EmployeeRole.superAdmin) {
        final inMyRegion = (e.regionId != null &&
                visibleRegionIds.contains(e.regionId)) ||
            (e.parkId != null &&
                db.regionsOfPark(e.parkId!).any(
                    (r) => visibleRegionIds.contains(r.id))) ||
            (e.role == EmployeeRole.operator &&
                _approvedParkIds(e).any((pid) => db
                    .regionsOfPark(pid)
                    .any((r) => visibleRegionIds.contains(r.id))));
        if (!inMyRegion) return false;
      }

      if (_filterStatus != null && e.status != _filterStatus) return false;

      if (_filterRegionId != null) {
        final region = db.regionById(_filterRegionId);
        if (region == null) return false;
        final inRegion = (e.regionId == _filterRegionId) ||
            (e.parkId != null && region.parkIds.contains(e.parkId!)) ||
            (e.role == EmployeeRole.operator &&
                _approvedParkIds(e)
                    .any((pid) => region.parkIds.contains(pid)));
        if (!inRegion) return false;
      }

      if (_filterCityId != null) {
        final city = db.cityById(_filterCityId);
        if (city == null) return false;
        if (!_employeeInCity(e, city.id)) return false;
      }

      if (q.isNotEmpty) {
        final hay = '${e.name} ${e.phone} ${e.jobTitle ?? ''}'.toLowerCase();
        if (!hay.contains(q)) return false;
      }

      return true;
    }).toList();
  }

  bool _employeeInCity(Employee e, String cityId) {
    if (e.role == EmployeeRole.regionalAdmin && e.regionId != null) {
      final cities = db.citiesOfRegion(e.regionId!);
      return cities.any((c) => c.id == cityId);
    }
    if (e.parkId != null) {
      final park = db.parkById(e.parkId);
      if (park == null) return false;
      final loc = db.locById(park.locId);
      return loc?.cityId == cityId;
    }
    if (e.role == EmployeeRole.operator) {
      for (final pid in _approvedParkIds(e)) {
        final park = db.parkById(pid);
        if (park == null) continue;
        final loc = db.locById(park.locId);
        if (loc?.cityId == cityId) return true;
      }
    }
    if (e.lastCityId != null) return e.lastCityId == cityId;
    return false;
  }

  List<String> _approvedParkIds(Employee e) {
    if (e.role == EmployeeRole.operator) {
      return db
          .linksForOperator(e.id)
          .where((l) => l.status == LinkStatus.approved)
          .map((l) => l.parkId)
          .toList();
    }
    return e.parkId != null ? [e.parkId!] : [];
  }

  List<String> _parksOf(Employee e) => _approvedParkIds(e);

  // ═══════════ build ═══════════

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _viewSwitcher(),
        const SizedBox(height: 6),
        _sectionSwitcher(),
        const SizedBox(height: 8),
        _filtersCard(),
        const SizedBox(height: 8),
        _viewMode == 'list' ? _buildListBody() : _buildTreeBody(),
      ],
    );
  }

  Widget _viewSwitcher() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.panel2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(children: [
        Expanded(child: _viewTab('list', Icons.list, 'Список')),
        Expanded(child: _viewTab('tree', Icons.account_tree, 'Дерево')),
      ]),
    );
  }

  Widget _viewTab(String key, IconData icon, String label) {
    final active = _viewMode == key;
    return InkWell(
      onTap: () => setState(() => _viewMode = key),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.panel : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color: active ? AppColors.line2 : Colors.transparent),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 14, color: active ? AppColors.amb2 : AppColors.mut),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: active ? AppColors.amb2 : AppColors.mut)),
          ],
        ),
      ),
    );
  }

  Widget _sectionSwitcher() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.panel2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(children: [
        Expanded(
          child: _sectionTab('operators', Icons.support_agent, 'Операторы'),
        ),
        Expanded(
          child: _sectionTab(
              'technicians', Icons.build_circle_outlined, 'Сервисная служба'),
        ),
      ]),
    );
  }

  Widget _sectionTab(String key, IconData icon, String label) {
    final active = _section == key;
    return InkWell(
      onTap: () => setState(() {
        _section = key;
        _collapsedTree.clear();
        _collapsedRegions.clear();
        _collapsedCities.clear();
        _collapsedParks.clear();
      }),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.panel : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color: active ? AppColors.line2 : Colors.transparent),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 14, color: active ? AppColors.amb2 : AppColors.mut),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: active ? AppColors.amb2 : AppColors.mut)),
          ],
        ),
      ),
    );
  }

  Widget _filtersCard() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: _cardDeco,
      child:
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(spacing: 4, runSpacing: 4, children: [
          _statusChip('Все', null),
          _statusChip('Работают', EmployeeStatus.active),
          _statusChip('Отпуск', EmployeeStatus.vacation),
          _statusChip('Больничный', EmployeeStatus.sick),
          _statusChip('Уволены', EmployeeStatus.fired),
        ]),
        const SizedBox(height: 8),
        LayoutBuilder(builder: (c, box) {
          final cols = box.maxWidth > 600 ? 2 : 1;
          final w = (box.maxWidth - (cols - 1) * 6) / cols;
          return Wrap(spacing: 6, runSpacing: 6, children: [
            SizedBox(
              width: w,
              child: DropdownButtonFormField<String?>(
                initialValue: _filterRegionId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Регион',
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                      value: null, child: Text('Все регионы')),
                  for (final r in _visibleRegions)
                    DropdownMenuItem<String?>(
                        value: r.id, child: Text(r.name)),
                ],
                onChanged: (v) => setState(() {
                  _filterRegionId = v;
                  _filterCityId = null;
                }),
              ),
            ),
            SizedBox(
              width: w,
              child: DropdownButtonFormField<String?>(
                initialValue: _filterCityId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Город',
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                      value: null, child: Text('Все города')),
                  for (final c in _visibleCities)
                    DropdownMenuItem<String?>(
                        value: c.id, child: Text(c.name)),
                ],
                onChanged: (v) => setState(() => _filterCityId = v),
              ),
            ),
          ]);
        }),
        const SizedBox(height: 8),
        TextField(
          controller: _searchCtrl,
          onChanged: (v) => setState(() => _query = v),
          decoration: InputDecoration(
            hintText: 'Поиск…',
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
            prefixIcon: const Icon(Icons.search, size: 16),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close, size: 14),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _query = '');
                    }),
          ),
        ),
      ]),
    );
  }

  // ═══════════ LIST VIEW ═══════════

  Widget _buildListBody() {
    final all = _filteredAll();

    final supers = _section == 'operators'
        ? all.where((e) => e.role == EmployeeRole.superAdmin).toList()
        : <Employee>[];
    final regionals = _section == 'operators'
        ? all.where((e) => e.role == EmployeeRole.regionalAdmin).toList()
        : <Employee>[];
    final workers = all
        .where((e) =>
            e.role != EmployeeRole.superAdmin &&
            e.role != EmployeeRole.regionalAdmin)
        .toList();

    final grouped =
        <String, Map<String, Map<String, List<Employee>>>>{};
    final loose = <Employee>[];

    for (final e in workers) {
      final parks = _parksOf(e);
      if (parks.isEmpty) {
        loose.add(e);
        continue;
      }
      for (final pid in parks) {
        final park = db.parkById(pid);
        if (park == null) continue;
        final loc = db.locById(park.locId);
        if (loc == null) continue;
        final city = db.cityById(loc.cityId);
        if (city == null) continue;
        final region = db.regionsOfPark(pid);
        final regionKey =
            region.isEmpty ? '__unassigned__' : region.first.id;
        grouped
            .putIfAbsent(regionKey, () => {})
            .putIfAbsent(city.id, () => {})
            .putIfAbsent(pid, () => [])
            .add(e);
      }
    }

    final allRegionKeys = <String>{};
    allRegionKeys.addAll(grouped.keys);
    for (final r in regionals) {
      if (r.regionId != null) allRegionKeys.add(r.regionId!);
    }

    final regionKeys = allRegionKeys.toList()
      ..sort((a, b) {
        if (a == '__unassigned__') return 1;
        if (b == '__unassigned__') return -1;
        final ra = db.regionById(a);
        final rb = db.regionById(b);
        return (ra?.name ?? '').compareTo(rb?.name ?? '');
      });

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(children: [
          Expanded(
            child: Text(
              'Найдено: ${all.length}',
              style: const TextStyle(fontSize: 11, color: AppColors.dim),
            ),
          ),
          if (_hasActiveFilters)
            TextButton(
              style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              onPressed: () => setState(() {
                _filterRegionId = null;
                _filterCityId = null;
                _filterStatus = null;
                _query = '';
                _searchCtrl.clear();
              }),
              child: const Text('Сбросить', style: TextStyle(fontSize: 11.5)),
            ),
        ]),
      ),
      const SizedBox(height: 4),
      if (supers.isNotEmpty) _superBlock(supers),
      if (regionKeys.isEmpty && loose.isEmpty && supers.isEmpty)
        _emptyState()
      else
        ...regionKeys.map((rk) {
          final regionAdmins =
              regionals.where((r) => r.regionId == rk).toList();
          final citiesMap =
              grouped[rk] ?? <String, Map<String, List<Employee>>>{};
          return _regionBlock(rk, citiesMap, regionAdmins);
        }),
      if (loose.isNotEmpty) _looseBlock(loose),
    ]);
  }

  Widget _emptyState() => Container(
        padding: const EdgeInsets.symmetric(vertical: 30),
        decoration: _cardDeco,
        child: const Center(
          child: Text('Сотрудников не найдено',
              style: TextStyle(color: AppColors.dim, fontSize: 12)),
        ),
      );

  Widget _superBlock(List<Employee> supers) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: _cardDeco,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () =>
                setState(() => _superCollapsed = !_superCollapsed),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Row(children: [
                Icon(
                    _superCollapsed
                        ? Icons.chevron_right
                        : Icons.expand_more,
                    size: 16,
                    color: AppColors.mut),
                const SizedBox(width: 4),
                const Icon(Icons.shield, size: 13, color: AppColors.pur),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text('Управление',
                      style: TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w700)),
                ),
                _countBadge(supers.length),
              ]),
            ),
          ),
          if (!_superCollapsed) ...[
            const Divider(height: 1, color: AppColors.line),
            Padding(
              padding: const EdgeInsets.all(4),
              child: Column(
                children: supers.map((e) => _employeeRow(e)).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _regionBlock(
      String regionKey, Map<String, Map<String, List<Employee>>> cities,
      List<Employee> regionAdmins) {
    final region = regionKey == '__unassigned__'
        ? null
        : db.regionById(regionKey);
    final collapsed = _collapsedRegions.contains(regionKey);
    final cityKeys = cities.keys.toList()
      ..sort((a, b) {
        final ca = db.cityById(a);
        final cb = db.cityById(b);
        return (ca?.name ?? '').compareTo(cb?.name ?? '');
      });
    final count = cities.values.fold<int>(
            0, (a, m) => a + m.values.fold<int>(0, (x, l) => x + l.length)) +
        regionAdmins.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: _cardDeco,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() {
              if (collapsed) {
                _collapsedRegions.remove(regionKey);
              } else {
                _collapsedRegions.add(regionKey);
              }
            }),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Row(children: [
                Icon(
                    collapsed
                        ? Icons.chevron_right
                        : Icons.expand_more,
                    size: 16,
                    color: AppColors.mut),
                const SizedBox(width: 4),
                Icon(
                    regionKey == '__unassigned__'
                        ? Icons.link_off
                        : Icons.map_outlined,
                    size: 13,
                    color: regionKey == '__unassigned__'
                        ? AppColors.amb
                        : AppColors.cyn),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(region?.name ?? 'Без региона',
                      style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700)),
                ),
                _countBadge(count),
              ]),
            ),
          ),
          if (!collapsed) ...[
            const Divider(height: 1, color: AppColors.line),
            Padding(
              padding: const EdgeInsets.all(4),
              child: Column(
                children: [
                  ...regionAdmins.map((a) => Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: _employeeRow(a, roleOverride: 'Рег. админ'),
                      )),
                  ...cityKeys.map((ck) => _cityBlock(ck, cities[ck]!)),
                  if (cityKeys.isEmpty && regionAdmins.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(6),
                      child: Text('Нет сотрудников',
                          style: TextStyle(
                              fontSize: 10.5, color: AppColors.dim)),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _cityBlock(String cityKey, Map<String, List<Employee>> parks) {
    final city = db.cityById(cityKey);
    final collapsed = _collapsedCities.contains(cityKey);
    final parkKeys = parks.keys.toList()
      ..sort((a, b) {
        final pa = db.parkById(a);
        final pb = db.parkById(b);
        return (pa?.name ?? '').compareTo(pb?.name ?? '');
      });
    final count = parks.values.fold<int>(0, (a, l) => a + l.length);

    return Container(
      margin: const EdgeInsets.only(bottom: 4, left: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1420),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() {
              if (collapsed) {
                _collapsedCities.remove(cityKey);
              } else {
                _collapsedCities.add(cityKey);
              }
            }),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              child: Row(children: [
                Icon(
                    collapsed
                        ? Icons.chevron_right
                        : Icons.expand_more,
                    size: 14,
                    color: AppColors.mut),
                const SizedBox(width: 4),
                const Icon(Icons.location_city,
                    size: 12, color: AppColors.cyn),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(city?.name ?? '—',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                ),
                Text('$count',
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.dim)),
              ]),
            ),
          ),
          if (!collapsed)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
              child: Column(
                children:
                    parkKeys.map((pk) => _parkBlock(pk, parks[pk]!)).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _parkBlock(String parkId, List<Employee> employees) {
    final park = db.parkById(parkId);
    final collapsed = _collapsedParks.contains(parkId);
    final parkAdmin = _section == 'operators'
        ? db.parkAdminsOf(parkId).firstOrNull
        : null;

    final others = parkAdmin != null
        ? employees.where((e) => e.id != parkAdmin.id).toList()
        : employees;

    return Container(
      margin: const EdgeInsets.only(bottom: 4, left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.panel2,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() {
              if (collapsed) {
                _collapsedParks.remove(parkId);
              } else {
                _collapsedParks.add(parkId);
              }
            }),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(children: [
                Icon(
                    collapsed
                        ? Icons.chevron_right
                        : Icons.expand_more,
                    size: 14,
                    color: AppColors.mut),
                const SizedBox(width: 2),
                const Icon(Icons.attractions,
                    size: 12, color: AppColors.amb),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(park?.name ?? '—',
                      style: const TextStyle(
                          fontSize: 11.5, fontWeight: FontWeight.w600)),
                ),
                Text(
                    '${(parkAdmin != null ? 1 : 0) + others.length}',
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.dim)),
              ]),
            ),
          ),
          if (!collapsed)
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 0, 2, 4),
              child: Column(
                children: [
                  if (parkAdmin != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: _employeeRow(parkAdmin,
                          roleOverride: 'Админ парка'),
                    ),
                  ...others.map((e) => _employeeRow(e)).toList(),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _looseBlock(List<Employee> loose) {
    final collapsed = _looseCollapsed;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: _cardDeco,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _looseCollapsed = !_looseCollapsed),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Row(children: [
                Icon(
                    collapsed
                        ? Icons.chevron_right
                        : Icons.expand_more,
                    size: 16,
                    color: AppColors.mut),
                const SizedBox(width: 6),
                const Icon(Icons.link_off, size: 13, color: AppColors.org),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text('Без привязки к парку',
                      style: TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w700)),
                ),
                _countBadge(loose.length),
              ]),
            ),
          ),
          if (!collapsed) ...[
            const Divider(height: 1, color: AppColors.line),
            Padding(
              padding: const EdgeInsets.all(4),
              child: Column(
                children: loose.map((e) => _employeeRow(e)).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _countBadge(int n) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: AppColors.panel2,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text('$n',
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.mut)),
      );

  // ═══════════ TREE VIEW ═══════════

  Widget _buildTreeBody() {
    final all = _filteredAll();
    final visibleIds = all.map((e) => e.id).toSet();

    final roots = all.where((e) {
      if (e.managerId == null) return true;
      final mgr = db.employeeById(e.managerId);
      if (mgr == null) return true;
      if (mgr.status == EmployeeStatus.fired) return true;
      if (!visibleIds.contains(mgr.id)) return true;
      return false;
    }).toList()
      ..sort((a, b) {
        if (a.role.level != b.role.level) {
          return b.role.level.compareTo(a.role.level);
        }
        return a.name.compareTo(b.name);
      });

    if (roots.isEmpty) {
      return _emptyState();
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(children: [
          Expanded(
            child: Text(
              'Найдено: ${all.length}',
              style: const TextStyle(fontSize: 11, color: AppColors.dim),
            ),
          ),
          if (_hasActiveFilters)
            TextButton(
              style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              onPressed: () => setState(() {
                _filterRegionId = null;
                _filterCityId = null;
                _filterStatus = null;
                _query = '';
                _searchCtrl.clear();
              }),
              child: const Text('Сбросить', style: TextStyle(fontSize: 11.5)),
            ),
        ]),
      ),
      const SizedBox(height: 4),
      ...roots.map((e) => _treeNode(e, visibleIds, 0)),
    ]);
  }

  Widget _treeNode(Employee e, Set<String> visibleIds, int depth) {
    final collapsed = _collapsedTree.contains(e.id);
    final children = db
        .directReports(e.id)
        .where((c) => visibleIds.contains(c.id))
        .toList();
    final hasChildren = children.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.only(left: depth * 12.0, top: 1, bottom: 1),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0E1420),
              borderRadius: BorderRadius.circular(6),
              border: depth == 0
                  ? Border.all(color: AppColors.line, width: 1)
                  : null,
            ),
            child: InkWell(
              onTap: hasChildren
                  ? () => setState(() {
                        if (collapsed) {
                          _collapsedTree.remove(e.id);
                        } else {
                          _collapsedTree.add(e.id);
                        }
                      })
                  : null,
              onLongPress: () => _showEmployeeCard(e),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 4),
                child: Row(children: [
                  SizedBox(
                    width: 16,
                    child: hasChildren
                        ? Icon(
                            collapsed
                                ? Icons.chevron_right
                                : Icons.expand_more,
                            size: 14,
                            color: AppColors.mut)
                        : const SizedBox.shrink(),
                  ),
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Color(e.role.colorValue).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(_initials(e.name),
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Color(e.role.colorValue))),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Flexible(
                            child: Text(e.name,
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: Color(e.role.colorValue)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(e.role.label,
                                style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w700,
                                    color: Color(e.role.colorValue))),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                                color: Color(e.status.colorValue),
                                shape: BoxShape.circle),
                          ),
                        ]),
                        Text(
                          _workplaceLabel(e),
                          style: const TextStyle(
                              fontSize: 9.5, color: AppColors.dim),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.info_outline, size: 14),
                    color: AppColors.mut,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 24, minHeight: 24),
                    onPressed: () => _showEmployeeCard(e),
                  ),
                ]),
              ),
            ),
          ),
        ),
        if (hasChildren && !collapsed)
          ...children.map((c) => _treeNode(c, visibleIds, depth + 1)),
      ],
    );
  }

  String _workplaceLabel(Employee e) {
    if (e.role == EmployeeRole.superAdmin) return 'Super';
    if (e.role == EmployeeRole.regionalAdmin) {
      final r = e.regionId == null ? null : db.regionById(e.regionId);
      return r == null ? 'Региональный админ' : 'Регион: ${r.name}';
    }
    final parks = _approvedParkIds(e);
    if (parks.isEmpty) return 'Свободен';
    final names = parks
        .map((pid) => db.parkById(pid)?.name)
        .where((x) => x != null)
        .cast<String>()
        .toList();
    if (names.isEmpty) return 'Свободен';
    return names.join(', ');
  }

  // ═══════════ КРАСИВАЯ СТРОКА СОТРУДНИКА ═══════════

  Widget _employeeRow(Employee e, {String? roleOverride}) {
    final color = Color(e.status.colorValue);
    final roleColor = Color(e.role.colorValue);
    final roleLabel = roleOverride ?? e.role.label;

    return InkWell(
      onTap: () => _showEmployeeCard(e),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0E14),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            // Аватар
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: roleColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Center(
                child: Text(
                  _initials(e.name),
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: roleColor),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Имя и Роль/Должность
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.name,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: roleColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          roleLabel,
                          style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w700,
                              color: roleColor),
                        ),
                      ),
                      if (e.jobTitle != null &&
                          e.jobTitle!.isNotEmpty) ...[
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            e.jobTitle!,
                            style: const TextStyle(
                                fontSize: 10, color: AppColors.dim),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),

            // Статус (вместо PIN)
            if (e.status != EmployeeStatus.active)
              Text(
                e.status.label,
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: color),
              )
            else
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 14, color: AppColors.dim),
          ],
        ),
      ),
    );
  }

  // ═══════════ КАРТОЧКА ═══════════

  Future<void> _showEmployeeCard(Employee emp) async {
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final current = db.employeeById(emp.id) ?? emp;
          final color = Color(current.status.colorValue);
          final roleColor = Color(current.role.colorValue);
          final canManage = _canManage(current);

          return DraggableScrollableSheet(
            initialChildSize: 0.85,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (_, scrollCtrl) => Container(
              decoration: const BoxDecoration(
                color: AppColors.panel,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.line2,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _cardHeader(
                              current, roleColor, color, canManage, setS),
                          const SizedBox(height: 14),
                          _infoSection(current, canManage, setS),
                          const SizedBox(height: 12),
                          _statsSection(current),
                          const SizedBox(height: 12),
                          if (canManage) ...[
                            const _CardSectionTitle('ДЕЙСТВИЯ'),
                            const SizedBox(height: 6),
                            _actionsGrid(current, setS),
                            const SizedBox(height: 12),
                          ],
                          const _CardSectionTitle('ИСТОРИЯ РАБОТЫ'),
                          const SizedBox(height: 6),
                          _historyList(current),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: AppColors.line)),
                    ),
                    child: SafeArea(
                      top: false,
                      child: SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Закрыть'),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _cardHeader(Employee e, Color roleColor, Color statusColor,
      bool canManage, StateSetter setS) {
    return Row(children: [
      Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: roleColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(_initials(e.name),
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: roleColor)),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(e.name,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700)),
            if (e.jobTitle != null && e.jobTitle!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(e.jobTitle!,
                  style: const TextStyle(
                      fontSize: 11.5, color: AppColors.dim)),
            ],
            const SizedBox(height: 4),
            Wrap(spacing: 4, runSpacing: 4, children: [
              _badge(e.role.label, roleColor),
              _badge(e.status.label, statusColor),
            ]),
          ],
        ),
      ),
      if (canManage)
        IconButton(
          icon: const Icon(Icons.edit_outlined, size: 18),
          tooltip: 'Редактировать',
          color: AppColors.mut,
          onPressed: () => _editEmployee(e, setS),
        ),
    ]);
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 9.5, fontWeight: FontWeight.w600, color: color)),
    );
  }

  Widget _infoSection(Employee e, bool canManage, StateSetter setS) {
    final parks = _approvedParkIds(e);
    final parkNames = parks
        .map((pid) => db.parkById(pid)?.name)
        .where((x) => x != null)
        .cast<String>()
        .join(', ');
    final manager =
        e.managerId == null ? null : db.employeeById(e.managerId);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1420),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _infoLine(
          icon: Icons.phone,
          label: 'Телефон',
          value: e.phone.isEmpty ? 'не указан' : e.phone,
          trailing: e.phone.isEmpty
              ? null
              : Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    icon: const Icon(Icons.copy, size: 14),
                    color: AppColors.mut,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 24, minHeight: 24),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: e.phone));
                      _snack('Телефон скопирован');
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.phone, size: 14),
                    color: AppColors.grn,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 24, minHeight: 24),
                    onPressed: () => _callPhone(e.phone),
                  ),
                ]),
        ),
        _infoLine(
          icon: Icons.key,
          label: 'PIN',
          value: e.pin,
          valueMono: true,
        ),
        _infoLine(
          icon: Icons.nfc,
          label: 'Бейдж',
          value: e.badgeId ?? 'не привязан',
          valueMono: e.badgeId != null,
          valueColor: e.badgeId != null ? AppColors.grn : AppColors.dim,
          trailing: canManage
              ? Row(mainAxisSize: MainAxisSize.min, children: [
                  if (e.badgeId != null)
                    IconButton(
                      icon: const Icon(Icons.close, size: 14),
                      color: AppColors.red,
                      tooltip: 'Отвязать',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                          minWidth: 24, minHeight: 24),
                      onPressed: () => _unbindBadge(e, setS),
                    ),
                  IconButton(
                    icon: const Icon(Icons.add, size: 14),
                    color: AppColors.cyn,
                    tooltip: e.badgeId != null
                        ? 'Заменить бейдж'
                        : 'Привязать бейдж',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                        minWidth: 24, minHeight: 24),
                    onPressed: () => _bindBadge(e, setS),
                  ),
                ])
              : null,
        ),
        _infoLine(
          icon: Icons.work_outline,
          label: 'Парки',
          value: parkNames.isEmpty ? 'Свободен' : parkNames,
        ),
        if (e.regionId != null)
          _infoLine(
            icon: Icons.map_outlined,
            label: 'Регион',
            value: db.regionById(e.regionId)?.name ?? '—',
          ),
        if (e.role != EmployeeRole.superAdmin)
          _infoLine(
            icon: Icons.supervisor_account,
            label: 'Руководитель',
            value: manager?.name ?? 'не назначен',
            trailing: canManage
                ? IconButton(
                    icon: const Icon(Icons.edit, size: 14),
                    color: AppColors.cyn,
                    tooltip: 'Сменить руководителя',
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 24, minHeight: 24),
                    onPressed: () => _changeManager(e, setS),
                  )
                : null,
          ),
        _infoLine(
          icon: Icons.calendar_today,
          label: 'Дата приёма',
          value: _fmtDate(e.createdAt),
        ),
        if (e.statusNote != null && e.statusNote!.isNotEmpty)
          _infoLine(
            icon: Icons.info_outline,
            label: 'Заметка',
            value: e.statusNote!,
            valueColor: AppColors.amb2,
          ),
      ]),
    );
  }

  Widget _infoLine({
    required IconData icon,
    required String label,
    required String value,
    Widget? trailing,
    bool valueMono = false,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: AppColors.mut),
          const SizedBox(width: 8),
          SizedBox(
            width: 90,
            child: Text(label,
                style:
                    const TextStyle(fontSize: 11.5, color: AppColors.dim)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  fontFamily: valueMono ? 'monospace' : null,
                  color: valueColor ?? AppColors.txt),
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _statsSection(Employee e) {
    final stats = <_StatItem>[];

    switch (e.role) {
      case EmployeeRole.operator:
        final shifts = db
            .applicationsForOperator(e.id)
            .where((a) => a.status == ApplicationStatus.approved)
            .length;
        final parks = _approvedParkIds(e).length;
        final reports = db.directReports(e.id).length;
        stats.add(_StatItem(
            icon: Icons.event_available, label: 'смен', value: '$shifts'));
        stats.add(_StatItem(
            icon: Icons.park_outlined, label: 'парков', value: '$parks'));
        if (reports > 0) {
          stats.add(_StatItem(
              icon: Icons.people_outline,
              label: 'в подчинении',
              value: '$reports'));
        }
        break;
      case EmployeeRole.technician:
        final incidents =
            db.incidents.where((i) => i.techId == e.id).length;
        final downtimes =
            db.downtimes.where((d) => d.techId == e.id).length;
        final activeDowntimes = db.downtimes
            .where((d) => d.techId == e.id && d.end == null)
            .length;
        stats.add(_StatItem(
            icon: Icons.warning_amber,
            label: 'инцидентов',
            value: '$incidents'));
        stats.add(_StatItem(
            icon: Icons.timer_outlined,
            label: 'простоев',
            value: '$downtimes'));
        stats.add(_StatItem(
            icon: Icons.pause_circle_outline,
            label: 'активных',
            value: '$activeDowntimes'));
        break;
      case EmployeeRole.parkAdmin:
        if (e.parkId != null) {
          final ops = db.operatorsOfPark(e.parkId!).length;
          final rides = db.rides
              .where((r) => r.parkId == e.parkId)
              .length;
          final reports = db.directReports(e.id).length;
          stats.add(_StatItem(
              icon: Icons.people_outline,
              label: 'операторов',
              value: '$ops'));
          stats.add(_StatItem(
              icon: Icons.attractions,
              label: 'аттракционов',
              value: '$rides'));
          stats.add(_StatItem(
              icon: Icons.supervisor_account,
              label: 'в подчинении',
              value: '$reports'));
        }
        break;
      case EmployeeRole.regionalAdmin:
        if (e.regionId != null) {
          final parks = db.parksOfRegion(e.regionId!).length;
          final reports = db.directReports(e.id).length;
          stats.add(_StatItem(
              icon: Icons.park_outlined, label: 'парков', value: '$parks'));
          stats.add(_StatItem(
              icon: Icons.supervisor_account,
              label: 'в подчинении',
              value: '$reports'));
        }
        break;
      case EmployeeRole.superAdmin:
        stats.add(_StatItem(
            icon: Icons.map_outlined,
            label: 'регионов',
            value: '${db.regions.length}'));
        stats.add(_StatItem(
            icon: Icons.park_outlined,
            label: 'парков',
            value: '${db.parks.length}'));
        stats.add(_StatItem(
            icon: Icons.supervisor_account,
            label: 'в подчинении',
            value: '${db.directReports(e.id).length}'));
        break;
    }

    if (stats.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _CardSectionTitle('СТАТИСТИКА'),
        const SizedBox(height: 6),
        Row(children: stats.map((s) {
          return Expanded(
            child: Container(
              margin: const EdgeInsets.only(right: 4),
              padding:
                  const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF0E1420),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(children: [
                Icon(s.icon, size: 14, color: AppColors.mut),
                const SizedBox(height: 2),
                Text(s.value,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'monospace')),
                Text(s.label,
                    style:
                        const TextStyle(fontSize: 9, color: AppColors.dim),
                    textAlign: TextAlign.center),
              ]),
            ),
          );
        }).toList()),
      ],
    );
  }

  Widget _actionsGrid(Employee e, StateSetter setS) {
    final hasWorkplace = _approvedParkIds(e).isNotEmpty || e.regionId != null;
    final roleChanges = _allowedRoleChanges(e);
    final canChangeWorkplace = e.role == EmployeeRole.regionalAdmin ||
        e.role == EmployeeRole.parkAdmin ||
        e.role == EmployeeRole.technician ||
        e.role == EmployeeRole.operator;

    final buttons = <Widget>[
      _actionBtn(
        icon: Icons.key,
        label: 'Сменить PIN',
        onTap: () => _changePin(e, setS),
      ),
      _actionBtn(
        icon: Icons.flag_outlined,
        label: 'Статус',
        onTap: () => _changeStatus(e, setS),
      ),
      if (canChangeWorkplace && hasWorkplace)
        _actionBtn(
          icon: Icons.move_up,
          label: 'Сменить место',
          color: AppColors.cyn,
          onTap: () => _changeWorkplace(e, setS),
        ),
      if (roleChanges.isNotEmpty)
        _actionBtn(
          icon: Icons.swap_horiz,
          label: 'Сменить роль',
          color: AppColors.pur,
          onTap: () => _changeRole(e, setS),
        ),
      if (hasWorkplace)
        _actionBtn(
          icon: Icons.link_off,
          label: 'Отвязать',
          color: AppColors.org,
          onTap: () => _detachWorkplace(e, setS),
        ),
      if (e.status != EmployeeStatus.fired)
        _actionBtn(
          icon: Icons.person_off,
          label: 'Уволить',
          color: AppColors.red,
          onTap: () => _fireEmployee(e, setS),
        ),
      if (me.role == EmployeeRole.superAdmin)
        _actionBtn(
          icon: Icons.delete_forever,
          label: 'Удалить',
          color: AppColors.red,
          onTap: () => _deleteEmployee(e, setS),
        ),
    ];

    return Wrap(spacing: 6, runSpacing: 6, children: buttons);
  }

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    final c = color ?? AppColors.amb;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.08),
          border: Border.all(color: c.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: c),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11.5, fontWeight: FontWeight.w600, color: c)),
        ]),
      ),
    );
  }

  // ═══════════ смена руководителя ═══════════

  Future<void> _changeManager(Employee e, StateSetter setS) async {
    final candidates = db.allowedManagersFor(e);
    if (candidates.isEmpty) {
      _snack('Нет подходящих руководителей');
      return;
    }

    String? selectedId = e.managerId;
    if (selectedId != null &&
        !candidates.any((c) => c.id == selectedId)) {
      selectedId = null;
    }

    final ok = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS2) => AlertDialog(
          backgroundColor: AppColors.panel,
          title: Text('Руководитель · ${e.name}'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Роль ${e.role.label} может подчиняться: ${e.role.allowedManagerRoles.map((r) => r.label).join(", ")}',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.dim),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: selectedId == null
                                ? AppColors.amb.withValues(alpha: 0.1)
                                : AppColors.panel2,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: selectedId == null
                                  ? AppColors.amb.withValues(alpha: 0.4)
                                  : Colors.transparent,
                            ),
                          ),
                          child: InkWell(
                            onTap: () => setS2(() => selectedId = null),
                            child: Row(children: [
                              Icon(
                                selectedId == null
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_off,
                                size: 18,
                                color: selectedId == null
                                    ? AppColors.amb
                                    : AppColors.dim,
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text('Без руководителя',
                                    style: TextStyle(fontSize: 13)),
                              ),
                            ]),
                          ),
                        ),
                        ...candidates.map((c) => Container(
                              margin: const EdgeInsets.only(bottom: 4),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: selectedId == c.id
                                    ? AppColors.amb
                                        .withValues(alpha: 0.1)
                                    : AppColors.panel2,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: selectedId == c.id
                                      ? AppColors.amb
                                          .withValues(alpha: 0.4)
                                      : Colors.transparent,
                                ),
                              ),
                              child: InkWell(
                                onTap: () =>
                                    setS2(() => selectedId = c.id),
                                child: Row(children: [
                                  Icon(
                                    selectedId == c.id
                                        ? Icons.radio_button_checked
                                        : Icons.radio_button_off,
                                    size: 18,
                                    color: selectedId == c.id
                                        ? AppColors.amb
                                        : AppColors.dim,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(c.name,
                                            style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight:
                                                    FontWeight.w600)),
                                        Text(
                                          '${c.role.label}${c.jobTitle != null ? " · ${c.jobTitle}" : ""}',
                                          style: const TextStyle(
                                              fontSize: 10.5,
                                              color: AppColors.dim),
                                        ),
                                      ],
                                    ),
                                  ),
                                ]),
                              ),
                            )),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Отмена')),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.amb,
                  foregroundColor: const Color(0xFF1C1204)),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;

    if (selectedId != null && db.wouldCreateCycle(e.id, selectedId!)) {
      _snack('Нельзя: это создаст циклическую иерархию');
      return;
    }

    e.managerId = selectedId;
    await db.save();
    setS(() {});
    _snack('Руководитель обновлён');
  }

  // ═══════════ смена роли ═══════════

  List<EmployeeRole> _allowedRoleChanges(Employee e) {
    final list = <EmployeeRole>[];
    if (e.id == me.id) return list;
    if (e.role == EmployeeRole.superAdmin) return list;
    if (e.role == EmployeeRole.regionalAdmin) return list;

    if (me.role == EmployeeRole.superAdmin) {
      if (e.role == EmployeeRole.operator) {
        list.addAll([EmployeeRole.technician, EmployeeRole.parkAdmin]);
      } else if (e.role == EmployeeRole.technician) {
        list.addAll([EmployeeRole.operator, EmployeeRole.parkAdmin]);
      } else if (e.role == EmployeeRole.parkAdmin) {
        list.addAll([EmployeeRole.operator, EmployeeRole.technician]);
      }
    } else if (me.role == EmployeeRole.regionalAdmin) {
      if (e.role == EmployeeRole.operator) {
        list.add(EmployeeRole.technician);
      } else if (e.role == EmployeeRole.technician) {
        list.add(EmployeeRole.operator);
      }
    }
    return list;
  }

  Future<void> _changeRole(Employee e, StateSetter setS) async {
    final allowed = _allowedRoleChanges(e);
    if (allowed.isEmpty) {
      _snack('Нельзя сменить роль');
      return;
    }
    EmployeeRole selected = allowed.first;

    final ok = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS2) => AlertDialog(
          backgroundColor: AppColors.panel,
          title: Text('Сменить роль · ${e.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Сейчас: ${e.role.label}',
                  style:
                      const TextStyle(fontSize: 11, color: AppColors.dim)),
              const SizedBox(height: 12),
              for (final r in allowed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: InkWell(
                    onTap: () => setS2(() => selected = r),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected == r
                            ? AppColors.pur.withValues(alpha: 0.12)
                            : Colors.transparent,
                        border: Border.all(
                            color: selected == r
                                ? AppColors.pur.withValues(alpha: 0.4)
                                : AppColors.line2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(children: [
                        Icon(
                            selected == r
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                            size: 18,
                            color: selected == r
                                ? AppColors.pur
                                : AppColors.dim),
                        const SizedBox(width: 8),
                        Text(r.label,
                            style: const TextStyle(fontSize: 13)),
                      ]),
                    ),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Отмена')),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.amb,
                  foregroundColor: const Color(0xFF1C1204)),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Далее'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;

    final parkId = await _pickPark(e);
    if (parkId == null) return;

    final now = DateTime.now();
    final oldRole = e.role;

    for (final h in e.history) {
      if (h.isCurrent) {
        h.endedAt = now;
        h.reason = 'Смена роли: ${oldRole.label} → ${selected.label}';
      }
    }

    if (oldRole == EmployeeRole.operator) {
      for (final l in db.linksForOperator(e.id).toList()) {
        l.status = LinkStatus.rejected;
      }
    }

    e.role = selected;
    e.status = EmployeeStatus.active;
    e.statusChangedAt = now;
    e.regionId = null;

    if (selected == EmployeeRole.operator) {
      e.parkId = null;
      db.createLinkRequest(e.id, parkId, initiatorAdminId: me.id);
      final created = db
          .linksForOperator(e.id)
          .firstWhere((l) => l.parkId == parkId);
      db.approveLink(created.id, me.id);
    } else {
      e.parkId = parkId;
    }

    final park = db.parkById(parkId);
    if (park != null) {
      final loc = db.locById(park.locId);
      if (loc != null) e.lastCityId = loc.cityId;
      final parkAdmin = db.parkAdminsOf(parkId).firstOrNull;
      if (parkAdmin != null && parkAdmin.id != e.id) {
        e.managerId = parkAdmin.id;
      }
    }

    e.history.add(RoleHistoryEntry(
      id: _uid(),
      role: selected,
      parkId: parkId,
      startedAt: now,
    ));

    await db.save();
    setS(() {});
    _snack('Роль изменена на ${selected.label}');
  }

  Future<String?> _pickPark(Employee e) async {
    final cities = List<City>.from(db.cities)
      ..sort((a, b) => a.name.compareTo(b.name));
    if (cities.isEmpty) {
      _snack('В базе нет городов');
      return null;
    }

    final currentParkIds = _approvedParkIds(e);
    String? initialCityId;
    if (currentParkIds.isNotEmpty) {
      final p = db.parkById(currentParkIds.first);
      if (p != null) {
        final l = db.locById(p.locId);
        initialCityId = l?.cityId;
      }
    }

    String? cityId = initialCityId ?? cities.first.id;
    String? parkId = currentParkIds.isNotEmpty ? currentParkIds.first : null;

    return showDialog<String>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS2) {
          final locs =
              db.locations.where((l) => l.cityId == cityId).toList();
          final parks = <Park>[];
          for (final l in locs) {
            parks.addAll(db.parks.where((p) => p.locId == l.id));
          }
          if (parkId == null || !parks.any((p) => p.id == parkId)) {
            parkId = parks.isEmpty ? null : parks.first.id;
          }

          return AlertDialog(
            backgroundColor: AppColors.panel,
            title: const Text('Выберите парк'),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  DropdownButtonFormField<String>(
                    initialValue: cityId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Город'),
                    items: [
                      for (final c in cities)
                        DropdownMenuItem(value: c.id, child: Text(c.name)),
                    ],
                    onChanged: (v) => setS2(() {
                      cityId = v;
                      parkId = null;
                    }),
                  ),
                  const SizedBox(height: 10),
                  if (parks.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      child: Text('В этом городе нет парков',
                          style: TextStyle(
                              fontSize: 11, color: AppColors.amb)),
                    )
                  else
                    DropdownButtonFormField<String>(
                      initialValue: parkId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Парк'),
                      items: [
                        for (final p in parks)
                          DropdownMenuItem(
                              value: p.id, child: Text(p.name)),
                      ],
                      onChanged: (v) => setS2(() => parkId = v),
                    ),
                ]),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Отмена')),
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.amb,
                    foregroundColor: const Color(0xFF1C1204)),
                onPressed: () {
                  if (parkId == null) {
                    _snack('Выберите парк');
                    return;
                  }
                  Navigator.pop(ctx, parkId);
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _detachWorkplace(Employee e, StateSetter setS) async {
    final ok = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: const Text('Отвязать от парка?'),
        content: Text(
          '${e.name} станет «свободным» — без привязки к парку. Роль (${e.role.label}) сохранится.',
          style: const TextStyle(fontSize: 13, color: AppColors.mut),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.amb,
                foregroundColor: const Color(0xFF1C1204)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Отвязать'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final now = DateTime.now();
    for (final h in e.history) {
      if (h.isCurrent) {
        h.endedAt = now;
        h.reason = 'Отвязан от парка';
      }
    }

    if (e.role == EmployeeRole.operator) {
      for (final l in db.linksForOperator(e.id).toList()) {
        l.status = LinkStatus.rejected;
      }
    }

    e.parkId = null;
    e.regionId = null;
    e.status = EmployeeStatus.active;
    e.statusChangedAt = now;

    e.history.add(RoleHistoryEntry(
      id: _uid(),
      role: e.role,
      startedAt: now,
    ));

    await db.save();
    setS(() {});
    _snack('${e.name} отвязан от парка');
  }

  Future<void> _changeWorkplace(Employee e, StateSetter setS) async {
    if (e.role == EmployeeRole.superAdmin) {
      _snack('Super-админ не привязан к парку');
      return;
    }
    if (e.role == EmployeeRole.regionalAdmin) {
      await _changeRegion(e, setS);
      return;
    }

    if (db.parks.isEmpty) {
      _snack('В базе нет парков');
      return;
    }

    final cities = List<City>.from(db.cities)
      ..sort((a, b) => a.name.compareTo(b.name));
    if (cities.isEmpty) {
      _snack('В базе нет городов');
      return;
    }

    final currentParkIds = _approvedParkIds(e);
    String? initialCityId;
    if (currentParkIds.isNotEmpty) {
      final p = db.parkById(currentParkIds.first);
      if (p != null) {
        final l = db.locById(p.locId);
        initialCityId = l?.cityId;
      }
    }

    String? cityId = initialCityId ?? cities.first.id;
    String? parkId = currentParkIds.isNotEmpty ? currentParkIds.first : null;

    final result = await showDialog<String>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS2) {
          final locs =
              db.locations.where((l) => l.cityId == cityId).toList();
          final parks = <Park>[];
          for (final l in locs) {
            parks.addAll(db.parks.where((p) => p.locId == l.id));
          }
          if (parkId != null && !parks.any((p) => p.id == parkId)) {
            parkId = parks.isEmpty ? null : parks.first.id;
          }

          return AlertDialog(
            backgroundColor: AppColors.panel,
            title: Text('Сменить место · ${e.name}'),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  DropdownButtonFormField<String>(
                    initialValue: cityId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Город'),
                    items: [
                      for (final c in cities)
                        DropdownMenuItem(value: c.id, child: Text(c.name)),
                    ],
                    onChanged: (v) => setS2(() {
                      cityId = v;
                      parkId = null;
                    }),
                  ),
                  const SizedBox(height: 10),
                  if (parks.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      child: Text('В этом городе нет парков',
                          style: TextStyle(
                              fontSize: 11, color: AppColors.amb)),
                    )
                  else
                    DropdownButtonFormField<String>(
                      initialValue: parkId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Парк'),
                      items: [
                        for (final p in parks)
                          DropdownMenuItem(
                              value: p.id, child: Text(p.name)),
                      ],
                      onChanged: (v) => setS2(() => parkId = v),
                    ),
                ]),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Отмена')),
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.amb,
                    foregroundColor: const Color(0xFF1C1204)),
                onPressed: () {
                  if (parkId == null) {
                    _snack('Выберите парк');
                    return;
                  }
                  Navigator.pop(ctx, parkId);
                },
                child: const Text('Перевести'),
              ),
            ],
          );
        },
      ),
    );

    if (result == null) return;
    final newParkId = result;
    if (currentParkIds.length == 1 && currentParkIds.first == newParkId) {
      _snack('Уже работает здесь');
      return;
    }

    final now = DateTime.now();
    for (final h in e.history) {
      if (h.isCurrent) {
        h.endedAt = now;
        h.reason = 'Переведён в другой парк';
      }
    }

    if (e.role == EmployeeRole.operator) {
      for (final l in db.linksForOperator(e.id).toList()) {
        if (l.status == LinkStatus.approved) {
          l.status = LinkStatus.rejected;
        }
      }
      db.createLinkRequest(e.id, newParkId, initiatorAdminId: me.id);
      final created = db
          .linksForOperator(e.id)
          .firstWhere((l) => l.parkId == newParkId);
      db.approveLink(created.id, me.id);
      e.parkId = null;
    } else {
      e.parkId = newParkId;
    }
    e.regionId = null;
    e.status = EmployeeStatus.active;
    e.statusChangedAt = now;
    final park = db.parkById(newParkId);
    if (park != null) {
      final loc = db.locById(park.locId);
      if (loc != null) e.lastCityId = loc.cityId;
      final parkAdmin = db.parkAdminsOf(newParkId).firstOrNull;
      if (parkAdmin != null && parkAdmin.id != e.id) {
        e.managerId = parkAdmin.id;
      }
    }

    e.history.add(RoleHistoryEntry(
      id: _uid(),
      role: e.role,
      parkId: newParkId,
      startedAt: now,
    ));

    await db.save();
    setS(() {});
    _snack('Переведён в ${park?.name ?? "парк"}');
  }

  Future<void> _changeRegion(Employee e, StateSetter setS) async {
    if (db.regions.isEmpty) {
      _snack('В базе нет регионов');
      return;
    }
    String? regionId = e.regionId;

    final result = await showDialog<String>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS2) => AlertDialog(
          backgroundColor: AppColors.panel,
          title: Text('Сменить регион · ${e.name}'),
          content: DropdownButtonFormField<String>(
            initialValue: regionId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Регион'),
            items: [
              for (final r in db.regions)
                DropdownMenuItem(value: r.id, child: Text(r.name)),
            ],
            onChanged: (v) => setS2(() => regionId = v),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Отмена')),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.amb,
                  foregroundColor: const Color(0xFF1C1204)),
              onPressed: () =>
                  regionId == null ? null : Navigator.pop(ctx, regionId),
              child: const Text('Перевести'),
            ),
          ],
        ),
      ),
    );

    if (result == null || result == e.regionId) return;
    final now = DateTime.now();
    for (final h in e.history) {
      if (h.isCurrent) {
        h.endedAt = now;
        h.reason = 'Переведён в другой регион';
      }
    }
    e.history.add(RoleHistoryEntry(
      id: _uid(),
      role: EmployeeRole.regionalAdmin,
      regionId: result,
      startedAt: now,
    ));
    e.role = EmployeeRole.regionalAdmin;
    e.regionId = result;
    e.parkId = null;
    e.status = EmployeeStatus.active;
    e.statusChangedAt = now;
    final superAdmin = db.superAdmins.isNotEmpty
        ? db.superAdmins.first
        : null;
    if (superAdmin != null) e.managerId = superAdmin.id;
    await db.save();
    setS(() {});
    _snack('Переведён в регион');
  }

  // ═══════════ звонок / PIN / статус / fire / delete / edit / NFC ═══════════

  Future<void> _callPhone(String phone) async {
    final cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('tel:$cleaned');
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) _snack('Не удалось открыть приложение звонка');
    } catch (err) {
      _snack('Ошибка: $err');
    }
  }

  Future<void> _changePin(Employee e, StateSetter setS) async {
    final ctrl = TextEditingController(text: e.pin);
    final ok = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: Text('Сменить PIN · ${e.name}'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: const InputDecoration(
              labelText: 'Новый PIN (4–6 цифр)', counterText: ''),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.amb,
                foregroundColor: const Color(0xFF1C1204)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Сменить'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final pin = ctrl.text.trim();
    if (pin.length < 4 || pin.length > 6 || int.tryParse(pin) == null) {
      _snack('PIN: 4–6 цифр');
      return;
    }
    if (db.employees.any((x) =>
        x.id != e.id &&
        x.status == EmployeeStatus.active &&
        x.pin == pin)) {
      _snack('PIN уже используется');
      return;
    }
    e.pin = pin;
    await db.save();
    setS(() {});
    _snack('PIN изменён');
  }

  Future<void> _changeStatus(Employee e, StateSetter setS) async {
    EmployeeStatus sel = e.status;
    final noteCtrl = TextEditingController(text: e.statusNote ?? '');

    final ok = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS2) => AlertDialog(
          backgroundColor: AppColors.panel,
          title: Text('Статус · ${e.name}'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (final s in EmployeeStatus.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: InkWell(
                    onTap: () => setS2(() => sel = s),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: sel == s
                            ? AppColors.amb.withValues(alpha: 0.12)
                            : Colors.transparent,
                        border: Border.all(
                            color: sel == s
                                ? AppColors.amb.withValues(alpha: 0.4)
                                : AppColors.line2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(children: [
                        Icon(
                            sel == s
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                            size: 18,
                            color: sel == s
                                ? AppColors.amb
                                : AppColors.dim),
                        const SizedBox(width: 8),
                        Text(s.label,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: sel == s
                                    ? FontWeight.w600
                                    : FontWeight.w400)),
                      ]),
                    ),
                  ),
                ),
              if (sel != EmployeeStatus.active) ...[
                const SizedBox(height: 6),
                TextField(
                  controller: noteCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Заметка',
                      hintText: 'например: отпуск до 15.11'),
                ),
              ],
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Отмена')),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.amb,
                  foregroundColor: const Color(0xFF1C1204)),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Применить'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    e.status = sel;
    e.statusChangedAt = DateTime.now();
    e.statusNote = sel == EmployeeStatus.active
        ? null
        : (noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim());
    if (sel == EmployeeStatus.fired) {
      for (final h in e.history) {
        if (h.isCurrent) {
          h.endedAt = DateTime.now();
          h.reason = 'Уволен';
        }
      }
      if (e.role == EmployeeRole.operator) {
        for (final l in db.linksForOperator(e.id).toList()) {
          l.status = LinkStatus.rejected;
        }
      }
    }
    await db.save();
    setS(() {});
    _snack('Статус изменён');
  }

  Future<void> _fireEmployee(Employee e, StateSetter setS) async {
    final ok = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: const Text('Уволить сотрудника?'),
        content: Text(
            '${e.name} будет переведён в статус «Уволен». История сохранится.',
            style: const TextStyle(fontSize: 13, color: AppColors.mut)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Уволить'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final now = DateTime.now();
    for (final h in e.history) {
      if (h.isCurrent) {
        h.endedAt = now;
        h.reason = 'Уволен';
      }
    }
    if (e.role == EmployeeRole.operator) {
      for (final l in db.linksForOperator(e.id).toList()) {
        l.status = LinkStatus.rejected;
      }
    }
    e.status = EmployeeStatus.fired;
    e.statusChangedAt = now;
    e.parkId = null;
    e.regionId = null;
    await db.save();
    setS(() {});
    _snack('${e.name} уволен');
  }

  Future<void> _deleteEmployee(Employee e, StateSetter setS) async {
    final ok = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: const Text('Удалить сотрудника?'),
        content: Text(
            '${e.name} будет удалён навсегда. Обычно достаточно статуса «Уволен».',
            style: const TextStyle(fontSize: 13, color: AppColors.mut)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    db.employees.removeWhere((x) => x.id == e.id);
    await db.save();
    if (mounted) Navigator.of(context, rootNavigator: true).pop();
    _snack('Сотрудник удалён');
  }

  Future<void> _editEmployee(Employee e, StateSetter setS) async {
    final nameCtrl = TextEditingController(text: e.name);
    final phoneCtrl = TextEditingController(text: e.phone);
    final jobCtrl = TextEditingController(text: e.jobTitle ?? '');

    final ok = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: const Text('Редактировать'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'ФИО *'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                  labelText: 'Телефон', hintText: '+7 900 000-00-00'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: jobCtrl,
              decoration: const InputDecoration(
                  labelText: 'Должность',
                  hintText: 'Старший механик, Оператор…'),
            ),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.amb,
                foregroundColor: const Color(0xFF1C1204)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final name = nameCtrl.text.trim();
    if (name.isEmpty) {
      _snack('Укажите ФИО');
      return;
    }
    e.name = name;
    e.phone = phoneCtrl.text.trim();
    e.jobTitle = jobCtrl.text.trim().isEmpty ? null : jobCtrl.text.trim();
    await db.save();
    setS(() {});
    _snack('Сохранено');
  }

  Future<void> _bindBadge(Employee e, StateSetter setS) async {
    _snack('Приложите бейдж к терминалу…');
    String? uid;
    try {
      uid = await NfcHelper.scanBadge();
    } catch (err) {
      _snack('Ошибка NFC: $err');
      return;
    }
    if (uid == null || uid.isEmpty) {
      _snack('Бейдж не распознан');
      return;
    }
    final existing = db.employeeByBadge(uid);
    if (existing != null && existing.id != e.id) {
      _snack('Этот бейдж уже привязан к: ${existing.name}');
      return;
    }
    e.badgeId = uid;
    await db.save();
    DebugLog.instance.info('badge bound: ${e.name} → $uid');
    setS(() {});
    _snack('Бейдж привязан');
  }

  Future<void> _unbindBadge(Employee e, StateSetter setS) async {
    final ok = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: const Text('Отвязать бейдж?'),
        content: Text('«${e.name}» больше не сможет входить по бейджу.',
            style: const TextStyle(fontSize: 13, color: AppColors.mut)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Отвязать'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    e.badgeId = null;
    await db.save();
    setS(() {});
    _snack('Бейдж отвязан');
  }

  // ═══════════ история ═══════════

  Widget _historyList(Employee e) {
    if (e.history.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.panel2,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text('История пуста',
            style: TextStyle(fontSize: 12, color: AppColors.dim)),
      );
    }
    final sorted = List<RoleHistoryEntry>.from(e.history)
      ..sort((a, b) {
        if (a.isCurrent != b.isCurrent) return a.isCurrent ? -1 : 1;
        return b.startedAt.compareTo(a.startedAt);
      });
    return Column(
      children: sorted.map((h) {
        final isCurrent = h.isCurrent;
        final park = h.parkId == null ? null : db.parkById(h.parkId);
        final region = h.regionId == null ? null : db.regionById(h.regionId);
        return Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isCurrent
                ? AppColors.grn.withValues(alpha: 0.05)
                : AppColors.panel2,
            borderRadius: BorderRadius.circular(6),
            border: isCurrent
                ? Border.all(color: AppColors.grn.withValues(alpha: 0.3))
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(isCurrent ? Icons.circle : Icons.history,
                    size: isCurrent ? 8 : 12,
                    color: isCurrent ? AppColors.grn : AppColors.dim),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(h.role.label,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                ),
                if (isCurrent)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.grn.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: const Text('сейчас',
                        style: TextStyle(
                            fontSize: 9,
                            color: AppColors.grn,
                            fontWeight: FontWeight.w700)),
                  ),
              ]),
              if (park != null || region != null)
                Padding(
                  padding: const EdgeInsets.only(left: 18, top: 2),
                  child: Text(
                    [region?.name, park?.name]
                        .where((x) => x != null)
                        .join(' → '),
                    style: const TextStyle(
                        fontSize: 10.5, color: AppColors.mut),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(left: 18, top: 2),
                child: Text(_fmtPeriod(h),
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.dim)),
              ),
              if (h.reason != null && h.reason!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 18, top: 2),
                  child: Text('· ${h.reason}',
                      style: const TextStyle(
                          fontSize: 10,
                          fontStyle: FontStyle.italic,
                          color: AppColors.dim)),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ═══════════ helpers ═══════════

  bool _canManage(Employee e) {
    if (e.id == me.id) return false;
    if (me.role == EmployeeRole.superAdmin) return true;
    if (e.role == EmployeeRole.superAdmin) return false;
    return true;
  }

  String _uid() => 'x${DateTime.now().microsecondsSinceEpoch}';

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  String _fmtPeriod(RoleHistoryEntry h) {
    final start = _fmtDate(h.startedAt);
    if (h.endedAt == null) return 'с $start';
    return '$start – ${_fmtDate(h.endedAt!)}';
  }

  Widget _statusChip(String label, EmployeeStatus? status) {
    final active = _filterStatus == status;
    return InkWell(
      onTap: () => setState(() => _filterStatus = status),
      borderRadius: BorderRadius.circular(99),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: active
              ? AppColors.amb.withValues(alpha: 0.12)
              : AppColors.panel2,
          border: Border.all(
              color: active
                  ? AppColors.amb.withValues(alpha: 0.4)
                  : AppColors.line2),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: active ? AppColors.amb2 : AppColors.mut)),
      ),
    );
  }

  bool get _hasActiveFilters =>
      _filterRegionId != null ||
      _filterCityId != null ||
      _filterStatus != null ||
      _query.isNotEmpty;

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1))
        .toUpperCase();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }
}

final _cardDeco = BoxDecoration(
  color: AppColors.panel,
  border: Border.all(color: AppColors.line),
  borderRadius: BorderRadius.circular(14),
);

class _CardSectionTitle extends StatelessWidget {
  final String text;
  const _CardSectionTitle(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.dim,
            letterSpacing: 0.6));
  }
}

class _StatItem {
  final IconData icon;
  final String label;
  final String value;
  _StatItem({required this.icon, required this.label, required this.value});
}