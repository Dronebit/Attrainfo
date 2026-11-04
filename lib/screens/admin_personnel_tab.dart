import 'package:flutter/material.dart';
import '../data/app_database.dart';
import '../models/models.dart';
import '../models/employee.dart';
import '../models/region.dart';
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
  String? _filterRegionId;
  String? _filterCityId;
  EmployeeStatus? _filterStatus;
  String _query = '';
  final _searchCtrl = TextEditingController();
  final Set<String> _collapsedGroups = {};

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  AppDatabase get db => widget.db;
  Employee get me => widget.currentAdmin;

  // Какие регионы доступны текущему админу
  List<Region> get _visibleRegions {
    if (me.role == EmployeeRole.superAdmin) return db.regions;
    if (me.role == EmployeeRole.regionalAdmin && me.regionId != null) {
      final r = db.regionById(me.regionId);
      return r == null ? [] : [r];
    }
    return [];
  }

  // Какие города доступны (по паркам видимых регионов)
  List<City> get _visibleCities {
    if (_filterRegionId != null) {
      return db.citiesOfRegion(_filterRegionId!);
    }
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

  // Все видимые сотрудники с применёнными фильтрами
  List<Employee> _filteredEmployees() {
    final q = _query.toLowerCase().trim();
    final visibleRegionIds = _visibleRegions.map((r) => r.id).toSet();

    return db.employees.where((e) {
      // super видит всё, regional — только своих
      if (me.role != EmployeeRole.superAdmin) {
        // Региональный админ видит только тех, кто в его регионе
        // через парк, либо сам является regionalAdmin своего региона
        final inMyRegion = (e.regionId != null &&
                visibleRegionIds.contains(e.regionId)) ||
            (e.parkId != null &&
                db.regionsOfPark(e.parkId!).any(
                    (r) => visibleRegionIds.contains(r.id)));
        if (!inMyRegion) return false;
      }

      if (_filterStatus != null && e.status != _filterStatus) return false;

      if (_filterRegionId != null) {
        final region = db.regionById(_filterRegionId);
        if (region == null) return false;
        final inRegion = (e.regionId == _filterRegionId) ||
            (e.parkId != null &&
                region.parkIds.contains(e.parkId!));
        if (!inRegion) return false;
      }

      if (_filterCityId != null) {
        final city = db.cityById(_filterCityId);
        if (city == null) return false;
        final inCity = _employeeInCity(e, city.id);
        if (!inCity) return false;
      }

      if (q.isNotEmpty) {
        final hay = '${e.name} ${e.phone} ${e.jobTitle ?? ''}'.toLowerCase();
        if (!hay.contains(q)) return false;
      }

      return true;
    }).toList();
  }

  bool _employeeInCity(Employee e, String cityId) {
    // regionalAdmin по regionId → вычисляем город через парки региона
    if (e.role == EmployeeRole.regionalAdmin && e.regionId != null) {
      final cities = db.citiesOfRegion(e.regionId!);
      return cities.any((c) => c.id == cityId);
    }
    // parkAdmin/operator/technician по parkId
    if (e.parkId != null) {
      final park = db.parkById(e.parkId);
      if (park == null) return false;
      final loc = db.locById(park.locId);
      return loc?.cityId == cityId;
    }
    // Свободные — по lastCityId
    if (e.lastCityId != null) return e.lastCityId == cityId;
    return false;
  }

  String _groupKey(Employee e) {
    if (e.role == EmployeeRole.superAdmin) return '__super__';
    if (e.role == EmployeeRole.regionalAdmin && e.regionId != null) {
      return e.regionId!;
    }
    if (e.parkId != null) {
      final regions = db.regionsOfPark(e.parkId!);
      if (regions.isNotEmpty) return regions.first.id;
    }
    if (e.lastCityId != null) {
      final parks = db.parks.where((p) {
        final loc = db.locById(p.locId);
        return loc?.cityId == e.lastCityId;
      });
      for (final p in parks) {
        final regions = db.regionsOfPark(p.id);
        if (regions.isNotEmpty) return regions.first.id;
      }
    }
    return '__unassigned__';
  }

  String _groupLabel(String key) {
    if (key == '__super__') return 'Управление';
    if (key == '__unassigned__') return 'Без региона';
    final r = db.regionById(key);
    return r?.name ?? 'Без региона';
  }

  String _employeeLocation(Employee e) {
    if (e.role == EmployeeRole.superAdmin) return 'Super';
    if (e.role == EmployeeRole.regionalAdmin) {
      final r = e.regionId == null ? null : db.regionById(e.regionId);
      return r == null ? 'Региональный админ' : 'Регион: ${r.name}';
    }
    if (e.parkId != null) {
      final p = db.parkById(e.parkId);
      if (p != null) {
        final loc = db.locById(p.locId);
        final city = loc == null ? null : db.cityById(loc.cityId);
        return [city?.name, p.name].where((x) => x != null).join(' · ');
      }
    }
    if (e.lastCityId != null) {
      final c = db.cityById(e.lastCityId);
      return c == null ? 'Свободен' : 'Свободен · ${c.name}';
    }
    return 'Свободен';
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredEmployees();
    // Группировка
    final grouped = <String, List<Employee>>{};
    for (final e in filtered) {
      final k = _groupKey(e);
      grouped.putIfAbsent(k, () => []).add(e);
    }
    // Сортировка сотрудников внутри группы: сначала активные, потом по имени
    for (final list in grouped.values) {
      list.sort((a, b) {
        if (a.canWork != b.canWork) return a.canWork ? -1 : 1;
        return a.name.compareTo(b.name);
      });
    }
    // Сортировка групп
    final groupOrder = <String>[
      '__super__',
      ..._visibleRegions.map((r) => r.id),
      '__unassigned__',
    ];
    final orderedKeys =
        groupOrder.where((k) => grouped.containsKey(k)).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // Заголовок
      Row(children: [
        Expanded(
          child: Text(
            'Сотрудников: ${filtered.length}',
            style: const TextStyle(fontSize: 11.5, color: AppColors.dim),
          ),
        ),
        if (_hasActiveFilters)
          TextButton(
            onPressed: () => setState(() {
              _filterRegionId = null;
              _filterCityId = null;
              _filterStatus = null;
              _query = '';
              _searchCtrl.clear();
            }),
            child: const Text('Сбросить', style: TextStyle(fontSize: 12)),
          ),
      ]),
      const SizedBox(height: 8),

      // Фильтры
      Container(
        padding: const EdgeInsets.all(12),
        decoration: _cardDeco,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Статус chips
          Wrap(spacing: 6, runSpacing: 6, children: [
            _statusChip('Все', null),
            _statusChip('Работают', EmployeeStatus.active),
            _statusChip('Отпуск', EmployeeStatus.vacation),
            _statusChip('Больничный', EmployeeStatus.sick),
            _statusChip('Уволены', EmployeeStatus.fired),
          ]),
          const SizedBox(height: 10),
          // Регион + Город
          LayoutBuilder(builder: (c, box) {
            final cols = box.maxWidth > 600 ? 2 : 1;
            final w = (box.maxWidth - (cols - 1) * 8) / cols;
            return Wrap(spacing: 8, runSpacing: 8, children: [
              SizedBox(
                width: w,
                child: DropdownButtonFormField<String?>(
                  initialValue: _filterRegionId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Регион',
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
                        EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
          const SizedBox(height: 10),
          // Поиск
          TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Поиск по имени, телефону, должности…',
              prefixIcon: const Icon(Icons.search, size: 18),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _query = '');
                      }),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 12),

      // Список
      if (orderedKeys.isEmpty)
        Container(
          padding: const EdgeInsets.symmetric(vertical: 40),
          decoration: _cardDeco,
          child: const Center(
            child: Text('Сотрудников не найдено',
                style: TextStyle(color: AppColors.dim, fontSize: 12.5)),
          ),
        )
      else
        ...orderedKeys.map((key) {
          final list = grouped[key]!;
          final collapsed = _collapsedGroups.contains(key);
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: _cardDeco,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Заголовок группы
                InkWell(
                  onTap: () => setState(() {
                    if (collapsed) {
                      _collapsedGroups.remove(key);
                    } else {
                      _collapsedGroups.add(key);
                    }
                  }),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(14)),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Row(children: [
                      Icon(
                          collapsed
                              ? Icons.chevron_right
                              : Icons.expand_more,
                          size: 18,
                          color: AppColors.mut),
                      const SizedBox(width: 6),
                      Icon(
                          key == '__super__'
                              ? Icons.shield
                              : key == '__unassigned__'
                                  ? Icons.link_off
                                  : Icons.map_outlined,
                          size: 14,
                          color: key == '__super__'
                              ? AppColors.pur
                              : key == '__unassigned__'
                                  ? AppColors.amb
                                  : AppColors.cyn),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(_groupLabel(key),
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.panel2,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text('${list.length}',
                            style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.mut)),
                      ),
                    ]),
                  ),
                ),
                if (!collapsed) ...[
                  const Divider(height: 1, color: AppColors.line),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      children: list.map((e) => _employeeRow(e)).toList(),
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
    ]);
  }

  Widget _employeeRow(Employee e) {
    final color = Color(e.status.colorValue);
    final roleColor = Color(e.role.colorValue);
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1420),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        // Аватар
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: roleColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(_initials(e.name),
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: roleColor)),
          ),
        ),
        const SizedBox(width: 10),
        // Имя + роль + локация
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Flexible(
                  child: Text(e.name,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: roleColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(e.role.label,
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: roleColor)),
                ),
                const SizedBox(width: 4),
                Container(
                  width: 7,
                  height: 7,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle),
                ),
              ]),
              const SizedBox(height: 2),
              Text(
                _employeeLocation(e),
                style: const TextStyle(fontSize: 10.5, color: AppColors.dim),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        // PIN / статус
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('PIN ${e.pin}',
                style: const TextStyle(
                    fontSize: 10.5,
                    fontFamily: 'monospace',
                    color: AppColors.mut)),
            if (e.status != EmployeeStatus.active)
              Text(e.status.label,
                  style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: color)),
          ],
        ),
      ]),
    );
  }

  Widget _statusChip(String label, EmployeeStatus? status) {
    final active = _filterStatus == status;
    return InkWell(
      onTap: () => setState(() => _filterStatus = status),
      borderRadius: BorderRadius.circular(99),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
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
                fontSize: 11.5,
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
}

final _cardDeco = BoxDecoration(
  color: AppColors.panel,
  border: Border.all(color: AppColors.line),
  borderRadius: BorderRadius.circular(14),
);