import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/app_database.dart';
import '../data/debug_log.dart';
import '../models/models.dart';
import '../models/park_admin.dart';
import '../models/region.dart';
import '../theme.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});
  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  bool _unlocked = false;
  ParkAdmin? _currentAdmin;
  final Set<String> _expandedRegions = {};

  String _uid() => 'x${DateTime.now().microsecondsSinceEpoch}';

  @override
  Widget build(BuildContext context) {
    final db = context.watch<AppDatabase>();
    if (!_unlocked) return _pinGate(db);
    final admin = _currentAdmin;
    if (admin == null) return _pinGate(db);

    switch (admin.role) {
      case AdminRole.superAdmin:
        return _superView(db, admin);
      case AdminRole.regionalAdmin:
        return _regionalView(db, admin);
      case AdminRole.parkAdmin:
        return _wrongRole('паркового администратора',
            'Откройте вкладку «Сотрудники» для управления операторами.');
    }
  }

  // ═══════════ PIN gate ═══════════

  Widget _pinGate(AppDatabase db) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: _cardDeco,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.shield_outlined, size: 42, color: AppColors.pur),
            const SizedBox(height: 14),
            const Text('Админ-панель',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            const Text('Вход для super-админов и региональных админов',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: AppColors.mut)),
            const SizedBox(height: 18),
            _primaryBtn(
              icon: Icons.key,
              label: 'Ввести PIN',
              onTap: () => _askPin(db),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                final superAdmin = db.admins.firstWhere(
                  (a) => a.active && a.role == AdminRole.superAdmin,
                  orElse: () => ParkAdmin(
                      id: 'fallback',
                      name: 'Super',
                      role: AdminRole.superAdmin),
                );
                setState(() {
                  _unlocked = true;
                  _currentAdmin = superAdmin;
                });
              },
              child: const Text('Быстрый вход: SUPER',
                  style: TextStyle(fontSize: 11, color: AppColors.pur)),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _askPin(AppDatabase db) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: const Text('PIN администратора'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          obscureText: false,
          maxLength: 6,
          decoration: const InputDecoration(labelText: 'PIN', counterText: ''),
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
            child: const Text('Войти'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final pin = ctrl.text.trim();
    if (pin.isEmpty) return;

    if (pin == AppDatabase.masterPin) {
      final superAdmin = db.admins.firstWhere(
        (a) => a.active && a.role == AdminRole.superAdmin,
        orElse: () => ParkAdmin(
            id: 'fallback', name: 'Super', role: AdminRole.superAdmin),
      );
      setState(() {
        _unlocked = true;
        _currentAdmin = superAdmin;
      });
      return;
    }

    final admin = db.adminByPin(pin);
    if (admin == null || admin.role == AdminRole.parkAdmin) {
      if (!mounted) return;
      _snack('Нет доступа · только super или региональный админ');
      return;
    }
    setState(() {
      _unlocked = true;
      _currentAdmin = admin;
    });
  }

  void _logout() => setState(() {
        _unlocked = false;
        _currentAdmin = null;
      });

  Widget _wrongRole(String role, String hint) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: _cardDeco,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.info_outline, size: 42, color: AppColors.blu),
              const SizedBox(height: 14),
              Text('Доступ для $role',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(hint,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12.5, color: AppColors.mut)),
              const SizedBox(height: 18),
              TextButton(onPressed: _logout, child: const Text('Выйти')),
            ]),
          ),
        ),
      );

  // ═══════════ super view ═══════════

  Widget _superView(AppDatabase db, ParkAdmin admin) {
    final unassigned = db.unassignedParks;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // Шапка SUPER
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.pur.withValues(alpha: 0.1),
          border: Border.all(color: AppColors.pur.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          const Icon(Icons.shield, size: 18, color: AppColors.pur),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('SUPER ADMIN',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.pur,
                          letterSpacing: 0.5)),
                  Text(
                    '${admin.name} · регионов: ${db.regions.length} · парков: ${db.parks.length}',
                    style: const TextStyle(
                        fontSize: 11.5, color: AppColors.dim),
                  ),
                ]),
          ),
          TextButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout, size: 14),
            label: const Text('Выйти', style: TextStyle(fontSize: 12)),
          ),
        ]),
      ),
      const SizedBox(height: 12),

      // Кнопка создания региона
      Row(children: [
        _primaryBtn(
          icon: Icons.add,
          label: 'Создать регион',
          onTap: () => _openRegionDialog(db, admin, null),
        ),
      ]),
      const SizedBox(height: 14),

      // Дерево регионов
      if (db.regions.isEmpty)
        Container(
          padding: const EdgeInsets.symmetric(vertical: 46),
          decoration: _cardDeco,
          child: const Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.map_outlined, size: 28, color: AppColors.dim),
            SizedBox(height: 10),
            Text('Регионов пока нет — нажми «Создать регион»',
                style: TextStyle(color: AppColors.dim, fontSize: 12.5)),
          ]),
        )
      else
        ...db.regions.map((r) => _regionCard(db, admin, r)),

      // Парки вне регионов
      if (unassigned.isNotEmpty) ...[
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.amb.withValues(alpha: 0.06),
            border: Border.all(color: AppColors.amb.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(14),
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              const Icon(Icons.link_off, size: 16, color: AppColors.amb),
              const SizedBox(width: 8),
              Text('Парки вне регионов · ${unassigned.length}',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.amb2)),
            ]),
            const SizedBox(height: 8),
            ...unassigned.map((p) {
              final loc = db.locById(p.locId);
              final city = loc == null ? null : db.cityById(loc.cityId);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Expanded(
                    child: Text(
                      '${city?.name ?? "—"} → ${loc?.name ?? "—"} → ${p.name}',
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    onPressed: () => _assignParkToRegion(db, p),
                    child: const Text('В регион',
                        style: TextStyle(fontSize: 12)),
                  ),
                ]),
              );
            }),
          ]),
        ),
      ],
    ]);
  }

  // ═══════════ regional view ═══════════

  Widget _regionalView(AppDatabase db, ParkAdmin admin) {
    final region = admin.regionId == null ? null : db.regionById(admin.regionId);
    if (region == null) {
      return _wrongRole('регионального администратора',
          'Не назначен регион. Обратитесь к super-админу.');
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        const Icon(Icons.map_outlined, size: 16, color: AppColors.blu),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Регион: ${region.name} · парков: ${region.parkIds.length}',
            style: const TextStyle(fontSize: 11.5, color: AppColors.dim),
          ),
        ),
        TextButton.icon(
          onPressed: _logout,
          icon: const Icon(Icons.logout, size: 14),
          label: const Text('Выйти', style: TextStyle(fontSize: 12)),
        ),
      ]),
      const SizedBox(height: 12),
      _regionCard(db, admin, region, isRegional: true),
    ]);
  }

  // ═══════════ region card ═══════════

  Widget _regionCard(AppDatabase db, ParkAdmin admin, Region region,
      {bool isRegional = false}) {
    final expanded = _expandedRegions.contains(region.id);
    final hierarchy = db.parksOfRegionHierarchy(region.id);
    final regAdmins = db.regionalAdminsOf(region.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: _cardDeco,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Шапка региона
        InkWell(
          onTap: () => setState(() {
            if (expanded) {
              _expandedRegions.remove(region.id);
            } else {
              _expandedRegions.add(region.id);
            }
          }),
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Icon(expanded ? Icons.expand_more : Icons.chevron_right,
                  size: 20, color: AppColors.mut),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(region.name,
                          style: const TextStyle(
                              fontSize: 14.5, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(
                        'Парков: ${region.parkIds.length}'
                        '${regAdmins.isEmpty ? " · рег. админов: нет" : " · рег. админов: ${regAdmins.length}"}',
                        style: const TextStyle(
                            fontSize: 11.5, color: AppColors.dim),
                      ),
                    ]),
              ),
              if (!isRegional)
                Row(children: [
                  _iconBtn(
                    icon: Icons.person_add,
                    tooltip: 'Рег. админ',
                    onTap: () => _openRegionalAdminDialog(db, region),
                  ),
                  _iconBtn(
                    icon: Icons.edit_outlined,
                    tooltip: 'Редактировать',
                    onTap: () => _openRegionDialog(db, admin, region),
                  ),
                  _iconBtn(
                    icon: Icons.delete_outline,
                    tooltip: 'Удалить',
                    danger: true,
                    onTap: () => _deleteRegion(db, region),
                  ),
                ]),
            ]),
          ),
        ),

        // Дерево
        if (expanded) ...[
          const Divider(height: 1, color: AppColors.line),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (hierarchy.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Center(
                        child: Text('В регионе нет парков',
                            style: TextStyle(
                                color: AppColors.dim, fontSize: 12)),
                      ),
                    )
                  else
                    ...hierarchy.entries.map((cityEntry) {
                      final city = cityEntry.key;
                      final locs = cityEntry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Заголовок города
                            Padding(
                              padding: const EdgeInsets.only(
                                  top: 4, bottom: 6, left: 4),
                              child: Row(children: [
                                const Icon(Icons.location_city,
                                    size: 14, color: AppColors.cyn),
                                const SizedBox(width: 6),
                                Text(city.name,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.cyn)),
                              ]),
                            ),
                            ...locs.entries.map((locEntry) {
                              final loc = locEntry.key;
                              final parksInLoc = locEntry.value;
                              return Padding(
                                padding: const EdgeInsets.only(
                                    left: 20, bottom: 6),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(
                                          top: 4, bottom: 6),
                                      child: Row(children: [
                                        const Icon(Icons.place_outlined,
                                            size: 12,
                                            color: AppColors.dim),
                                        const SizedBox(width: 6),
                                        Text(loc.name,
                                            style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.mut)),
                                      ]),
                                    ),
                                    ...parksInLoc.map((p) => Padding(
                                          padding: const EdgeInsets.only(
                                              left: 18),
                                          child: _parkRow(db, p),
                                        )),
                                    // + Парк
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(left: 18),
                                      child: _addButton(
                                        label: '+ Парк',
                                        onTap: () => _createParkInRegion(
                                            db, region, city, loc),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                            // + Локация
                            Padding(
                              padding: const EdgeInsets.only(left: 20),
                              child: _addButton(
                                label: '+ Локация',
                                onTap: () =>
                                    _createLocationChain(db, region, city),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  // + Город
                  _addButton(
                    label: '+ Город в регион',
                    onTap: () => _createCityChain(db, region),
                  ),
                ]),
          ),
        ],
      ]),
    );
  }

  Widget _addButton({required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.add_circle_outline, size: 14, color: AppColors.amb),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.amb2,
                  fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  Widget _parkRow(AppDatabase db, Park p) {
    final parkAdmins = db.parkAdminsOf(p.id);
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1420),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        const Icon(Icons.attractions, size: 14, color: AppColors.amb),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name,
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w600)),
                Text(
                  parkAdmins.isEmpty
                      ? 'без админа'
                      : parkAdmins
                          .map((a) => '${a.name} (${a.pin})')
                          .join(', '),
                  style: TextStyle(
                      fontSize: 10.5,
                      color: parkAdmins.isEmpty
                          ? AppColors.dim
                          : AppColors.grn),
                  overflow: TextOverflow.ellipsis,
                ),
              ]),
        ),
        IconButton(
          icon: const Icon(Icons.person_add, size: 16),
          color: AppColors.mut,
          tooltip: 'Назначить админа',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
          onPressed: () => _openParkAdminDialog(db, p),
        ),
      ]),
    );
  }

  // ═══════════ chain creation ═══════════

  /// + Город в регион → создаёт город + локацию + парк, привязанный к региону
  Future<void> _createCityChain(AppDatabase db, Region region) async {
    final cityCtrl = TextEditingController();
    final locCtrl = TextEditingController();
    final parkCtrl = TextEditingController();

    cityCtrl.addListener(() {
      if (locCtrl.text.isEmpty || locCtrl.text == cityCtrl.text) {
        locCtrl.text = cityCtrl.text;
      }
      if (parkCtrl.text.isEmpty || parkCtrl.text == cityCtrl.text) {
        parkCtrl.text = cityCtrl.text;
      }
    });

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: const Text('Новый город в регион'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text(
              'Создаётся цепочка: город → локация → парк. Парк сразу привязывается к региону.',
              style: TextStyle(fontSize: 11, color: AppColors.dim),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: cityCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                  labelText: 'Город *', hintText: 'Химки'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: locCtrl,
              decoration: const InputDecoration(
                  labelText: 'Локация *', hintText: 'Парк Химки'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: parkCtrl,
              decoration: const InputDecoration(
                  labelText: 'Парк *', hintText: 'Звёздный'),
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
            child: const Text('Создать'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final cityName = cityCtrl.text.trim();
    final locName = locCtrl.text.trim();
    final parkName = parkCtrl.text.trim();
    if (cityName.isEmpty || locName.isEmpty || parkName.isEmpty) {
      _snack('Заполните все поля');
      return;
    }

    // Найти или создать город
    var city = db.cities.firstWhere(
      (c) => c.name.toLowerCase() == cityName.toLowerCase(),
      orElse: () => City(id: '', name: ''),
    );
    if (city.id.isEmpty) {
      city = City(id: _uid(), name: cityName);
      db.cities.add(city);
    }
    // Найти или создать локацию в этом городе
    var loc = db.locations.firstWhere(
      (l) => l.cityId == city.id &&
          l.name.toLowerCase() == locName.toLowerCase(),
      orElse: () => ParkLocation(id: '', cityId: '', name: ''),
    );
    if (loc.id.isEmpty) {
      loc = ParkLocation(id: _uid(), cityId: city.id, name: locName);
      db.locations.add(loc);
    }
    // Создать парк
    final park = Park(id: _uid(), locId: loc.id, name: parkName);
    db.parks.add(park);
    db.addParkToRegion(region.id, park.id);
    await db.save();
    if (!mounted) return;
    _snack('Создано: $cityName → $locName → $parkName');
  }

  /// + Локация у города → создаёт локацию + парк
  Future<void> _createLocationChain(
      AppDatabase db, Region region, City city) async {
    final locCtrl = TextEditingController();
    final parkCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: Text('Новая локация · ${city.name}'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text(
              'Создаётся локация + парк. Парк сразу привязывается к региону.',
              style: TextStyle(fontSize: 11, color: AppColors.dim),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: locCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                  labelText: 'Локация *', hintText: 'Парк Горького'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: parkCtrl,
              decoration: const InputDecoration(
                  labelText: 'Парк *', hintText: 'Аттракционы «Солнышко»'),
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
            child: const Text('Создать'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final locName = locCtrl.text.trim();
    final parkName = parkCtrl.text.trim();
    if (locName.isEmpty || parkName.isEmpty) {
      _snack('Заполните все поля');
      return;
    }

    var loc = db.locations.firstWhere(
      (l) => l.cityId == city.id &&
          l.name.toLowerCase() == locName.toLowerCase(),
      orElse: () => ParkLocation(id: '', cityId: '', name: ''),
    );
    if (loc.id.isEmpty) {
      loc = ParkLocation(id: _uid(), cityId: city.id, name: locName);
      db.locations.add(loc);
    }
    final park = Park(id: _uid(), locId: loc.id, name: parkName);
    db.parks.add(park);
    db.addParkToRegion(region.id, park.id);
    await db.save();
    if (!mounted) return;
    _snack('Создано: $locName → $parkName');
  }

  /// + Парк у локации → создаёт парк и привязывает к региону
  Future<void> _createParkInRegion(AppDatabase db, Region region, City city,
      ParkLocation loc) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: Text('Новый парк · ${loc.name}'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
              labelText: 'Название парка *',
              hintText: 'Аттракционы «Радуга»'),
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
            child: const Text('Создать'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final name = ctrl.text.trim();
    if (name.isEmpty) return;
    final park = Park(id: _uid(), locId: loc.id, name: name);
    db.parks.add(park);
    db.addParkToRegion(region.id, park.id);
    await db.save();
    if (!mounted) return;
    _snack('Парк создан: $name');
  }

  // ═══════════ region dialogs ═══════════

  Future<void> _openRegionDialog(
      AppDatabase db, ParkAdmin admin, Region? editing) async {
    final nameCtrl = TextEditingController(text: editing?.name ?? '');
    final selected = <String>{...?editing?.parkIds};

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: AppColors.panel,
          title: Text(editing == null
              ? 'Новый регион'
              : 'Регион — редактирование'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      autofocus: true,
                      decoration: const InputDecoration(
                          labelText: 'Название региона *',
                          hintText: 'Москва Юг'),
                    ),
                    const SizedBox(height: 12),
                    const Text('Парки в регионе:',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.mut)),
                    const SizedBox(height: 6),
                    if (db.parks.isEmpty)
                      const Text(
                          'Нет парков — создайте через «+ Город» в дереве',
                          style: TextStyle(
                              fontSize: 11, color: AppColors.dim))
                    else
                      ...db.parks.map((p) {
                        final loc = db.locById(p.locId);
                        final city = loc == null
                            ? null
                            : db.cityById(loc.cityId);
                        final otherRegion = db
                            .regionsOfPark(p.id)
                            .where((r) => r.id != editing?.id)
                            .toList();
                        final occupied = otherRegion.isNotEmpty;
                        return CheckboxListTile(
                          value: selected.contains(p.id),
                          onChanged: occupied
                              ? null
                              : (v) => setS(() {
                                    if (v == true) {
                                      selected.add(p.id);
                                    } else {
                                      selected.remove(p.id);
                                    }
                                  }),
                          title: Text(p.name,
                              style: const TextStyle(fontSize: 12.5)),
                          subtitle: Text(
                            '${city?.name ?? "—"} · ${loc?.name ?? "—"}'
                            '${occupied ? " · уже в регионе «${otherRegion.first.name}»" : ""}',
                            style: TextStyle(
                                fontSize: 10.5,
                                color: occupied
                                    ? AppColors.red
                                    : AppColors.dim),
                          ),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          activeColor: AppColors.amb,
                          controlAffinity:
                              ListTileControlAffinity.leading,
                        );
                      }),
                  ]),
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
              child: Text(editing == null ? 'Создать' : 'Сохранить'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final name = nameCtrl.text.trim();
    if (name.isEmpty) {
      _snack('Укажите название');
      return;
    }
    if (editing == null) {
      db.createRegion(name, parkIds: selected.toList());
    } else {
      db.updateRegion(editing.id, name, selected.toList());
    }
    if (!mounted) return;
    _snack(editing == null ? 'Регион создан' : 'Сохранено');
  }

  Future<void> _deleteRegion(AppDatabase db, Region r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: Text('Удалить регион «${r.name}»?'),
        content: const Text(
          'Парки освободятся, региональные админы будут деактивированы.',
          style: TextStyle(fontSize: 13, color: AppColors.mut),
        ),
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
    db.deleteRegion(r.id);
    _snack('Регион удалён');
  }

  Future<void> _assignParkToRegion(AppDatabase db, Park p) async {
    final available = db.regions;
    if (available.isEmpty) {
      _snack('Сначала создайте регион');
      return;
    }
    String? selId = available.first.id;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: AppColors.panel,
          title: Text('В регион · ${p.name}'),
          content: DropdownButtonFormField<String>(
            initialValue: selId,
            decoration: const InputDecoration(labelText: 'Регион'),
            items: [
              for (final r in available)
                DropdownMenuItem(value: r.id, child: Text(r.name)),
            ],
            onChanged: (v) => setS(() => selId = v),
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
              child: const Text('Добавить'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || selId == null) return;
    db.addParkToRegion(selId!, p.id);
    _snack('Парк добавлен в регион');
  }

  // ═══════════ admin assignment ═══════════

  Future<void> _openRegionalAdminDialog(
      AppDatabase db, Region region) async {
    final existing = db.regionalAdminsOf(region.id);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: Text('Рег. админы · ${region.name}'),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (existing.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text('Нет администраторов',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 12, color: AppColors.dim)),
                )
              else
                ...existing.map((a) => Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.panel2,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(children: [
                        Expanded(
                          child: Text('${a.name} · PIN ${a.pin}',
                              style: const TextStyle(fontSize: 12)),
                        ),
                        IconButton(
                          icon:
                              const Icon(Icons.delete_outline, size: 16),
                          color: AppColors.red,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                              minWidth: 30, minHeight: 30),
                          onPressed: () {
                            db.admins.removeWhere((x) => x.id == a.id);
                            db.save();
                            Navigator.pop(ctx);
                          },
                        ),
                      ]),
                    )),
              const SizedBox(height: 12),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.amb,
                    foregroundColor: const Color(0xFF1C1204)),
                onPressed: () {
                  Navigator.pop(ctx);
                  _assignAdminToRegion(db, region);
                },
                icon: const Icon(Icons.person_add, size: 16),
                label: const Text('Добавить рег. админа'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Закрыть')),
        ],
      ),
    );
    setState(() {});
  }

  Future<void> _assignAdminToRegion(AppDatabase db, Region region) async {
    final candidates = db.admins.where((a) {
      if (!a.active) return false;
      if (a.regionId == region.id) return false;
      return a.role == AdminRole.regionalAdmin ||
          a.role == AdminRole.parkAdmin;
    }).toList();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: Text('В регион · ${region.name}'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (candidates.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Text('Нет свободных админов',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 12, color: AppColors.dim)),
                  )
                else
                  ...candidates.map((a) {
                    final curRegion = a.regionId == null
                        ? null
                        : db.regionById(a.regionId);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.panel2,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(children: [
                        Expanded(
                          child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text('${a.name} · PIN ${a.pin}',
                                    style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600)),
                                Text(
                                  curRegion == null
                                      ? 'Свободен · ${a.role.label}'
                                      : 'В регионе: ${curRegion.name}',
                                  style: const TextStyle(
                                      fontSize: 10.5,
                                      color: AppColors.dim),
                                ),
                              ]),
                        ),
                        TextButton(
                          onPressed: () {
                            a.role = AdminRole.regionalAdmin;
                            a.regionId = region.id;
                            a.parkId = null;
                            db.save();
                            Navigator.pop(ctx);
                            _snack('Назначен: ${a.name}');
                          },
                          child: const Text('Выбрать',
                              style: TextStyle(fontSize: 12)),
                        ),
                      ]),
                    );
                  }),
                const SizedBox(height: 10),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.amb,
                      foregroundColor: const Color(0xFF1C1204)),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _createAdmin(db, regionId: region.id);
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Создать нового'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена')),
        ],
      ),
    );
    setState(() {});
  }

  Future<void> _openParkAdminDialog(AppDatabase db, Park park) async {
    final existing = db.parkAdminsOf(park.id);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: Text('Админы · ${park.name}'),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (existing.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text('Нет администраторов',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 12, color: AppColors.dim)),
                )
              else
                ...existing.map((a) => Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.panel2,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(children: [
                        Expanded(
                          child: Text('${a.name} · PIN ${a.pin}',
                              style: const TextStyle(fontSize: 12)),
                        ),
                        IconButton(
                          icon:
                              const Icon(Icons.delete_outline, size: 16),
                          color: AppColors.red,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                              minWidth: 30, minHeight: 30),
                          onPressed: () {
                            db.admins.removeWhere((x) => x.id == a.id);
                            db.save();
                            Navigator.pop(ctx);
                          },
                        ),
                      ]),
                    )),
              const SizedBox(height: 12),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.amb,
                    foregroundColor: const Color(0xFF1C1204)),
                onPressed: () {
                  Navigator.pop(ctx);
                  _assignAdminToPark(db, park);
                },
                icon: const Icon(Icons.person_add, size: 16),
                label: const Text('Назначить админа'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Закрыть')),
        ],
      ),
    );
    setState(() {});
  }

  Future<void> _assignAdminToPark(AppDatabase db, Park park) async {
    final parkLoc = db.locById(park.locId);
    final parkCityId = parkLoc?.cityId;

    final candidates = db.admins.where((a) {
      if (!a.active) return false;
      if (a.role != AdminRole.parkAdmin) return false;
      if (a.parkId == park.id) return false;
      if (a.parkId == null) return true;
      final city = db.cityOfAdmin(a);
      return city?.id == parkCityId;
    }).toList();

    final cityName = parkCityId == null
        ? '—'
        : (db.cityById(parkCityId)?.name ?? '—');

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: Text('Назначить админа · ${park.name}'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Город: $cityName. Показаны админы из этого города и свободные.',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.dim),
                ),
                const SizedBox(height: 12),
                if (candidates.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Text(
                        'Нет подходящих админов. Создайте нового.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 12, color: AppColors.dim)),
                  )
                else
                  ...candidates.map((a) {
                    final city = db.cityOfAdmin(a);
                    final curPark = a.parkId == null
                        ? null
                        : db.parkById(a.parkId);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.panel2,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(children: [
                        Expanded(
                          child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text('${a.name} · PIN ${a.pin}',
                                    style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600)),
                                Text(
                                  curPark == null
                                      ? 'Свободен · ${city?.name ?? "без города"}'
                                      : 'Сейчас: ${curPark.name} (${city?.name ?? "—"})',
                                  style: const TextStyle(
                                      fontSize: 10.5,
                                      color: AppColors.dim),
                                ),
                              ]),
                        ),
                        TextButton(
                          onPressed: () {
                            a.parkId = park.id;
                            a.role = AdminRole.parkAdmin;
                            a.regionId = null;
                            db.save();
                            Navigator.pop(ctx);
                            _snack('Назначен: ${a.name}');
                          },
                          child: const Text('Выбрать',
                              style: TextStyle(fontSize: 12)),
                        ),
                      ]),
                    );
                  }),
                const SizedBox(height: 10),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.amb,
                      foregroundColor: const Color(0xFF1C1204)),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _createAdmin(db, parkId: park.id);
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Создать нового'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена')),
        ],
      ),
    );
    setState(() {});
  }

  Future<void> _createAdmin(AppDatabase db,
      {String? regionId, String? parkId}) async {
    final nameCtrl = TextEditingController();
    final pinCtrl = TextEditingController(text: '0000');
    final isRegional = regionId != null;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: Text(isRegional ? 'Новый рег. админ' : 'Новый админ парка'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: nameCtrl,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'ФИО *'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: pinCtrl,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: const InputDecoration(
                labelText: 'PIN (4–6 цифр)', counterText: ''),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.amb,
                foregroundColor: const Color(0xFF1C1204)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Создать'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final name = nameCtrl.text.trim();
    final pin = pinCtrl.text.trim();
    if (name.isEmpty) {
      _snack('Укажите ФИО');
      return;
    }
    if (pin.length < 4 || pin.length > 6 || int.tryParse(pin) == null) {
      _snack('PIN: 4–6 цифр');
      return;
    }
    if (db.admins.any((a) => a.active && a.pin == pin)) {
      _snack('PIN уже используется');
      return;
    }
    db.admins.add(ParkAdmin(
      id: _uid(),
      name: name,
      pin: pin,
      role: isRegional ? AdminRole.regionalAdmin : AdminRole.parkAdmin,
      regionId: regionId,
      parkId: parkId,
    ));
    await db.save();
    DebugLog.instance.info(
        'admin created: $name (${isRegional ? "regional" : "park"})');
    if (!mounted) return;
    _snack('Админ создан');
    setState(() {});
  }

  // ═══════════ helpers ═══════════

  Widget _primaryBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [AppColors.amb, Color(0xFFFF9A3D)]),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: const Color(0xFF1C1204)),
          const SizedBox(width: 7),
          Text(label,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1C1204))),
        ]),
      ),
    );
  }

  Widget _iconBtn({
    required IconData icon,
    required VoidCallback onTap,
    String? tooltip,
    bool danger = false,
  }) {
    return Tooltip(
      message: tooltip ?? '',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 30,
          height: 30,
          margin: const EdgeInsets.only(left: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.line2),
          ),
          child: Icon(icon,
              size: 15, color: danger ? AppColors.red : AppColors.mut),
        ),
      ),
    );
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