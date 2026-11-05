import 'package:flutter/material.dart';
import '../data/app_database.dart';
import '../data/debug_log.dart';
import '../models/employee.dart';
import '../models/models.dart';
import '../models/region.dart';
import '../theme.dart';
import '../widgets/role_management_dialog.dart';
import '../widgets/workplace_change_dialog.dart';

class AdminAdminsTab extends StatefulWidget {
  final AppDatabase db;
  final Employee currentAdmin;
  const AdminAdminsTab({
    super.key,
    required this.db,
    required this.currentAdmin,
  });

  @override
  State<AdminAdminsTab> createState() => _AdminAdminsTabState();
}

class _AdminAdminsTabState extends State<AdminAdminsTab> {
  final Set<String> _collapsedRegions = {};
  final Set<String> _collapsedParks = {};
  bool _superCollapsed = false;
  bool _freeParkCollapsed = false;
  bool _freeRegionCollapsed = false;
  bool _showFired = false;

  String _uid() => 'x${DateTime.now().microsecondsSinceEpoch}';

  AppDatabase get db => widget.db;
  Employee get me => widget.currentAdmin;

  // ═══════════ фильтрованные списки ═══════════

  List<Employee> _regAdminsFor(String regionId) {
    return db.employees
        .where((e) =>
            e.role == EmployeeRole.regionalAdmin &&
            e.regionId == regionId &&
            (_showFired || e.status == EmployeeStatus.active))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  List<Employee> _parkAdminsFor(String parkId) {
    return db.employees
        .where((e) =>
            e.role == EmployeeRole.parkAdmin &&
            e.parkId == parkId &&
            (_showFired || e.status == EmployeeStatus.active))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _actionsBar(),
        const SizedBox(height: 12),
        if (me.role == EmployeeRole.superAdmin) ..._superSection(),
        ..._regionsSection(),
        if (me.role == EmployeeRole.superAdmin) _unassignedParksSection(),
        if (me.role == EmployeeRole.superAdmin) ...[
          _freeParkAdminsSection(),
          _freeRegionalAdminsSection(),
        ],
      ],
    );
  }

  // ═══════════ Верхняя панель ═══════════

  Widget _actionsBar() {
    return Row(children: [
      if (me.role == EmployeeRole.superAdmin)
        _primaryBtn(
          icon: Icons.person_add,
          label: 'Рег. админ',
          onTap: _createRegionalAdmin,
        ),
      if (me.role == EmployeeRole.superAdmin) const SizedBox(width: 8),
      _primaryBtn(
        icon: Icons.person_add,
        label: 'Админ парка',
        onTap: _createParkAdmin,
      ),
      const SizedBox(width: 8),
      _firedToggle(),
    ]);
  }

  Widget _firedToggle() {
    final active = _showFired;
    return Tooltip(
      message: active ? 'Скрыть уволенных' : 'Показать уволенных',
      child: InkWell(
        onTap: () => setState(() => _showFired = !_showFired),
        borderRadius: BorderRadius.circular(9),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: active
                ? AppColors.red.withValues(alpha: 0.12)
                : AppColors.panel2,
            border: Border.all(
              color: active
                  ? AppColors.red.withValues(alpha: 0.4)
                  : AppColors.line2,
            ),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(
            active ? Icons.visibility : Icons.visibility_off,
            size: 16,
            color: active ? AppColors.red : AppColors.mut,
          ),
        ),
      ),
    );
  }

  // ═══════════ Super-блок ═══════════

  List<Widget> _superSection() {
    final supers = db.superAdmins;
    if (supers.isEmpty) return [];
    return [
      Container(
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
                padding: const EdgeInsets.all(6),
                child: Column(
                  children: supers.map((e) => _adminRow(e)).toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    ];
  }

  // ═══════════ Регионы ═══════════

  List<Widget> _regionsSection() {
    final visible = me.role == EmployeeRole.superAdmin
        ? db.regions
        : (me.regionId == null
            ? <Region>[]
            : [db.regionById(me.regionId!)].whereType<Region>().toList());

    if (visible.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 46),
          decoration: _cardDeco,
          child: const Center(
            child: Text('Нет регионов',
                style: TextStyle(color: AppColors.dim, fontSize: 12)),
          ),
        ),
      ];
    }

    return visible.map((r) => _regionNode(r)).toList();
  }

  Widget _regionNode(Region region) {
    final regAdmins = _regAdminsFor(region.id);
    final parks = db.parksOfRegion(region.id);
    final collapsed = _collapsedRegions.contains(region.id);
    final totalAdmins = regAdmins.length +
        parks.fold<int>(0, (a, p) => a + _parkAdminsFor(p.id).length);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: _cardDeco,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() {
              if (collapsed) {
                _collapsedRegions.remove(region.id);
              } else {
                _collapsedRegions.add(region.id);
              }
            }),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
              child: Row(children: [
                Icon(collapsed ? Icons.chevron_right : Icons.expand_more,
                    size: 16, color: AppColors.mut),
                const SizedBox(width: 4),
                const Icon(Icons.map_outlined, size: 13, color: AppColors.cyn),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(region.name,
                          style: const TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.w700)),
                      Text(
                        'Парков: ${parks.length} · '
                        'Рег. админ: ${regAdmins.isEmpty ? "нет" : regAdmins.length}',
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.dim),
                      ),
                    ],
                  ),
                ),
                _countBadge(totalAdmins),
                if (me.role == EmployeeRole.superAdmin)
                  IconButton(
                    icon: const Icon(Icons.person_add, size: 16),
                    color: AppColors.cyn,
                    tooltip: 'Назначить рег. админа',
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 30, minHeight: 30),
                    onPressed: () => _pickAdminForRegion(region),
                  ),
              ]),
            ),
          ),
          if (!collapsed) ...[
            const Divider(height: 1, color: AppColors.line),
            Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (regAdmins.isEmpty)
                    _emptyRegAdminRow(region)
                  else
                    ...regAdmins.map((a) => _adminRow(a)),
                  if (parks.isNotEmpty) const SizedBox(height: 6),
                  ...parks.map((p) => _parkNode(p)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _emptyRegAdminRow(Region region) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.amb.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.amb.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        const Icon(Icons.warning_amber, size: 12, color: AppColors.amb),
        const SizedBox(width: 6),
        const Expanded(
          child: Text('Рег. админ не назначен',
              style: TextStyle(fontSize: 10.5, color: AppColors.amb)),
        ),
        if (me.role == EmployeeRole.superAdmin)
          TextButton(
            onPressed: () => _pickAdminForRegion(region),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              minimumSize: const Size(0, 26),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Назначить',
                style: TextStyle(fontSize: 11)),
          ),
      ]),
    );
  }

  Widget _parkNode(Park park) {
    final admins = _parkAdminsFor(park.id);
    final collapsed = _collapsedParks.contains(park.id);

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
                _collapsedParks.remove(park.id);
              } else {
                _collapsedParks.add(park.id);
              }
            }),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
              child: Row(children: [
                Icon(collapsed ? Icons.chevron_right : Icons.expand_more,
                    size: 14, color: AppColors.mut),
                const SizedBox(width: 4),
                const Icon(Icons.attractions, size: 12, color: AppColors.amb),
                const SizedBox(width: 5),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(park.name,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600)),
                      Text(
                        admins.isEmpty
                            ? 'нет админа'
                            : 'админов: ${admins.length}',
                        style: TextStyle(
                          fontSize: 9.5,
                          color:
                              admins.isEmpty ? AppColors.dim : AppColors.grn,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.person_add, size: 14),
                  color: AppColors.amb,
                  tooltip: 'Назначить админа парка',
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 26, minHeight: 26),
                  onPressed: () => _pickAdminForPark(park),
                ),
              ]),
            ),
          ),
          if (!collapsed && admins.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 0, 2, 4),
              child: Column(
                children: admins.map((a) => _adminRow(a)).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _unassignedParksSection() {
    final unassigned = db.unassignedParks;
    if (unassigned.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.amb.withValues(alpha: 0.06),
          border: Border.all(color: AppColors.amb.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Row(children: [
                const Icon(Icons.link_off, size: 13, color: AppColors.amb),
                const SizedBox(width: 6),
                Text('Парки вне регионов · ${unassigned.length}',
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.amb2)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                children: unassigned.map((p) => _parkNode(p)).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════ Свободные админы парков ═══════════

  Widget _freeParkAdminsSection() {
    final free = db.employees.where((a) {
      if (!_showFired && a.status != EmployeeStatus.active) return false;
      if (a.role != EmployeeRole.parkAdmin) return false;
      if (a.parkId != null) return false;
      return true;
    }).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    if (free.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.panel,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: () => setState(
                  () => _freeParkCollapsed = !_freeParkCollapsed),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Row(children: [
                  Icon(
                      _freeParkCollapsed
                          ? Icons.chevron_right
                          : Icons.expand_more,
                      size: 16,
                      color: AppColors.mut),
                  const SizedBox(width: 4),
                  const Icon(Icons.person_off,
                      size: 13, color: AppColors.grn),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text('Свободные админы парков',
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700)),
                  ),
                  _countBadge(free.length),
                ]),
              ),
            ),
            if (!_freeParkCollapsed) ...[
              const Divider(height: 1, color: AppColors.line),
              Padding(
                padding: const EdgeInsets.all(6),
                child: Column(
                  children: free.map((a) => _adminRow(a)).toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ═══════════ Свободные рег. админы ═══════════

  Widget _freeRegionalAdminsSection() {
    final free = db.employees.where((a) {
      if (!_showFired && a.status != EmployeeStatus.active) return false;
      if (a.role != EmployeeRole.regionalAdmin) return false;
      if (a.regionId != null) return false;
      return true;
    }).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    if (free.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.panel,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: () => setState(
                  () => _freeRegionCollapsed = !_freeRegionCollapsed),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Row(children: [
                  Icon(
                      _freeRegionCollapsed
                          ? Icons.chevron_right
                          : Icons.expand_more,
                      size: 16,
                      color: AppColors.mut),
                  const SizedBox(width: 4),
                  const Icon(Icons.person_off,
                      size: 13, color: AppColors.cyn),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text('Свободные рег. админы',
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700)),
                  ),
                  _countBadge(free.length),
                ]),
              ),
            ),
            if (!_freeRegionCollapsed) ...[
              const Divider(height: 1, color: AppColors.line),
              Padding(
                padding: const EdgeInsets.all(6),
                child: Column(
                  children: free.map((a) => _adminRow(a)).toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ═══════════ строка админа ═══════════

  Widget _adminRow(Employee e) {
    final statusColor = Color(e.status.colorValue);
    final isFired = e.status == EmployeeStatus.fired;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0E14),
        borderRadius: BorderRadius.circular(6),
        border: isFired
            ? Border.all(color: AppColors.red.withValues(alpha: 0.25))
            : null,
      ),
      child: InkWell(
        onTap: () => _openAdminCard(e),
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: Color(e.role.colorValue).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(
                child: Text(_initials(e.name),
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(e.role.colorValue))),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.name,
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          decoration: isFired
                              ? TextDecoration.lineThrough
                              : null,
                          color: isFired
                              ? AppColors.dim
                              : AppColors.txt),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text(
                    'PIN ${e.pin} · ${e.role.label}${e.status != EmployeeStatus.active ? " · ${e.status.label}" : ""}',
                    style: TextStyle(
                        fontSize: 10,
                        color: isFired
                            ? AppColors.red.withValues(alpha: 0.7)
                            : AppColors.dim),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Container(
              width: 6,
              height: 6,
              decoration:
                  BoxDecoration(color: statusColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, size: 14, color: AppColors.dim),
          ]),
        ),
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

  // ═══════════ Карточка админа ═══════════

  Future<void> _openAdminCard(Employee emp) async {
    await showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final current = db.employeeById(emp.id) ?? emp;
          final park =
              current.parkId == null ? null : db.parkById(current.parkId);
          final region = current.regionId == null
              ? null
              : db.regionById(current.regionId);
          final isSuper = current.role == EmployeeRole.superAdmin;
          final isRegional = current.role == EmployeeRole.regionalAdmin;
          final isPark = current.role == EmployeeRole.parkAdmin;
          final isFired = current.status == EmployeeStatus.fired;

          return AlertDialog(
            backgroundColor: AppColors.panel,
            titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            title: Row(children: [
              Icon(
                isSuper
                    ? Icons.shield
                    : isRegional
                        ? Icons.map_outlined
                        : Icons.attractions,
                size: 20,
                color: Color(current.role.colorValue),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(current.name,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(current.role.label,
                        style: const TextStyle(
                            fontSize: 11.5, color: AppColors.dim)),
                  ],
                ),
              ),
            ]),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _infoLine('Телефон',
                        current.phone.isEmpty ? '—' : current.phone),
                    _infoLine('PIN', current.pin, mono: true),
                    _infoLine('Статус', current.status.label,
                        color: Color(current.status.colorValue)),
                    if (current.additionalRoles.isNotEmpty)
                      _infoLine(
                          'Доп. роли',
                          current.additionalRoles
                              .map((r) => r.label)
                              .join(', ')),
                    if (region != null) _infoLine('Регион', region.name),
                    if (park != null) _infoLine('Парк', park.name),
                    if (region == null && park == null && !isSuper)
                      _infoLine('Место работы',
                          isFired ? 'Уволен' : 'Свободен',
                          color: isFired ? AppColors.red : AppColors.org),
                    const SizedBox(height: 14),
                    if (!isSuper && !isFired) ...[
                      OutlinedButton.icon(
                        onPressed: () => _manageRoles(current, setS),
                        icon: const Icon(Icons.manage_accounts, size: 16),
                        label: const Text('Роли'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.pur,
                          side: BorderSide(
                              color: AppColors.pur.withValues(alpha: 0.4)),
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (isPark) ...[
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _changePark(current);
                          },
                          icon: const Icon(Icons.move_up, size: 16),
                          label: const Text('Перевести в другой парк'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.cyn,
                            side: BorderSide(
                                color: AppColors.cyn.withValues(alpha: 0.4)),
                          ),
                        ),
                        const SizedBox(height: 6),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final ok = await _confirmAction(
                              'Снять с должности?',
                              '${current.name} перестанет быть админом парка, '
                                  'останется в системе как «свободный админ».',
                              confirmLabel: 'Снять',
                              confirmColor: AppColors.amb,
                            );
                            if (ok != true) return;
                            if (!ctx.mounted) return;
                            db.removeAdminFromPark(current,
                                byAdminId: me.id);
                            Navigator.pop(ctx);
                            setState(() {});
                          },
                          icon: const Icon(Icons.person_remove, size: 16),
                          label: const Text('Снять с должности'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.amb2,
                            side: BorderSide(
                                color: AppColors.amb.withValues(alpha: 0.4)),
                          ),
                        ),
                      ],
                      if (isRegional) ...[
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _changeRegion(current);
                          },
                          icon: const Icon(Icons.move_up, size: 16),
                          label: const Text('Перевести в другой регион'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.cyn,
                            side: BorderSide(
                                color: AppColors.cyn.withValues(alpha: 0.4)),
                          ),
                        ),
                        const SizedBox(height: 6),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final ok = await _confirmAction(
                              'Снять с должности?',
                              '${current.name} перестанет быть рег. админом. '
                                  'Старые подчинённые будут отвязаны.',
                              confirmLabel: 'Снять',
                              confirmColor: AppColors.amb,
                            );
                            if (ok != true) return;
                            if (!ctx.mounted) return;
                            db.removeRegionalAdmin(current, byAdminId: me.id);
                            Navigator.pop(ctx);
                            setState(() {});
                          },
                          icon: const Icon(Icons.person_remove, size: 16),
                          label: const Text('Снять с должности'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.amb2,
                            side: BorderSide(
                                color: AppColors.amb.withValues(alpha: 0.4)),
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final ok = await _confirmAction(
                            'Уволить?',
                            '${current.name} будет уволен. История сохранится.',
                            confirmLabel: 'Уволить',
                            confirmColor: AppColors.red,
                          );
                          if (ok != true) return;
                          if (!ctx.mounted) return;
                          db.fireEmployee(current);
                          Navigator.pop(ctx);
                          setState(() {});
                        },
                        icon: const Icon(Icons.person_off, size: 16),
                        label: const Text('Уволить'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.red,
                          side: BorderSide(
                              color: AppColors.red.withValues(alpha: 0.4)),
                        ),
                      ),
                    ],
                  ],
                ),
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
    setState(() {});
  }

  Future<void> _manageRoles(Employee admin, StateSetter setS) async {
  // SuperAdmin (владелец) может менять основную роль.
  // RegionalAdmin — только дополнительные.
  final isOwner = me.role == EmployeeRole.superAdmin;

  final result = await showRoleManagementDialog(
    context: context,
    employee: admin,
    selectableRoles: const [
      EmployeeRole.parkAdmin,
      EmployeeRole.regionalAdmin,
    ],
    selectableExtras: const [
      EmployeeRole.operator,
      EmployeeRole.technician,
    ],
    canChangePrimary: isOwner,
  );
  if (result == null) return;
  db.setRoles(admin, result.primary, result.extras);
  setS(() {});
  setState(() {});
  _snack('Роли обновлены');
}

  Widget _infoLine(String label, String value,
      {bool mono = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        SizedBox(
          width: 110,
          child: Text(label,
              style:
                  const TextStyle(fontSize: 11.5, color: AppColors.dim)),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              fontFamily: mono ? 'monospace' : null,
              color: color ?? AppColors.txt,
            ),
          ),
        ),
      ]),
    );
  }

  // ═══════════ Перевод ═══════════

  Future<void> _changePark(Employee admin) async {
    final result = await showWorkplaceChangeDialog(
      context: context,
      db: db,
      employee: admin,
      type: WorkplaceChangeType.park,
    );
    if (result == null || result.parkId == null) return;
    if (result.parkId == admin.parkId) {
      _snack('Уже в этом парке');
      return;
    }

    final park = db.parkById(result.parkId!);
    if (park == null) return;
    db.assignAdminToPark(admin, park, reason: 'Переведён в другой парк');
    setState(() {});
    _snack('Переведён в ${park.name}');
  }

  Future<void> _changeRegion(Employee admin) async {
    final result = await showWorkplaceChangeDialog(
      context: context,
      db: db,
      employee: admin,
      type: WorkplaceChangeType.region,
    );
    if (result == null || result.regionId == null) return;
    if (result.regionId == admin.regionId) {
      _snack('Уже в этом регионе');
      return;
    }

    final region = db.regionById(result.regionId!);
    if (region == null) return;
    db.assignRegionalAdmin(admin, region, reason: 'Переведён в другой регион');
    setState(() {});
    _snack('Переведён в ${region.name}');
  }

  // ═══════════ Назначение: регион ═══════════

  Future<void> _pickAdminForRegion(Region region) async {
    final all = db.employees.where((a) {
      if (a.status != EmployeeStatus.active) return false;
      if (a.role != EmployeeRole.regionalAdmin &&
          a.role != EmployeeRole.parkAdmin) {
        return false;
      }
      if (a.regionId == region.id) return false;
      return true;
    }).toList();

    // Свободен = ни региона, ни парка
    final free = all
        .where((a) => a.regionId == null && a.parkId == null)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    // Занят = есть регион или парк
    final busy = all
        .where((a) => a.regionId != null || a.parkId != null)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    await showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: Text('Рег. админ · ${region.name}'),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (free.isEmpty && busy.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Text(
                        'Нет доступных админов. Создайте нового.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 12, color: AppColors.dim)),
                  ),
                if (free.isNotEmpty) ...[
                  const _SectionLabel('СВОБОДНЫЕ'),
                  ...free.map((a) => _candidateTile(
                        a,
                        subtitle: 'Свободен · ${a.role.label}',
                        onTap: () async {
                          db.assignRegionalAdmin(a, region,
                              reason: 'Назначен из списка');
                          Navigator.pop(ctx);
                          setState(() {});
                          _snack('Назначен: ${a.name}');
                        },
                      )),
                  const SizedBox(height: 10),
                ],
                if (busy.isNotEmpty) ...[
                  const _SectionLabel('ЗАНЯТЫЕ'),
                  ...busy.map((a) => _candidateTile(
                        a,
                        subtitle: _busySubtitle(a),
                        warning: true,
                        onTap: () async {
                          final ok = await _confirmAction(
                            'Перевести?',
                            '${a.name} сейчас ${_busySubtitle(a)}. '
                                'Перевести в регион «${region.name}»?',
                            confirmLabel: 'Перевести',
                            confirmColor: AppColors.amb,
                          );
                          if (ok != true) return;
                          if (!ctx.mounted) return;
                          db.assignRegionalAdmin(a, region,
                              reason: 'Переведён в регион');
                          Navigator.pop(ctx);
                          setState(() {});
                          _snack('Назначен: ${a.name}');
                        },
                      )),
                  const SizedBox(height: 10),
                ],
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.amb,
                      foregroundColor: const Color(0xFF1C1204)),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _createAdmin(regionId: region.id);
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

  // ═══════════ Назначение: парк ═══════════

  Future<void> _pickAdminForPark(Park park) async {
    final all = db.employees.where((a) {
      if (a.status != EmployeeStatus.active) return false;
      if (a.role != EmployeeRole.parkAdmin &&
          a.role != EmployeeRole.regionalAdmin) {
        return false;
      }
      if (a.parkId == park.id) return false;
      return true;
    }).toList();

    // Свободен для парка = нет парка И нет региона.
    // Рег. админ с регионом — занят (перевод с подтверждением).
    final free = all
        .where((a) => a.parkId == null && a.regionId == null)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final busy = all
        .where((a) => a.parkId != null || a.regionId != null)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    await showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: Text('Админ парка · ${park.name}'),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (free.isEmpty && busy.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Text(
                        'Нет доступных админов. Создайте нового.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 12, color: AppColors.dim)),
                  ),
                if (free.isNotEmpty) ...[
                  const _SectionLabel('СВОБОДНЫЕ'),
                  ...free.map((a) => _candidateTile(
                        a,
                        subtitle: 'Свободен · ${a.role.label}',
                        onTap: () async {
                          db.assignAdminToPark(a, park,
                              reason: 'Назначен из списка');
                          Navigator.pop(ctx);
                          setState(() {});
                          _snack('Назначен: ${a.name}');
                        },
                      )),
                  const SizedBox(height: 10),
                ],
                if (busy.isNotEmpty) ...[
                  const _SectionLabel('ЗАНЯТЫЕ'),
                  ...busy.map((a) => _candidateTile(
                        a,
                        subtitle: _busySubtitle(a),
                        warning: true,
                        onTap: () async {
                          final ok = await _confirmAction(
                            'Перевести?',
                            '${a.name} сейчас ${_busySubtitle(a)}. '
                                'Перевести в парк «${park.name}»?',
                            confirmLabel: 'Перевести',
                            confirmColor: AppColors.amb,
                          );
                          if (ok != true) return;
                          if (!ctx.mounted) return;
                          db.assignAdminToPark(a, park,
                              reason: 'Переведён в парк');
                          Navigator.pop(ctx);
                          setState(() {});
                          _snack('Назначен: ${a.name}');
                        },
                      )),
                  const SizedBox(height: 10),
                ],
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.amb,
                      foregroundColor: const Color(0xFF1C1204)),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _createAdmin(parkId: park.id);
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

  Widget _candidateTile(
    Employee a, {
    required String subtitle,
    required Future<void> Function() onTap,
    bool warning = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.panel2,
        borderRadius: BorderRadius.circular(8),
        border: warning
            ? Border.all(color: AppColors.amb.withValues(alpha: 0.3))
            : null,
      ),
      child: Row(children: [
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${a.name} · PIN ${a.pin}',
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w600)),
                Text(
                  subtitle,
                  style: TextStyle(
                      fontSize: 10.5,
                      color: warning ? AppColors.amb : AppColors.dim),
                ),
              ]),
        ),
        TextButton(
          onPressed: onTap,
          child: const Text('Выбрать', style: TextStyle(fontSize: 12)),
        ),
      ]),
    );
  }

  String _busySubtitle(Employee a) {
    if (a.parkId != null) {
      final p = db.parkById(a.parkId);
      return 'админ парка «${p?.name ?? "—"}»';
    }
    if (a.regionId != null) {
      final r = db.regionById(a.regionId);
      return 'рег. админ «${r?.name ?? "—"}»';
    }
    return 'свободен';
  }

  // ═══════════ Создание новых ═══════════

  Future<void> _createRegionalAdmin() async {
    if (db.regions.isEmpty) {
      _snack('Сначала создайте регион в «Инфраструктуре»');
      return;
    }
    String? selRegionId = db.regions.first.id;
    final ok = await showDialog<String>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: AppColors.panel,
          title: const Text('Новый рег. админ'),
          content: SizedBox(
            width: 440,
            child: DropdownButtonFormField<String>(
              initialValue: selRegionId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Регион'),
              items: [
                for (final r in db.regions)
                  DropdownMenuItem(value: r.id, child: Text(r.name)),
              ],
              onChanged: (v) => setS(() => selRegionId = v),
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
              onPressed: () => Navigator.pop(ctx, selRegionId),
              child: const Text('Далее'),
            ),
          ],
        ),
      ),
    );
    if (ok == null) return;
    await _createAdmin(regionId: ok);
  }

  Future<void> _createParkAdmin() async {
    final parks = me.role == EmployeeRole.superAdmin
        ? db.parks
        : db.parks.where((p) {
            return db
                .regionsOfPark(p.id)
                .any((r) => r.id == me.regionId);
          }).toList();
    if (parks.isEmpty) {
      _snack('Нет доступных парков');
      return;
    }
    final sorted = List<Park>.from(parks)
      ..sort((a, b) => a.name.compareTo(b.name));
    String? selParkId = sorted.first.id;
    final ok = await showDialog<String>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: AppColors.panel,
          title: const Text('Новый админ парка'),
          content: SizedBox(
            width: 440,
            child: DropdownButtonFormField<String>(
              initialValue: selParkId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Парк'),
              items: [
                for (final p in sorted)
                  DropdownMenuItem(
                    value: p.id,
                    child: Text('${p.name} · ${db.cityOfPark(p)}',
                        overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) => setS(() => selParkId = v),
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
              onPressed: () => Navigator.pop(ctx, selParkId),
              child: const Text('Далее'),
            ),
          ],
        ),
      ),
    );
    if (ok == null) return;
    await _createAdmin(parkId: ok);
  }

  Future<bool?> _createAdmin({String? regionId, String? parkId}) async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final pinCtrl = TextEditingController(text: '0000');
    final isRegional = regionId != null;

    final ok = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: Text(isRegional ? 'Новый рег. админ' : 'Новый админ парка'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'ФИО *'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                  labelText: 'Телефон', hintText: '+7 900 000-00-00'),
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
    if (ok != true) return null;
    final name = nameCtrl.text.trim();
    final phone = phoneCtrl.text.trim();
    final pin = pinCtrl.text.trim();
    if (name.isEmpty) {
      _snack('Укажите ФИО');
      return null;
    }
    if (pin.length < 4 || pin.length > 6 || int.tryParse(pin) == null) {
      _snack('PIN: 4–6 цифр');
      return null;
    }
    if (db.employees
        .any((a) => a.status == EmployeeStatus.active && a.pin == pin)) {
      _snack('PIN уже используется');
      return null;
    }
    final now = DateTime.now();

    final newAdmin = Employee(
      id: _uid(),
      name: name,
      phone: phone,
      pin: pin,
      role: EmployeeRole.operator, // временная, перезапишется
      managerId: me.id,
      createdAt: now,
      history: [],
    );
    db.employees.add(newAdmin);

    if (!isRegional && parkId != null) {
      final park = db.parkById(parkId);
      if (park != null) {
        db.assignAdminToPark(newAdmin, park, reason: 'Создан и назначен');
      } else {
        await db.save();
      }
    } else if (isRegional && regionId != null) {
      final region = db.regionById(regionId);
      if (region != null) {
        db.assignRegionalAdmin(newAdmin, region, reason: 'Создан и назначен');
      } else {
        await db.save();
      }
    } else {
      await db.save();
    }

    DebugLog.instance.info(
        'admin created: $name (${isRegional ? "regional" : "park"})');
    if (!mounted) return null;
    _snack('Админ создан');
    setState(() {});
    return true;
  }

  // ═══════════ helpers ═══════════

  Future<bool?> _confirmAction(
    String title,
    String text, {
    String confirmLabel = 'OK',
    Color confirmColor = AppColors.red,
  }) async {
    return showDialog<bool>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: Text(title),
        content: Text(text,
            style: const TextStyle(fontSize: 13, color: AppColors.mut)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: confirmColor,
              foregroundColor:
                  confirmColor == AppColors.red
                      ? Colors.white
                      : const Color(0xFF1C1204),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

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

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(text,
          style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.dim,
              letterSpacing: 0.6)),
    );
  }
}