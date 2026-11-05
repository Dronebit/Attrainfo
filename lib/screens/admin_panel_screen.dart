import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/app_database.dart';
import '../models/models.dart';
import '../models/employee.dart';
import '../models/region.dart';
import '../theme.dart';
import 'admin_admins_tab.dart';
import 'admin_personnel_tab.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});
  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _unlocked = false;
  Employee? _currentAdmin;
  final Set<String> _expandedRegions = {};

  String _uid() => 'x${DateTime.now().microsecondsSinceEpoch}';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = context.watch<AppDatabase>();
    if (!_unlocked) return _pinGate(db);
    final admin = _currentAdmin;
    if (admin == null) return _pinGate(db);

    if (admin.role == EmployeeRole.parkAdmin) {
      return _wrongRole('паркового администратора',
          'Откройте вкладку «Сотрудники» для управления операторами.');
    }
    if (admin.role != EmployeeRole.superAdmin &&
        admin.role != EmployeeRole.regionalAdmin) {
      return _wrongRole('администратора',
          'Откройте вкладку «Сотрудники» или «Сервисная служба».');
    }

    final isSuper = admin.role == EmployeeRole.superAdmin;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          decoration: BoxDecoration(
            color: isSuper
                ? AppColors.pur.withValues(alpha: 0.1)
                : AppColors.blu.withValues(alpha: 0.1),
            border: Border(
                bottom: BorderSide(
                    color: isSuper
                        ? AppColors.pur.withValues(alpha: 0.4)
                        : AppColors.blu.withValues(alpha: 0.4))),
          ),
          child: Row(children: [
            Icon(isSuper ? Icons.shield : Icons.map_outlined,
                size: 18,
                color: isSuper ? AppColors.pur : AppColors.blu),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isSuper ? 'SUPER ADMIN' : 'РЕГИОНАЛЬНЫЙ АДМИН',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: isSuper ? AppColors.pur : AppColors.blu)),
                  Text(admin.name,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.dim)),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout, size: 14),
              label: const Text('Выйти', style: TextStyle(fontSize: 12)),
            ),
          ]),
        ),
        Container(
          color: AppColors.panel,
          child: TabBar(
            controller: _tabController,
            indicatorColor: AppColors.amb,
            labelColor: AppColors.amb2,
            unselectedLabelColor: AppColors.mut,
            labelStyle:
                const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            tabs: const [
              Tab(text: 'Инфраструктура'),
              Tab(text: 'Администраторы'),
              Tab(text: 'Сотрудники'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                child: isSuper
                    ? _superViewContent(db, admin)
                    : _regionalViewContent(db, admin),
              ),
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                child: AdminAdminsTab(db: db, currentAdmin: admin),
              ),
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                child: AdminPersonnelTab(db: db, currentAdmin: admin),
              ),
            ],
          ),
        ),
      ],
    );
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
                final superAdmin = db.superAdmins.isNotEmpty
                    ? db.superAdmins.first
                    : Employee(
                        id: 'fallback',
                        name: 'Super',
                        role: EmployeeRole.superAdmin,
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
      useRootNavigator: true,
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
      final superAdmin = db.superAdmins.isNotEmpty
          ? db.superAdmins.first
          : Employee(
              id: 'fallback', name: 'Super', role: EmployeeRole.superAdmin);
      setState(() {
        _unlocked = true;
        _currentAdmin = superAdmin;
      });
      return;
    }

    final emp = db.employeeByPin(pin);
    if (emp == null || !emp.isAdmin) {
      if (!mounted) return;
      _snack('Нет доступа · только super или региональный админ');
      return;
    }
    setState(() {
      _unlocked = true;
      _currentAdmin = emp;
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

  Widget _superViewContent(AppDatabase db, Employee admin) {
    final unassigned = db.unassignedParks;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        _primaryBtn(
          icon: Icons.add,
          label: 'Создать регион',
          onTap: () => _openRegionDialog(db, admin, null),
        ),
      ]),
      const SizedBox(height: 14),

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

  Widget _regionalViewContent(AppDatabase db, Employee admin) {
    final region =
        admin.regionId == null ? null : db.regionById(admin.regionId);
    if (region == null) {
      return _wrongRole('регионального администратора',
          'Не назначен регион. Обратитесь к super-админу.');
    }
    return _regionCard(db, admin, region, isRegional: true);
  }

  // ═══════════ region card ═══════════

  Widget _regionCard(AppDatabase db, Employee admin, Region region,
      {bool isRegional = false}) {
    final expanded = _expandedRegions.contains(region.id);
    final hierarchy = db.parksOfRegionHierarchy(region.id);
    final regAdmins = db.regionalAdminsOf(region.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: _cardDeco,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
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
            padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
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
                        'Парков: ${region.parkIds.length} · '
                        'Рег. админ: ${_regAdminLine(regAdmins)}',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: regAdmins.isEmpty
                              ? AppColors.dim
                              : AppColors.mut,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ]),
              ),
              if (!isRegional)
                IconButton(
                  icon: const Icon(Icons.more_vert, size: 20),
                  color: AppColors.mut,
                  tooltip: 'Действия',
                  onPressed: () => _showRegionMenu(db, admin, region),
                ),
            ]),
          ),
        ),
        if (expanded) ...[
          const Divider(height: 1, color: AppColors.line),
          Padding(
            padding: const EdgeInsets.all(12),
            child: hierarchy.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Column(children: [
                      const Text('В регионе нет парков',
                          style: TextStyle(
                              color: AppColors.dim, fontSize: 12)),
                      if (!isRegional) ...[
                        const SizedBox(height: 10),
                        TextButton.icon(
                          onPressed: () =>
                              _showRegionMenu(db, admin, region),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Добавить парк',
                              style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ]),
                  )
                : Column(
                    children: hierarchy.entries.map((cityEntry) {
                      final city = cityEntry.key;
                      final locs = cityEntry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
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
                                    left: 20, bottom: 4),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(
                                          top: 4, bottom: 6),
                                      child: Row(children: [
                                        const Icon(Icons.place_outlined,
                                            size: 12, color: AppColors.dim),
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
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ]),
    );
  }

  Widget _parkRow(AppDatabase db, Park p) {
    final parkAdmins = db.parkAdminsOf(p.id);
    return InkWell(
      onTap: () => _showParkCard(db, p),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
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
          const Icon(Icons.chevron_right, size: 16, color: AppColors.dim),
        ]),
      ),
    );
  }

  // ═══════════ КАРТОЧКА ПАРКА (урезанная) ═══════════

  Future<void> _showParkCard(AppDatabase db, Park park) async {
    await showDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final ridesCount = db.rides.where((r) => r.parkId == park.id).length;
          final opsCount = db.operatorsOfPark(park.id).length;

          return AlertDialog(
            backgroundColor: AppColors.panel,
            titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            title: Row(children: [
              const Icon(Icons.attractions, size: 20, color: AppColors.amb),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(park.name,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      _parkLocationPath(db, park),
                      style: const TextStyle(
                          fontSize: 11.5, color: AppColors.dim),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                tooltip: 'Редактировать парк',
                color: AppColors.mut,
                onPressed: () async {
                  await _editPark(db, park);
                  if (!ctx.mounted) return;
                  setS(() {});
                },
              ),
            ]),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _parkInfoBlock(park),
                      const SizedBox(height: 14),
                      Row(children: [
                        Expanded(
                            child: _statBox('$ridesCount',
                                'аттракционов', AppColors.amb)),
                        const SizedBox(width: 6),
                        Expanded(
                            child: _statBox('$opsCount',
                                'операторов', AppColors.cyn)),
                      ]),
                    ]),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Закрыть')),
            ],
          );
        },
      ),
    );
  }

  String _parkLocationPath(AppDatabase db, Park p) {
    final loc = db.locById(p.locId);
    final city = loc == null ? null : db.cityById(loc.cityId);
    final region = db.regionsOfPark(p.id).firstOrNull;
    return [
      region?.name,
      city?.name,
      loc?.name,
    ].where((x) => x != null).join(' · ');
  }

  String _regAdminLine(List<Employee> admins) {
    if (admins.isEmpty) return 'не назначен';
    if (admins.length == 1) return admins.first.name;
    return '${admins.first.name} +${admins.length - 1}';
  }

  Widget _parkInfoBlock(Park park) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1420),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (park.openedAt != null)
            _infoRow(Icons.calendar_today, 'Дата открытия',
                _formatDate(park.openedAt!)),
          if (park.address != null && park.address!.isNotEmpty)
            _infoRow(Icons.place, 'Адрес', park.address!),
          if (park.phone != null && park.phone!.isNotEmpty)
            _infoRow(Icons.phone, 'Телефон', park.phone!),
          if (park.openedAt == null &&
              (park.address == null || park.address!.isEmpty) &&
              (park.phone == null || park.phone!.isEmpty))
            const Text(
              'Информация не заполнена. Нажмите ✏️ чтобы добавить.',
              style: TextStyle(fontSize: 11.5, color: AppColors.dim),
            ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Icon(icon, size: 13, color: AppColors.mut),
        const SizedBox(width: 8),
        Text('$label: ',
            style: const TextStyle(fontSize: 12, color: AppColors.dim)),
        Expanded(
          child: Text(value,
              style: const TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis),
        ),
      ]),
    );
  }

  Widget _statBox(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(children: [
        Text(value,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: color,
                fontFamily: 'monospace')),
        Text(label,
            style: const TextStyle(fontSize: 10.5, color: AppColors.dim),
            textAlign: TextAlign.center),
      ]),
    );
  }

  String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }

  // ═══════════ редактирование парка ═══════════

  Future<bool?> _editPark(AppDatabase db, Park park) async {
    final nameCtrl = TextEditingController(text: park.name);
    final addressCtrl = TextEditingController(text: park.address ?? '');
    final phoneCtrl = TextEditingController(text: park.phone ?? '');
    DateTime? openedAt = park.openedAt;

    final ok = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: AppColors.panel,
          title: const Text('Редактировать парк'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      autofocus: true,
                      decoration: const InputDecoration(
                          labelText: 'Название парка *'),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () async {
                        final d = await showDatePicker(
                          context: ctx,
                          initialDate: openedAt ?? DateTime.now(),
                          firstDate: DateTime(1950),
                          lastDate: DateTime.now(),
                        );
                        if (d != null) setS(() => openedAt = d);
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Дата открытия',
                          suffixIcon: Icon(Icons.calendar_today, size: 16),
                        ),
                        child: Text(
                          openedAt == null
                              ? 'Не указана'
                              : _formatDate(openedAt!),
                          style: TextStyle(
                              fontSize: 13,
                              color: openedAt == null
                                  ? AppColors.dim
                                  : AppColors.txt),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: addressCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Адрес',
                          hintText: 'г. Москва, ул. Примерная, 1'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                          labelText: 'Телефон',
                          hintText: '+7 495 000-00-00'),
                    ),
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
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return null;

    final name = nameCtrl.text.trim();
    if (name.isEmpty) {
      _snack('Укажите название');
      return null;
    }
    park.name = name;
    park.openedAt = openedAt;
    park.address =
        addressCtrl.text.trim().isEmpty ? null : addressCtrl.text.trim();
    park.phone =
        phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim();
    await db.save();
    if (!mounted) return null;
    _snack('Парк обновлён');
    return true;
  }

  // ═══════════ меню региона ═══════════

  Future<void> _showRegionMenu(
      AppDatabase db, Employee admin, Region region) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      backgroundColor: AppColors.panel,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.line2,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(region.name,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              const Text('Выберите действие',
                  style: TextStyle(fontSize: 11.5, color: AppColors.dim)),
              const SizedBox(height: 16),
              const Text('ДОБАВИТЬ',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.dim,
                      letterSpacing: 0.6)),
              const SizedBox(height: 6),
              _menuItem(
                icon: Icons.attractions,
                title: 'Парк в существующую локацию',
                subtitle: 'Город и локация уже есть',
                onTap: () => Navigator.pop(ctx, 'add-park'),
              ),
              _menuItem(
                icon: Icons.place_outlined,
                title: 'Новую локацию с парком',
                subtitle: 'В существующем городе',
                onTap: () => Navigator.pop(ctx, 'add-location'),
              ),
              if (db.cities.isNotEmpty)
                _menuItem(
                  icon: Icons.location_city,
                  title: 'Локацию с парком в существующий город',
                  subtitle: 'Выбрать город из базы',
                  onTap: () => Navigator.pop(ctx, 'add-existing-city'),
                ),
              _menuItem(
                icon: Icons.add_location_alt,
                title: 'Новый город с локацией и парком',
                subtitle: 'Создать город с нуля',
                onTap: () => Navigator.pop(ctx, 'add-new-city'),
              ),
              _menuItem(
                icon: Icons.add_link,
                title: 'Привязать существующий парк',
                subtitle: 'Парк уже создан, но не в этом регионе',
                onTap: () => Navigator.pop(ctx, 'attach-park'),
              ),
              const SizedBox(height: 12),
              const Divider(color: AppColors.line, height: 1),
              const SizedBox(height: 8),
              const Text('РЕГИОН',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.dim,
                      letterSpacing: 0.6)),
              const SizedBox(height: 6),
              _menuItem(
                icon: Icons.edit_outlined,
                title: 'Редактировать регион',
                subtitle: 'Название и парки',
                onTap: () => Navigator.pop(ctx, 'edit'),
              ),
              _menuItem(
                icon: Icons.delete_outline,
                title: 'Удалить регион',
                subtitle: 'Парки освободятся',
                color: AppColors.red,
                onTap: () => Navigator.pop(ctx, 'delete'),
              ),
            ],
          ),
        ),
      ),
    );

    if (action == null || !mounted) return;

    switch (action) {
      case 'add-park':
        await _addParkToExistingLoc(db, region);
        break;
      case 'add-location':
        await _addLocationWithPark(db, region);
        break;
      case 'add-existing-city':
        await _addToExistingCity(db, region);
        break;
      case 'add-new-city':
        await _addNewCityWithChain(db, region);
        break;
      case 'attach-park':
        await _attachExistingPark(db, region);
        break;
      case 'edit':
        await _openRegionDialog(db, admin, region);
        break;
      case 'delete':
        await _deleteRegion(db, region);
        break;
    }
  }

  Widget _menuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: (color ?? AppColors.amb).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 17, color: color ?? AppColors.amb),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: color ?? AppColors.txt)),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.dim)),
                ]),
          ),
          const Icon(Icons.chevron_right, size: 16, color: AppColors.dim),
        ]),
      ),
    );
  }

  // ═══════════ создание — 5 сценариев ═══════════

  Future<void> _addParkToExistingLoc(AppDatabase db, Region region) async {
    final cities = db.citiesOfRegion(region.id);
    if (cities.isEmpty) {
      _snack('В регионе нет городов — создайте город');
      return;
    }

    String? cityId = cities.first.id;
    String? locId;
    final parkCtrl = TextEditingController();

    List<ParkLocation> locsFor(String? cid) => cid == null
        ? []
        : db.locations.where((l) => l.cityId == cid).toList();

    var currentLocs = locsFor(cityId);
    locId = currentLocs.isEmpty ? null : currentLocs.first.id;

    final ok = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: AppColors.panel,
          title: const Text('Парк в существующую локацию'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                initialValue: cityId,
                decoration: const InputDecoration(labelText: 'Город'),
                isExpanded: true,
                items: [
                  for (final c in cities)
                    DropdownMenuItem(value: c.id, child: Text(c.name)),
                ],
                onChanged: (v) => setS(() {
                  cityId = v;
                  currentLocs = locsFor(v);
                  locId =
                      currentLocs.isEmpty ? null : currentLocs.first.id;
                }),
              ),
              const SizedBox(height: 12),
              if (currentLocs.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                      'В городе нет локаций. Используйте «Новую локацию с парком».',
                      style:
                          TextStyle(fontSize: 11, color: AppColors.amb)),
                )
              else
                DropdownButtonFormField<String>(
                  initialValue: locId,
                  decoration: const InputDecoration(labelText: 'Локация'),
                  isExpanded: true,
                  items: [
                    for (final l in currentLocs)
                      DropdownMenuItem(value: l.id, child: Text(l.name)),
                  ],
                  onChanged: (v) => setS(() => locId = v),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: parkCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                    labelText: 'Название парка *',
                    hintText: 'Аттракционы «Радуга»'),
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
      ),
    );

    if (ok != true || locId == null) return;
    final name = parkCtrl.text.trim();
    if (name.isEmpty) {
      _snack('Введите название парка');
      return;
    }
    final park = Park(id: _uid(), locId: locId!, name: name);
    db.parks.add(park);
    db.addParkToRegion(region.id, park.id);
    await db.save();
    if (!mounted) return;
    _snack('Парк «$name» создан');
  }

  Future<void> _addLocationWithPark(
      AppDatabase db, Region region) async {
    final cities = db.citiesOfRegion(region.id);
    if (cities.isEmpty) {
      _snack('В регионе нет городов — создайте город');
      return;
    }

    String? cityId = cities.first.id;
    final locCtrl = TextEditingController();
    final parkCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: AppColors.panel,
          title: const Text('Новая локация с парком'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                initialValue: cityId,
                decoration: const InputDecoration(labelText: 'Город'),
                isExpanded: true,
                items: [
                  for (final c in cities)
                    DropdownMenuItem(value: c.id, child: Text(c.name)),
                ],
                onChanged: (v) => setS(() => cityId = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: locCtrl,
                decoration: const InputDecoration(
                    labelText: 'Название локации *',
                    hintText: 'Измайлово ПКиО'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: parkCtrl,
                decoration: const InputDecoration(
                    labelText: 'Название парка *',
                    hintText: 'Аттракционы «Солнышко»'),
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
      ),
    );

    if (ok != true || cityId == null) return;
    final locName = locCtrl.text.trim();
    final parkName = parkCtrl.text.trim();
    if (locName.isEmpty || parkName.isEmpty) {
      _snack('Заполните все поля');
      return;
    }

    final existingLoc = db.locations.firstWhere(
      (l) =>
          l.cityId == cityId &&
          l.name.toLowerCase() == locName.toLowerCase(),
      orElse: () => ParkLocation(id: '', cityId: '', name: ''),
    );
    ParkLocation loc;
    if (existingLoc.id.isNotEmpty) {
      if (!mounted) return;
      final useExisting = await _askUseExistingLocation(
          db, existingLoc, parkName);
      if (useExisting != true) return;
      loc = existingLoc;
    } else {
      loc = ParkLocation(id: _uid(), cityId: cityId!, name: locName);
      db.locations.add(loc);
    }

    final park = Park(id: _uid(), locId: loc.id, name: parkName);
    db.parks.add(park);
    db.addParkToRegion(region.id, park.id);
    await db.save();
    if (!mounted) return;
    _snack('Парк «$parkName» создан');
  }

  Future<void> _addToExistingCity(AppDatabase db, Region region) async {
    if (db.cities.isEmpty) {
      _snack('В базе нет городов');
      return;
    }

    String? cityId;
    final citiesSorted = List<City>.from(db.cities)
      ..sort((a, b) => a.name.compareTo(b.name));

    final pickedCity = await showDialog<City>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: const Text('Выбрать город'),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Города из базы. Тап — выбрать.',
                style: TextStyle(fontSize: 11, color: AppColors.dim),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: citiesSorted.map((c) {
                      final locsCount = db.locations
                          .where((l) => l.cityId == c.id)
                          .length;
                      final parksCount = db.parks.where((p) {
                        final loc = db.locById(p.locId);
                        return loc?.cityId == c.id;
                      }).length;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.panel2,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: InkWell(
                          onTap: () => Navigator.pop(ctx, c),
                          child: Row(children: [
                            const Icon(Icons.location_city,
                                size: 16, color: AppColors.cyn),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(c.name,
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600)),
                                    Text(
                                      'локаций: $locsCount · парков: $parksCount',
                                      style: const TextStyle(
                                          fontSize: 10.5,
                                          color: AppColors.dim),
                                    ),
                                  ]),
                            ),
                            const Icon(Icons.chevron_right,
                                size: 16, color: AppColors.dim),
                          ]),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена')),
        ],
      ),
    );

    if (pickedCity == null || !mounted) return;
    cityId = pickedCity.id;

    final locCtrl = TextEditingController();
    final parkCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: AppColors.panel,
          title: Text('Новая локация · ${pickedCity.name}'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: locCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                    labelText: 'Название локации *',
                    hintText: 'Измайлово ПКиО'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: parkCtrl,
                decoration: const InputDecoration(
                    labelText: 'Название парка *',
                    hintText: 'Аттракционы «Солнышко»'),
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
      ),
    );

    if (ok != true || cityId == null) return;
    final locName = locCtrl.text.trim();
    final parkName = parkCtrl.text.trim();
    if (locName.isEmpty || parkName.isEmpty) {
      _snack('Заполните все поля');
      return;
    }

    final existingLoc = db.locations.firstWhere(
      (l) =>
          l.cityId == cityId &&
          l.name.toLowerCase() == locName.toLowerCase(),
      orElse: () => ParkLocation(id: '', cityId: '', name: ''),
    );
    ParkLocation loc;
    if (existingLoc.id.isNotEmpty) {
      if (!mounted) return;
      final useExisting = await _askUseExistingLocation(
          db, existingLoc, parkName);
      if (useExisting != true) return;
      loc = existingLoc;
    } else {
      loc = ParkLocation(id: _uid(), cityId: cityId, name: locName);
      db.locations.add(loc);
    }

    final park = Park(id: _uid(), locId: loc.id, name: parkName);
    db.parks.add(park);
    db.addParkToRegion(region.id, park.id);
    await db.save();
    if (!mounted) return;
    _snack('Создано: ${pickedCity.name} → $locName → $parkName');
  }

  Future<void> _addNewCityWithChain(AppDatabase db, Region region) async {
    final cityCtrl = TextEditingController();
    final locCtrl = TextEditingController();
    final parkCtrl = TextEditingController();

    cityCtrl.addListener(() {
      if (locCtrl.text.isEmpty) locCtrl.text = cityCtrl.text;
      if (parkCtrl.text.isEmpty) parkCtrl.text = cityCtrl.text;
    });

    final ok = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: const Text('Новый город в регион'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text(
              'Создаётся цепочка: город → локация → парк. Если город с таким именем уже есть — будет предупреждение.',
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

    final existingCity = db.cities.firstWhere(
      (c) => c.name.toLowerCase() == cityName.toLowerCase(),
      orElse: () => City(id: '', name: ''),
    );
    City city;
    if (existingCity.id.isNotEmpty) {
      if (!mounted) return;
      final useExisting = await _askUseExistingCity(
          db, existingCity, locName, parkName);
      if (useExisting == null) return;
      if (useExisting == false) return;
      city = existingCity;
    } else {
      city = City(id: _uid(), name: cityName);
      db.cities.add(city);
    }

    final existingLoc = db.locations.firstWhere(
      (l) =>
          l.cityId == city.id &&
          l.name.toLowerCase() == locName.toLowerCase(),
      orElse: () => ParkLocation(id: '', cityId: '', name: ''),
    );
    ParkLocation loc;
    if (existingLoc.id.isNotEmpty) {
      if (!mounted) return;
      final useExistingLoc = await _askUseExistingLocation(
          db, existingLoc, parkName);
      if (useExistingLoc != true) return;
      loc = existingLoc;
    } else {
      loc = ParkLocation(id: _uid(), cityId: city.id, name: locName);
      db.locations.add(loc);
    }

    final park = Park(id: _uid(), locId: loc.id, name: parkName);
    db.parks.add(park);
    db.addParkToRegion(region.id, park.id);
    await db.save();
    if (!mounted) return;
    _snack('Создано: ${city.name} → ${loc.name} → $parkName');
  }

  Future<void> _attachExistingPark(AppDatabase db, Region region) async {
    final candidates =
        db.parks.where((p) => !region.parkIds.contains(p.id)).toList();

    await showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: Text('Привязать парк · ${region.name}'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: candidates.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text('Нет парков для привязки',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 12, color: AppColors.dim)),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: candidates.map((p) {
                      final loc = db.locById(p.locId);
                      final city =
                          loc == null ? null : db.cityById(loc.cityId);
                      final otherRegions = db.regionsOfPark(p.id);
                      final inOther = otherRegions.isNotEmpty;
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
                                  Text(p.name,
                                      style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600)),
                                  Text(
                                    '${city?.name ?? "—"} → ${loc?.name ?? "—"}'
                                    '${inOther ? " · сейчас в «${otherRegions.first.name}» (перенесётся)" : ""}',
                                    style: TextStyle(
                                        fontSize: 10.5,
                                        color: inOther
                                            ? AppColors.amb
                                            : AppColors.dim),
                                  ),
                                ]),
                          ),
                          TextButton(
                            onPressed: () {
                              db.addParkToRegion(region.id, p.id);
                              Navigator.pop(ctx);
                              _snack('Парк привязан');
                            },
                            child: const Text('Привязать',
                                style: TextStyle(fontSize: 12)),
                          ),
                        ]),
                      );
                    }).toList(),
                  ),
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

  // ═══════════ confirm helpers ═══════════

  Future<bool?> _askUseExistingCity(AppDatabase db, City city,
      String locName, String parkName) async {
    final locsCount =
        db.locations.where((l) => l.cityId == city.id).length;
    final parksCount = db.parks.where((p) {
      final loc = db.locById(p.locId);
      return loc?.cityId == city.id;
    }).length;

    return showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: const Text('Город уже существует'),
        content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'В базе уже есть город «${city.name}». Локаций: $locsCount, парков: $parksCount.',
                style: const TextStyle(fontSize: 13, color: AppColors.mut),
              ),
              const SizedBox(height: 12),
              const Text(
                'Использовать его для создания новой локации и парка?',
                style: TextStyle(fontSize: 12.5),
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
            child: const Text('Использовать этот город'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _askUseExistingLocation(AppDatabase db,
      ParkLocation loc, String parkName) async {
    final parksCount = db.parks.where((p) => p.locId == loc.id).length;

    return showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: const Text('Локация уже существует'),
        content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'В этом городе уже есть локация «${loc.name}». Парков в ней: $parksCount.',
                style: const TextStyle(fontSize: 13, color: AppColors.mut),
              ),
              const SizedBox(height: 12),
              Text(
                'Создать парк «$parkName» в этой локации?',
                style: const TextStyle(fontSize: 12.5),
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
            child: const Text('Использовать локацию'),
          ),
        ],
      ),
    );
  }

  // ═══════════ region dialogs ═══════════

  Future<void> _openRegionDialog(
      AppDatabase db, Employee admin, Region? editing) async {
    final nameCtrl = TextEditingController(text: editing?.name ?? '');
    final selected = <String>{...?editing?.parkIds};

    final ok = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
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
                          'Нет парков — создайте через меню региона',
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
                            '${occupied ? " · уже в «${otherRegion.first.name}»" : ""}',
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
      useRootNavigator: true,
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
      useRootNavigator: true,
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