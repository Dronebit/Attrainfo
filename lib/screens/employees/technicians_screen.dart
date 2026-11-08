import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/app_database.dart';
import '../../models/employee.dart';
import '../../theme.dart';

class TechniciansScreen extends StatelessWidget {
  const TechniciansScreen({super.key});

  String _uid() => 'x${DateTime.now().microsecondsSinceEpoch}';

  @override
  Widget build(BuildContext context) {
    final db = context.watch<AppDatabase>();
    final techs = db.technicians
      ..sort((a, b) {
        if (a.canWork != b.canWork) return a.canWork ? -1 : 1;
        return a.name.compareTo(b.name);
      });

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(
          child: Text(
            'Механиков: ${techs.length} · в работе: ${techs.where((t) => t.canWork).length}',
            style: const TextStyle(fontSize: 11.5, color: AppColors.dim),
          ),
        ),
        _primaryBtn(
          icon: Icons.person_add,
          label: 'Механик',
          onTap: () => _openTechDialog(context, db, null),
        ),
      ]),
      const SizedBox(height: 14),

      if (techs.isEmpty)
        Container(
          padding: const EdgeInsets.symmetric(vertical: 46),
          decoration: _cardDeco,
          child: const Center(
            child: Text('Механиков нет',
                style: TextStyle(color: AppColors.dim)),
          ),
        )
      else
        ...techs.map((t) => _techCard(context, db, t)),
    ]);
  }

  Widget _techCard(
      BuildContext context, AppDatabase db, Employee t) {
    final activeDowntimes =
        db.downtimes.where((d) => d.techId == t.id && d.end == null).length;
    final doneDowntimes =
        db.downtimes.where((d) => d.techId == t.id && d.end != null).length;
    final foundIncidents =
        db.incidents.where((i) => i.techId == t.id).length;
    final color = Color(t.status.colorValue);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: _cardDeco,
      child:
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.panel2,
            child: Text(_initials(t.name),
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 15)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.name,
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
                    Text(t.status.label,
                        style: TextStyle(
                            fontSize: 11.5,
                            color: color,
                            fontWeight: FontWeight.w600)),
                    if (t.jobTitle != null &&
                        t.jobTitle!.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text('· ${t.jobTitle}',
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.dim),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ]),
                  if (t.phone.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(t.phone,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.dim)),
                  ],
                ]),
          ),
        ]),
        const SizedBox(height: 12),

        Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF0E1420),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(children: [
            Expanded(
              child: _stat(
                activeDowntimes.toString(),
                'в работе',
                AppColors.amb2,
              ),
            ),
            Container(
                width: 1,
                height: 24,
                color: AppColors.line2),
            Expanded(
              child: _stat(
                doneDowntimes.toString(),
                'завершено',
                AppColors.grn,
              ),
            ),
            Container(
                width: 1,
                height: 24,
                color: AppColors.line2),
            Expanded(
              child: _stat(
                foundIncidents.toString(),
                'обнаружил',
                AppColors.cyn,
              ),
            ),
          ]),
        ),
        const SizedBox(height: 10),

        Wrap(spacing: 6, runSpacing: 6, children: [
          _smallBtn(
            icon: Icons.edit_outlined,
            label: 'Изменить',
            onTap: () => _openTechDialog(context, db, t),
          ),
          _smallBtn(
            icon: Icons.key,
            label: 'PIN',
            onTap: () => _changePin(context, db, t),
          ),
          _smallBtn(
            icon: Icons.flag_outlined,
            label: 'Статус',
            onTap: () => _changeStatus(context, db, t),
          ),
          _smallBtn(
            icon: Icons.phone,
            label: 'Позвонить',
            color: AppColors.cyn,
            onTap: t.phone.isEmpty
                ? null
                : () => _showPhone(context, t),
          ),
          if (t.status == EmployeeStatus.fired)
            _smallBtn(
              icon: Icons.delete_forever,
              label: 'Удалить',
              color: AppColors.red,
              onTap: () => _deleteTech(context, db, t),
            ),
        ]),
      ]),
    );
  }

  Widget _stat(String value, String label, Color color) {
    return Column(children: [
      Text(value,
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color,
              fontFamily: 'monospace')),
      Text(label,
          style: const TextStyle(fontSize: 10.5, color: AppColors.dim)),
    ]);
  }

  // ═══════════ dialogs ═══════════

  Future<void> _openTechDialog(
      BuildContext context, AppDatabase db, Employee? editing) async {
    final nameCtrl = TextEditingController(text: editing?.name ?? '');
    final phoneCtrl = TextEditingController(text: editing?.phone ?? '');
    final jobCtrl = TextEditingController(text: editing?.jobTitle ?? '');
    final pinCtrl =
        TextEditingController(text: editing == null ? '0000' : editing.pin);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: Text(editing == null
            ? 'Новый механик'
            : 'Механик — редактирование'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                    labelText: 'ФИО *', hintText: 'Иванов Иван')),
            const SizedBox(height: 12),
            TextField(
                controller: jobCtrl,
                decoration: const InputDecoration(
                    labelText: 'Должность',
                    hintText: 'Старший механик, Электромеханик…')),
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
    final job = jobCtrl.text.trim();
    final pin = pinCtrl.text.trim();
    if (name.isEmpty) {
      if (!context.mounted) return;
      _snack(context, 'Укажите ФИО');
      return;
    }
    if (pin.length < 4 || pin.length > 6 || int.tryParse(pin) == null) {
      if (!context.mounted) return;
      _snack(context, 'PIN: 4–6 цифр');
      return;
    }
    if (editing == null &&
        db.employees.any((e) =>
            e.status == EmployeeStatus.active && e.pin == pin)) {
      if (!context.mounted) return;
      _snack(context, 'PIN уже используется');
      return;
    }

    if (editing == null) {
      db.employees.add(Employee(
        id: _uid(),
        name: name,
        phone: phone,
        pin: pin,
        jobTitle: job.isEmpty ? null : job,
        role: EmployeeRole.technician,
      ));
    } else {
      editing.name = name;
      editing.phone = phone;
      editing.jobTitle = job.isEmpty ? null : job;
      editing.pin = pin;
    }
    await db.save();
    if (!context.mounted) return;
    _snack(context, editing == null ? 'Механик создан' : 'Сохранено');
  }

  Future<void> _changePin(
      BuildContext context, AppDatabase db, Employee t) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: Text('Сменить PIN · ${t.name}'),
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
      if (!context.mounted) return;
      _snack(context, 'PIN: 4–6 цифр');
      return;
    }
    t.pin = pin;
    await db.save();
    if (!context.mounted) return;
    _snack(context, 'PIN изменён');
  }

  Future<void> _changeStatus(
      BuildContext context, AppDatabase db, Employee t) async {
    EmployeeStatus sel = t.status;
    final noteCtrl = TextEditingController(text: t.statusNote ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: AppColors.panel,
          title: Text('Статус · ${t.name}'),
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
    t.status = sel;
    t.statusChangedAt = DateTime.now();
    t.statusNote = sel == EmployeeStatus.active
        ? null
        : (noteCtrl.text.trim().isEmpty
            ? null
            : noteCtrl.text.trim());
    await db.save();
    if (!context.mounted) return;
    _snack(context, 'Статус изменён');
  }

  Future<void> _deleteTech(
      BuildContext context, AppDatabase db, Employee t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: const Text('Удалить механика?'),
        content: Text(
            '«${t.name}» будет удалён навсегда. Записи простоев и инцидентов сохранятся с пометкой.',
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
    db.employees.removeWhere((x) => x.id == t.id);
    await db.save();
    if (!context.mounted) return;
    _snack(context, 'Механик удалён');
  }

  void _showPhone(BuildContext context, Employee t) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: Text(t.name),
        content: SelectableText(t.phone,
            style: const TextStyle(
                fontSize: 18,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Закрыть')),
        ],
      ),
    );
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
    required VoidCallback? onTap,
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

  void _snack(BuildContext context, String msg) {
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
