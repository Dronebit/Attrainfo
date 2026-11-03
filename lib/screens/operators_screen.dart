import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/app_database.dart';
import '../data/nfc_helper.dart';
import '../models/operator.dart';
import '../models/park_admin.dart';
import '../theme.dart';

class OperatorsScreen extends StatefulWidget {
  const OperatorsScreen({super.key});
  @override
  State<OperatorsScreen> createState() => _OperatorsScreenState();
}

class _OperatorsScreenState extends State<OperatorsScreen> {
  bool _unlocked = false;
  ParkAdmin? _currentAdmin;
  String _filter = 'all';
  String _query = '';
  final _searchCtrl = TextEditingController();

  String _uid() => 'x${DateTime.now().microsecondsSinceEpoch}';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Operator> _filtered(AppDatabase db) {
    final q = _query.toLowerCase().trim();
    return db.operators.where((o) {
      if (_filter == 'active' && o.status != OperatorStatus.active) return false;
      if (_filter == 'vacation' && o.status != OperatorStatus.vacation) {
        return false;
      }
      if (_filter == 'fired' && o.status != OperatorStatus.fired) return false;
      if (q.isNotEmpty) {
        final hay = '${o.name} ${o.phone}'.toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList()
      ..sort((a, b) {
        if (a.status.canWork != b.status.canWork) {
          return a.status.canWork ? -1 : 1;
        }
        return a.name.compareTo(b.name);
      });
  }

  @override
  Widget build(BuildContext context) {
    final db = context.watch<AppDatabase>();

    if (!_unlocked) {
      return _pinGate(db);
    }

    final list = _filtered(db);
    final working = db.operators.where((o) => o.status.canWork).length;
    final fired =
        db.operators.where((o) => o.status == OperatorStatus.fired).length;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(
          child: Text(
            '${_currentAdmin?.name ?? "Админ"} · операторов: ${db.operators.length} '
            '(работают: $working, уволены: $fired)',
            style: const TextStyle(fontSize: 11.5, color: AppColors.dim),
          ),
        ),
        TextButton.icon(
          onPressed: () => setState(() {
            _unlocked = false;
            _currentAdmin = null;
          }),
          icon: const Icon(Icons.logout, size: 14),
          label: const Text('Выйти', style: TextStyle(fontSize: 12)),
        ),
        const SizedBox(width: 8),
        _primaryBtn(
          icon: Icons.person_add,
          label: 'Оператор',
          onTap: () => _openOperatorDialog(db, null),
        ),
      ]),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: _cardDeco,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Wrap(spacing: 8, runSpacing: 8, children: [
            _chip(
                label: 'Все',
                active: _filter == 'all',
                onTap: () => setState(() => _filter = 'all')),
            _chip(
                label: 'Работают',
                active: _filter == 'active',
                color: const Color(0xFF34D399),
                onTap: () => setState(() => _filter = 'active')),
            _chip(
                label: 'Отпуск',
                active: _filter == 'vacation',
                color: const Color(0xFF60A5FA),
                onTap: () => setState(() => _filter = 'vacation')),
            _chip(
                label: 'Уволены',
                active: _filter == 'fired',
                color: const Color(0xFF94A3B8),
                onTap: () => setState(() => _filter = 'fired')),
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
                      },
                    ),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 12),
      if (list.isEmpty)
        Container(
          padding: const EdgeInsets.symmetric(vertical: 46),
          decoration: _cardDeco,
          child: const Center(
            child: Text('Операторов не найдено',
                style: TextStyle(color: AppColors.dim)),
          ),
        )
      else
        ...list.map((o) => _operatorCard(db, o)),
    ]);
  }

  // ─────────── PIN gate ───────────

  Widget _pinGate(AppDatabase db) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
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
            const Text('Введите PIN для доступа к управлению операторами',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: AppColors.mut)),
            const SizedBox(height: 18),
            const Text('Доступные администраторы:',
                style: TextStyle(fontSize: 11, color: AppColors.dim)),
            const SizedBox(height: 6),
            ...db.admins.where((a) => a.active).map((a) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(a.name, style: const TextStyle(fontSize: 12)),
                )),
            const SizedBox(height: 18),
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
          obscureText: true,
          maxLength: 6,
          decoration: const InputDecoration(labelText: 'PIN'),
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
    final admin = db.admins.firstWhere(
      (a) => a.active && a.pin == pin,
      orElse: () => ParkAdmin(id: '', name: '', pin: ''),
    );
    if (admin.id.isEmpty) {
      if (!mounted) return;
      _snack('Неверный PIN');
      return;
    }
    setState(() {
      _unlocked = true;
      _currentAdmin = admin;
    });
  }

  // ─────────── card ───────────

  Widget _operatorCard(AppDatabase db, Operator o) {
    final color = Color(o.status.colorValue);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: _cardDeco,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                    decoration:
                        BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
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
                if (o.phone.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(o.phone,
                      style:
                          const TextStyle(fontSize: 11, color: AppColors.dim)),
                ],
              ],
            ),
          ),
        ]),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: const Color(0xFF0E1420),
            border: Border.all(color: AppColors.line2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(children: [
            Icon(Icons.nfc,
                size: 16,
                color: o.badgeId != null ? AppColors.grn : AppColors.dim),
            const SizedBox(width: 8),
            Expanded(
              child: o.badgeId == null
                  ? const Text('Бейдж не привязан',
                      style: TextStyle(fontSize: 12, color: AppColors.dim))
                  : Text('Бейдж: ${o.badgeId}',
                      style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                          color: AppColors.txt)),
            ),
            if (o.badgeId == null)
              TextButton(
                onPressed: () => _bindBadge(db, o),
                child:
                    const Text('Привязать', style: TextStyle(fontSize: 12)),
              )
            else
              TextButton(
                onPressed: () => _unbindBadge(db, o),
                child: const Text('Отвязать',
                    style: TextStyle(fontSize: 12, color: AppColors.red)),
              ),
          ]),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 6, children: [
          _smallBtn(
            icon: Icons.edit_outlined,
            label: 'Изменить',
            onTap: () => _openOperatorDialog(db, o),
          ),
          _smallBtn(
            icon: Icons.key,
            label: 'Сменить PIN',
            onTap: () => _changePin(db, o),
          ),
          _smallBtn(
            icon: Icons.flag_outlined,
            label: 'Статус',
            onTap: () => _changeStatus(db, o),
          ),
          if (o.status == OperatorStatus.fired)
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

  // ─────────── NFC ───────────

  Future<void> _bindBadge(AppDatabase db, Operator o) async {
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
    final existing = db.operatorByBadge(uid);
    if (existing != null && existing.id != o.id) {
      if (!mounted) return;
      _snack('Этот бейдж уже привязан к: ${existing.name}');
      return;
    }
    o.badgeId = uid;
    await db.save();
    if (!mounted) return;
    _snack('Бейдж привязан');
  }

  Future<void> _unbindBadge(AppDatabase db, Operator o) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: const Text('Отвязать бейдж?'),
        content: Text('Оператор «${o.name}» больше не сможет входить по бейджу.',
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
    o.badgeId = null;
    await db.save();
    if (!mounted) return;
    _snack('Бейдж отвязан');
  }

  // ─────────── dialogs ───────────

  Future<void> _openOperatorDialog(AppDatabase db, Operator? editing) async {
    final nameCtrl = TextEditingController(text: editing?.name ?? '');
    final phoneCtrl = TextEditingController(text: editing?.phone ?? '');
    final pinCtrl =
        TextEditingController(text: editing == null ? '0000' : editing.pin);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panel,
        title:
            Text(editing == null ? 'Новый оператор' : 'Оператор — редактирование'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                  labelText: 'ФИО *', hintText: 'Иванов Иван'),
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

    if (editing == null) {
      db.operators.add(Operator(
        id: _uid(),
        name: name,
        phone: phone,
        pin: pin,
      ));
    } else {
      editing.name = name;
      editing.phone = phone;
      editing.pin = pin;
    }
    await db.save();
    if (!mounted) return;
    _snack(editing == null ? 'Оператор создан' : 'Сохранено');
  }

  Future<void> _changePin(AppDatabase db, Operator o) async {
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

  // Статус — кастомный выбор без deprecated RadioListTile
  Future<void> _changeStatus(AppDatabase db, Operator o) async {
    OperatorStatus sel = o.status;
    final noteCtrl = TextEditingController(text: o.statusNote ?? '');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: AppColors.panel,
          title: Text('Статус · ${o.name}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final s in OperatorStatus.values)
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
                                : AppColors.line2,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(children: [
                          Icon(
                            sel == s
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                            size: 18,
                            color: sel == s ? AppColors.amb : AppColors.dim,
                          ),
                          const SizedBox(width: 10),
                          Text(s.label,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: sel == s
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              )),
                        ]),
                      ),
                    ),
                  ),
                if (sel != OperatorStatus.active) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: noteCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Заметка',
                      hintText: 'например: отпуск до 15.11, причина',
                    ),
                  ),
                ],
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
              child: const Text('Применить'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    o.status = sel;
    o.statusChangedAt = DateTime.now();
    o.statusNote = sel == OperatorStatus.active
        ? null
        : (noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim());
    await db.save();
    if (!mounted) return;
    _snack('Статус изменён');
  }

  Future<void> _deleteOperator(AppDatabase db, Operator o) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: const Text('Удалить оператора?'),
        content: Text(
            '«${o.name}» будет удалён навсегда. '
            'Обычно достаточно статуса «Уволен».',
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
    db.operators.removeWhere((x) => x.id == o.id);
    await db.save();
    if (!mounted) return;
    _snack('Оператор удалён');
  }

  // ─────────── helpers ───────────

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.line2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: color ?? AppColors.mut),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(fontSize: 12, color: color ?? AppColors.mut)),
        ]),
      ),
    );
  }

  Widget _chip({
    required String label,
    required bool active,
    required VoidCallback onTap,
    Color? color,
  }) {
    final c = color ?? AppColors.amb;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: active ? c.withValues(alpha: 0.1) : AppColors.panel2,
          border: Border.all(
              color: active ? c.withValues(alpha: 0.4) : AppColors.line2),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: active ? c : AppColors.mut,
            )),
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