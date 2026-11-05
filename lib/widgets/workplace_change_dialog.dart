import 'package:flutter/material.dart';
import '../data/app_database.dart';
import '../models/employee.dart';
import '../models/models.dart';
import '../theme.dart';

enum WorkplaceChangeType { park, region }

class WorkplacePickResult {
  final String? parkId;
  final String? regionId;
  const WorkplacePickResult.park(String this.parkId) : regionId = null;
  const WorkplacePickResult.region(String this.regionId) : parkId = null;
}

Future<WorkplacePickResult?> showWorkplaceChangeDialog({
  required BuildContext context,
  required AppDatabase db,
  required Employee employee,
  WorkplaceChangeType? type,
}) async {
  final effectiveType = type ??
      (employee.role == EmployeeRole.regionalAdmin
          ? WorkplaceChangeType.region
          : WorkplaceChangeType.park);

  if (effectiveType == WorkplaceChangeType.region) {
    return _pickRegion(context, db, employee);
  }
  return _pickPark(context, db, employee);
}

Future<WorkplacePickResult?> _pickPark(
  BuildContext context,
  AppDatabase db,
  Employee employee,
) async {
  if (db.parks.isEmpty || db.cities.isEmpty) {
    return null;
  }

  final cities = List<City>.from(db.cities)
    ..sort((a, b) => a.name.compareTo(b.name));

  final currentParkIds = <String>[];
  if (employee.hasRole(EmployeeRole.operator)) {
    currentParkIds.addAll(db.approvedParkIdsForOperator(employee.id));
  } else if (employee.parkId != null) {
    currentParkIds.add(employee.parkId!);
  }

  String? initialCityId;
  if (currentParkIds.isNotEmpty) {
    final p = db.parkById(currentParkIds.first);
    if (p != null) {
      final l = db.locById(p.locId);
      initialCityId = l?.cityId;
    }
  } else if (employee.cityId != null) {
    initialCityId = employee.cityId;
  }

  String? cityId = initialCityId ?? cities.first.id;
  String? parkId = currentParkIds.isNotEmpty ? currentParkIds.first : null;

  final result = await showDialog<String>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) {
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
          title: Text('Сменить место · ${employee.name}'),
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
                  onChanged: (v) => setS(() {
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
                    onChanged: (v) => setS(() => parkId = v),
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
                if (parkId == null) return;
                Navigator.pop(ctx, parkId);
              },
              child: const Text('Перевести'),
            ),
          ],
        );
      },
    ),
  );

  if (result == null) return null;
  return WorkplacePickResult.park(result);
}

Future<WorkplacePickResult?> _pickRegion(
  BuildContext context,
  AppDatabase db,
  Employee employee,
) async {
  if (db.regions.isEmpty) return null;

  final currentId = employee.regionId;
  final available =
      db.regions.where((r) => r.id != currentId).toList();
  if (available.isEmpty) return null;

  String? selId = available.first.id;

  final ok = await showDialog<bool>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: Text('Сменить регион · ${employee.name}'),
        content: SizedBox(
          width: 440,
          child: DropdownButtonFormField<String>(
            initialValue: selId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Регион'),
            items: [
              for (final r in available)
                DropdownMenuItem(value: r.id, child: Text(r.name)),
            ],
            onChanged: (v) => setS(() => selId = v),
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
            child: const Text('Перевести'),
          ),
        ],
      ),
    ),
  );
  if (ok != true || selId == null) return null;
  return WorkplacePickResult.region(selId!);
}