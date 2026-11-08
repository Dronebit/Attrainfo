import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/app_database.dart';
import '../data/debug_log.dart';
import '../data/nfc_helper.dart';
import '../models/employee.dart';
import '../models/operator_park_link.dart';
import '../theme.dart';

class OperatorsScreen extends StatefulWidget {
  const OperatorsScreen({super.key});
  @override
  State<OperatorsScreen> createState() => _OperatorsScreenState();
}

class _OperatorsScreenState extends State<OperatorsScreen> {
  bool _unlocked = false;
  Employee? _currentAdmin;
  String _filter = 'all';
  String _query = '';
  final _searchCtrl = TextEditingController();

  String _uid() => 'x${DateTime.now().microsecondsSinceEpoch}';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = context.watch<AppDatabase>();
    if (!_unlocked) return _pinGate(db);

    final admin = _currentAdmin;
    if (admin == null) return _pinGate(db);

    switch (admin.role) {
      case EmployeeRole.parkAdmin:
        return _parkAdminView(db, admin);
      case EmployeeRole.regionalAdmin:
        return _wrongRole('регионального администратора',
            'Откройте вкладку «Админ-панель» для управления парками региона.');
      case EmployeeRole.superAdmin:
        return _wrongRole('супер-администратора',
            'Откройте вкладку «Админ-панель» для управления регионами.');
      case EmployeeRole.operator:
      case EmployeeRole.technician:
        return _wrongRole('этот экран',
            'Доступ только для администраторов парков.');
    }
  }

  // ═══════════ PIN gate ═══════════

  Widget _pinGate(AppDatabase db) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: _cardDeco,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.admin_panel_settings,
                size: 42, color: AppColors.amb),
            const SizedBox(height: 14),
            const Text('Панель администратора',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            const Text('Введите PIN для доступа',
                style: TextStyle(fontSize: 12.5, color: AppColors.mut)),
            const SizedBox(height: 18),
            if (db.admins.isNotEmpty) ...[
              const Text('Администраторы:',
                  style: TextStyle(fontSize: 11, color: AppColors.dim)),
              const SizedBox(height: 6),
              ...db.admins
                  .where((a) => a.status == EmployeeStatus.active)
                  .map((a) {
                final subtitle = switch (a.role) {
                  EmployeeRole.superAdmin => 'Super · ${a.name}',
                  EmployeeRole.regionalAdmin => () {
                      final r = db.regionById(a.regionId);
                      return 'Регион: ${r?.name ?? "—"} · ${a.name}';
                    }(),
                  EmployeeRole.parkAdmin => () {
                      final p = db.parkById(a.parkId);
                      return '${p?.name ?? "—"} · ${a.name}';
                    }(),
                  _ => a.name,
                };
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(subtitle,
                      style: const TextStyle(fontSize: 11.5),
                      textAlign: TextAlign.center),
                );
              }),
              const SizedBox(height: 18),
            ],
            _primaryBtn(
              icon: Icons.key,
              label: 'Ввести PIN',
              onTap: () => _askPin(db),
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
          decoration:
              const InputDecoration(labelText: 'PIN', counterText: ''),
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

    // fallback 9999 → super
    if (pin == AppDatabase.masterPin) {
      final superAdmin = db.superAdmins.isNotEmpty
          ? db.superAdmins.first
          : Employee(
              id: 'fallback',
              name: 'Super (fallback)',
              role: EmployeeRole.superAdmin,
            );
      DebugLog.instance.info('PIN 9999 → super fallback');
      setState(() {
        _unlocked = true;
        _currentAdmin = superAdmin;
      });
      return;
    }

    final emp = db.employeeByPin(pin);
    if (emp == null || !emp.isAdmin) {
      if (!mounted) return;
      _snack('Неверный PIN или недостаточно прав');
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

  Widget _wrongRole(String roleName, String hint) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: _cardDeco,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.info_outline, size: 42, color: AppColors.blu),
            const SizedBox(height: 14),
            Text('Вход для $roleName',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(hint,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 12.5, color: AppColors.mut)),
            const SizedBox(height: 18),
            TextButton(
              onPressed: _logout,
              child: const Text('Выйти'),
            ),
          ]),
        ),
      ),
    );
  }

  // ═══════════ parkAdmin view ═══════════

  Widget _parkAdminView(AppDatabase db, Employee admin) {
    final park = admin.parkId == null ? null : db.parkById(admin.parkId);
    if (park == null) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: _cardDeco,
          child: const Text('У администратора не назначен парк',
              style: TextStyle(color: AppColors.red)),
        ),
      );
    }

    final myOps = db.operatorsOfPark(park.id);
    final pending = db.pendingLinksForPark(park.id);

    final filtered = myOps.where((o) {
      final q = _query.toLowerCase().trim();
      if (_filter == 'active' && o.status != EmployeeStatus.active) {
        return false;
      }
      if (_filter == 'vacation' && o.status != EmployeeStatus.vacation) {
        return false;
      }
      if (_filter == 'fired' && o.status != EmployeeStatus.fired) {
        return false;
      }
      if (q.isNotEmpty) {
        final hay = '${o.name} ${o.phone}'.toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList()
      ..sort((a, b) {
        if (a.canWork != b.canWork) {
          return a.canWork ? -1 : 1;
        }
        return a.name.compareTo(b.name);
      });

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(
          child: Text(
            '${park.name} · операторов: ${myOps.length}'
            '${pending.isNotEmpty ? " · заявок: ${pending.length}" : ""}',
            style: const TextStyle(fontSize: 11.5, color: AppColors.dim),
          ),
        ),
        TextButton.icon(
          onPressed: _logout,
          icon: const Icon(Icons.logout, size: 14),
          label: const Text('Выйти', style: TextStyle(fontSize: 12)),
        ),
        const SizedBox(width: 8),
        _primaryBtn(
          icon: Icons.person_add,
          label: 'Оператор',
          onTap: () => _openOperatorDialog(db, admin, null),
        ),
      ]),
      const SizedBox(height: 12),

      if (pending.isNotEmpty) ...[
        _pendingLinksSection(db, admin, pending),
        const SizedBox(height: 12),
      ],

      Container(
        padding: const EdgeInsets.all(14),
        decoration: _cardDeco,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Wrap(spacing: 8, runSpacing: 8, children: [
            _chip('Все', _filter == 'all',
                () => setState(() => _filter = 'all')),
            _chip('Работают', _filter == 'active',
                () => setState(() => _filter = 'active'),
                color: AppColors.grn),
            _chip('Отпуск', _filter == 'vacation',
                () => setState(() => _filter = 'vacation'),
                color: AppColors.blu),
            _chip('Уволены', _filter == 'fired',
                () => setState(() => _filter = 'fired'),
                color: AppColors.mut),
          ]),
          const SizedBox(height: 10),
          TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Поиск по имени или телефону…',
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

      if (filtered.isEmpty)
        Container(
          padding: const EdgeInsets.symmetric(vertical: 46),
          decoration: _cardDeco,
          child: const Center(
            child: Text('Операторов не найдено',
                style: TextStyle(color: AppColors.dim)),
          ),
        )
      else
        ...filtered.map((o) => _operatorCard(db, admin, o)),
    ]);
  }

  Widget _pendingLinksSection(
      AppDatabase db, Employee admin, List<OperatorParkLink> pending) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.amb.withValues(alpha: 0.06),
        border: Border.all(color: AppColors.amb.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(14),
      ),
      child:
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Icon(Icons.inbox, size: 16, color: AppColors.amb),
          const SizedBox(width: 8),
          Text('Заявки на привязку · ${pending.length}',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.amb2)),
        ]),
        const SizedBox(height: 10),
        ...pending.map((link) {
          final op = db.operatorById(link.operatorId);
          final initiator =
              link.initiatorAdminId == null
                  ? null
                  : db.adminById(link.initiatorAdminId);
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.panel,
              border: Border.all(color: AppColors.line),
              borderRadius: BorderRadius.circular(10),
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(op?.name ?? '—',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              if (initiator != null)
                Text(
                  'От: ${initiator.name}',
                  style: const TextStyle(fontSize: 11, color: AppColors.dim),
                ),
              if (link.note != null)
                Text('«${link.note}»',
                    style: const TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: AppColors.dim)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: _smallBtn(
                    icon: Icons.check,
                    label: 'Одобрить',
                    color: AppColors.grn,
                    onTap: () {
                      db.approveLink(link.id, admin.id);
                      _snack('Привязка одобрена');
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _smallBtn(
                    icon: Icons.close,
                    label: 'Отклонить',
                    color: AppColors.red,
                    onTap: () {
                      db.rejectLink(link.id, admin.id);
                      _snack('Заявка отклонена');
                    },
                  ),
                ),
              ]),
            ]),
          );
        }),
      ]),
    );
  }

  // ═══════════ operator card ═══════════

  Widget _operatorCard(AppDatabase db, Employee admin, Employee o) {
    final color = Color(o.status.colorValue);
    final myParkId = admin.parkId;
    final approvedLinks = db
        .linksForOperator(o.id)
        .where((l) => l.status == LinkStatus.approved)
        .toList();
    final otherParks = approvedLinks
        .where((l) => l.parkId != myParkId)
        .map((l) => db.parkById(l.parkId))
        .whereType<dynamic>()
        .toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: _cardDeco,
      child:
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.panel2,
            child: Text(_initials(o.name),
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 14)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(o.name,
                      style: const TextStyle(
                          fontSize: 14.5, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Row(children: [
                    Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                            color: color, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(o.status.label,
                        style: TextStyle(
                            fontSize: 11.5,
                            color: color,
                            fontWeight: FontWeight.w600)),
                    if (o.statusNote != null) ...[
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text('· ${o.statusNote}',
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.dim),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ]),
                  if (o.phone.isNotEmpty)
                    Text(o.phone,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.dim)),
                ]),
          ),
        ]),
        const SizedBox(height: 8),

        if (otherParks.isNotEmpty || myParkId != null) ...[
          Wrap(spacing: 6, runSpacing: 6, children: [
            if (myParkId != null)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.amb.withValues(alpha: 0.1),
                  border:
                      Border.all(color: AppColors.amb.withValues(alpha: 0.4)),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.star, size: 10, color: AppColors.amb2),
                  const SizedBox(width: 4),
                  Text(db.parkById(myParkId)?.name ?? '—',
                      style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.amb2)),
                ]),
              ),
            ...otherParks.map((p) => Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.panel2,
                    border: Border.all(color: AppColors.line2),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(p.name as String,
                      style: const TextStyle(fontSize: 10.5)),
                )),
          ]),
          const SizedBox(height: 8),
        ],

        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: const Color(0xFF0E1420),
            border: Border.all(color: AppColors.line2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(children: [
            Icon(Icons.nfc,
                size: 16,
                color:
                    o.badgeId != null ? AppColors.grn : AppColors.dim),
            const SizedBox(width: 8),
            Expanded(
              child: o.badgeId == null
                  ? const Text('Бейдж не привязан',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.dim))
                  : Text('Бейдж: ${o.badgeId}',
                      style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                          color: AppColors.txt)),
            ),
            if (o.badgeId == null)
              TextButton(
                  onPressed: () => _bindBadge(db, o),
                  child: const Text('Привязать',
                      style: TextStyle(fontSize: 12)))
            else
              TextButton(
                  onPressed: () => _unbindBadge(db, o),
                  child: const Text('Отвязать',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.red))),
          ]),
        ),
        const SizedBox(height: 10),

        Wrap(spacing: 6, runSpacing: 6, children: [
          _smallBtn(
            icon: Icons.edit_outlined,
            label: 'Изменить',
            onTap: () => _openOperatorDialog(db, admin, o),
          ),
          _smallBtn(
            icon: Icons.key,
            label: 'PIN',
            onTap: () => _changePin(db, o),
          ),
          _smallBtn(
            icon: Icons.flag_outlined,
            label: 'Статус',
            onTap: () => _changeStatus(db, o),
          ),
          _smallBtn(
            icon: Icons.add_link,
            label: 'К парку',
            color: AppColors.cyn,
            onTap: () => _addParkLink(db, admin, o),
          ),
          if (o.status == EmployeeStatus.fired)
            _smallBtn(
              icon: Icons.delete_forever,
              label: 'Удалить',
              color: AppColors.red,
              onTap: () => _deleteOperator(db, o),
            ),
        ]),
      ]),
    );
  }

  // ═══════════ operators CRUD ═══════════

  Future<void> _openOperatorDialog(
      AppDatabase db, Employee admin, Employee? editing) async {
    final nameCtrl = TextEditingController(text: editing?.name ?? '');
    final phoneCtrl = TextEditingController(text: editing?.phone ?? '');
    final pinCtrl =
        TextEditingController(text: editing == null ? '0000' : editing.pin);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: Text(editing == null
            ? 'Новый оператор'
            : 'Оператор — редактирование'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                    labelText: 'ФИО *', hintText: 'Иванов Иван')),
            const SizedBox(height: 12),
            TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                    labelText: 'Телефон', hintText: '+7 900 000-00-00')),
            const SizedBox(height: 12),
            TextField(
                controller: pinCtrl,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                    labelText: 'PIN (4–6 цифр)', counterText: '')),
            if (editing == null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Оператор будет автоматически привязан к парку «${db.parkById(admin.parkId)?.name ?? "—"}»',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.dim),
                ),
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
            child: Text(editing == null ? 'Создать' : 'Сохранить'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final name = nameCtrl.text.trim();
    final phone = phoneCtrl.text.trim();
    final pin = pinCtrl.text.trim();
    if (name.isEmpty) {
      if (!mounted) return;
      _snack('Укажите ФИО');
      return;
    }
    if (pin.length < 4 || pin.length > 6 || int.tryParse(pin) == null) {
      if (!mounted) return;
      _snack('PIN: 4–6 цифр');
      return;
    }
    if (editing == null &&
        db.employees.any((e) =>
            e.status == EmployeeStatus.active && e.pin == pin)) {
      if (!mounted) return;
      _snack('PIN уже используется');
      return;
    }

    if (editing == null) {
      final op = Employee(
        id: _uid(),
        name: name,
        phone: phone,
        pin: pin,
        role: EmployeeRole.operator,
      );
      db.employees.add(op);
      if (admin.parkId != null) {
        db.createLinkRequest(op.id, admin.parkId!,
            initiatorAdminId: admin.id, note: 'Принят на работу');
        final link = db
            .linksForOperator(op.id)
            .firstWhere((l) => l.parkId == admin.parkId);
        db.approveLink(link.id, admin.id);
      }
    } else {
      editing.name = name;
      editing.phone = phone;
      editing.pin = pin;
    }
    await db.save();
    if (!mounted) return;
    _snack(editing == null ? 'Оператор создан' : 'Сохранено');
  }

  Future<void> _changePin(AppDatabase db, Employee o) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: Text('Сменить PIN · ${o.name}'),
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
      if (!mounted) return;
      _snack('PIN: 4–6 цифр');
      return;
    }
    o.pin = pin;
    await db.save();
    if (!mounted) return;
    _snack('PIN изменён');
  }

  Future<void> _changeStatus(AppDatabase db, Employee o) async {
    EmployeeStatus sel = o.status;
    final noteCtrl = TextEditingController(text: o.statusNote ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: AppColors.panel,
          title: Text('Статус · ${o.name}'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (final s in EmployeeStatus.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: InkWell(
                    onTap: () => setS(() => sel = s),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
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
                        const SizedBox(width: 10),
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
                const SizedBox(height: 8),
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
    o.status = sel;
    o.statusChangedAt = DateTime.now();
    o.statusNote = sel == EmployeeStatus.active
        ? null
        : (noteCtrl.text.trim().isEmpty
            ? null
            : noteCtrl.text.trim());
    await db.save();
    if (!mounted) return;
    _snack('Статус изменён');
  }

  Future<void> _deleteOperator(AppDatabase db, Employee o) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: const Text('Удалить оператора?'),
        content: Text('«${o.name}» будет удалён навсегда.',
            style:
                const TextStyle(fontSize: 13, color: AppColors.mut)),
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
    db.employees.removeWhere((x) => x.id == o.id);
    db.operatorLinks.removeWhere((l) => l.operatorId == o.id);
    await db.save();
    if (!mounted) return;
    _snack('Оператор удалён');
  }

  Future<void> _addParkLink(
      AppDatabase db, Employee admin, Employee o) async {
    final myParks = db
        .linksForOperator(o.id)
        .where((l) => l.status == LinkStatus.approved)
        .map((l) => l.parkId)
        .toSet();
    final available =
        db.parks.where((p) => !myParks.contains(p.id)).toList();
    if (available.isEmpty) {
      _snack('Оператор уже привязан ко всем паркам');
      return;
    }
    String? selParkId = available.first.id;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: AppColors.panel,
          title: Text('Привязать · ${o.name}'),
          content: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text(
              'Заявка уйдёт администратору парка — он должен подтвердить.',
              style: TextStyle(fontSize: 12, color: AppColors.dim),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: selParkId,
              decoration: const InputDecoration(labelText: 'Парк'),
              isExpanded: true,
              items: [
                for (final p in available)
                  DropdownMenuItem(
                      value: p.id,
                      child: Text(
                          '${p.name} · ${db.cityOfPark(p)}',
                          overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) => setS(() => selParkId = v),
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
              child: const Text('Отправить'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || selParkId == null) return;
    db.createLinkRequest(o.id, selParkId!,
        initiatorAdminId: admin.id, note: 'Запрос от ${admin.name}');
    if (!mounted) return;
    _snack('Заявка отправлена администратору парка');
  }

  // ═══════════ NFC ═══════════

  Future<void> _bindBadge(AppDatabase db, Employee o) async {
    _snack('Приложите бейдж к терминалу…');
    String? uid;
    try {
      uid = await NfcHelper.scanBadge();
    } catch (e) {
      if (!mounted) return;
      _snack('Ошибка NFC: $e');
      return;
    }
    if (uid == null || uid.isEmpty) {
      if (!mounted) return;
      _snack('Бейдж не распознан');
      return;
    }
    final existing = db.employeeByBadge(uid);
    if (existing != null && existing.id != o.id) {
      if (!mounted) return;
      _snack('Этот бейдж уже привязан к: ${existing.name}');
      return;
    }
    o.badgeId = uid;
    await db.save();
    DebugLog.instance.info('badge bound: ${o.name} → $uid');
    if (!mounted) return;
    _snack('Бейдж привязан');
  }

  Future<void> _unbindBadge(AppDatabase db, Employee o) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: const Text('Отвязать бейдж?'),
        content: Text('«${o.name}» больше не сможет входить по бейджу.',
            style:
                const TextStyle(fontSize: 13, color: AppColors.mut)),
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
    o.badgeId = null;
    await db.save();
    if (!mounted) return;
    _snack('Бейдж отвязан');
  }

  // ═══════════ helpers ═══════════

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1))
        .toUpperCase();
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
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
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

  Widget _smallBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.line2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: color ?? AppColors.mut),
          const SizedBox(width: 6),
          Text(label,
              style:
                  TextStyle(fontSize: 12, color: color ?? AppColors.mut)),
        ]),
      ),
    );
  }

  Widget _chip(String label, bool active, VoidCallback onTap,
      {Color? color}) {
    final c = color ?? AppColors.amb;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: active ? c.withValues(alpha: 0.1) : AppColors.panel2,
          border: Border.all(
              color:
                  active ? c.withValues(alpha: 0.4) : AppColors.line2),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: active ? c : AppColors.mut)),
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
