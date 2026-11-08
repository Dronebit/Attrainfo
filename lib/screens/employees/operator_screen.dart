import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../data/app_database.dart';
import '../models/enums.dart';
import '../models/models.dart';
import '../models/shift.dart';
import '../theme.dart';

class OperatorScreen extends StatelessWidget {
  const OperatorScreen({super.key});
  static const _opName = 'Алексей Смирнов';

  @override
  Widget build(BuildContext context) {
    final db = context.watch<AppDatabase>();
    if (db.activeShift == null) return _Welcome(db: db);
    if (db.opSelectingRides) return _RideSelect(db: db);
    return _ActiveShift(db: db);
  }
}

// =====================================================================
// 1. ЭКРАН ПРИВЕТСТВИЯ
// =====================================================================
class _Welcome extends StatefulWidget {
  final AppDatabase db;
  const _Welcome({required this.db});
  @override
  State<_Welcome> createState() => _WelcomeState();
}

class _WelcomeState extends State<_Welcome> {
  String? _parkId;

  @override
  void initState() {
    super.initState();
    _parkId = widget.db.currentParkId ??
        (widget.db.parks.isNotEmpty ? widget.db.parks.first.id : null);
  }

  @override
  Widget build(BuildContext context) {
    final parks = widget.db.parks;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: _cardDeco,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(OperatorScreen._opName,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              const Text('👋', textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 42)),
              const SizedBox(height: 14),
              const Text('Добро пожаловать',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              const Text('Выберите парк и нажмите «Начать смену»',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.mut, fontSize: 13)),
              const SizedBox(height: 22),
              DropdownButtonFormField<String>(
                initialValue: _parkId,
                decoration: const InputDecoration(labelText: 'Парк'),
                isExpanded: true,
                items: [
                  for (final p in parks)
                    DropdownMenuItem(value: p.id, child: Text(p.name)),
                ],
                onChanged: (v) => setState(() => _parkId = v),
              ),
              const SizedBox(height: 18),
              InkWell(
                onTap: () {
                  if (_parkId == null) {
                    _snack(context, 'Выберите парк');
                    return;
                  }
                  widget.db.startShift(_parkId!);
                  _snack(context, 'Смена начата');
                },
                borderRadius: BorderRadius.circular(11),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [AppColors.amb, Color(0xFFFF9A3D)]),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check,
                          size: 18, color: Color(0xFF1C1204)),
                      SizedBox(width: 8),
                      Text('Начать смену',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1C1204))),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// 2. ВЫБОР АТТРАКЦИОНОВ
// =====================================================================
class _RideSelect extends StatefulWidget {
  final AppDatabase db;
  const _RideSelect({required this.db});
  @override
  State<_RideSelect> createState() => _RideSelectState();
}

class _RideSelectState extends State<_RideSelect> {
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set<String>.from(widget.db.activeShift?.rideIds ?? []);
  }

  void _toggle(String id) {
    if (_selected.contains(id)) {
      setState(() => _selected.remove(id));
    } else {
      if (_selected.length >= 5) {
        _snack(context, 'Максимум 5 аттракционов');
        return;
      }
      setState(() => _selected.add(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final shift = widget.db.activeShift;
    if (shift == null) return const SizedBox.shrink();
    final rides = widget.db.rides
        .where((r) => r.parkId == shift.parkId && r.status != RideStatus.retired)
        .toList();
    final count = _selected.length;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: _cardDeco,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Аттракционы парка',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text('Выбрано: $count',
                            style: const TextStyle(
                                fontSize: 11.5, color: AppColors.dim)),
                      ],
                    ),
                  ),
                  if (_selected.isNotEmpty)
                    TextButton(
                      onPressed: () =>
                          widget.db.setOpSelectingRides(false),
                      child: const Text('Отмена'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (rides.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 26),
                  child: Center(
                      child: Text('Нет доступных аттракционов',
                          style: TextStyle(color: AppColors.dim))),
                )
              else
                ...rides.map((r) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _RideTile(
                        ride: r,
                        selected: _selected.contains(r.id),
                        onTap: () => _toggle(r.id),
                      ),
                    )),
              const SizedBox(height: 10),
              InkWell(
                onTap: count == 0
                    ? null
                    : () {
                        widget.db.setShiftRides(_selected.toList());
                        widget.db.setOpSelectingRides(false);
                        _snack(context, 'Аттракционы сохранены');
                      },
                borderRadius: BorderRadius.circular(11),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    gradient: count == 0
                        ? null
                        : const LinearGradient(
                            colors: [AppColors.amb, Color(0xFFFF9A3D)]),
                    color: count == 0 ? AppColors.panel2 : null,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check,
                          size: 16,
                          color: count == 0
                              ? AppColors.dim
                              : const Color(0xFF1C1204)),
                      const SizedBox(width: 8),
                      Text('Подтвердить ($count)',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: count == 0
                                  ? AppColors.dim
                                  : const Color(0xFF1C1204))),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RideTile extends StatelessWidget {
  final Ride ride;
  final bool selected;
  final VoidCallback onTap;
  const _RideTile(
      {required this.ride, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.amb.withValues(alpha: 0.08)
              : const Color(0xFF0E1420),
          border: Border.all(
            color: selected ? AppColors.amb.withValues(alpha: 0.4) : AppColors.line2,
          ),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                border: Border.all(
                  color: selected ? AppColors.amb : AppColors.line2,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(6),
                color: selected ? AppColors.amb : Colors.transparent,
              ),
              child: selected
                  ? const Icon(Icons.check, size: 14, color: Color(0xFF1C1204))
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ride.name,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _badge(ride.status.label, ride.status.color),
                      const SizedBox(width: 6),
                      Text('${ride.year ?? '—'}',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.dim)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// 3. АКТИВНАЯ СМЕНА
// =====================================================================
class _ActiveShift extends StatelessWidget {
  final AppDatabase db;
  const _ActiveShift({required this.db});

  @override
  Widget build(BuildContext context) {
    final shift = db.activeShift;
    if (shift == null) return const SizedBox.shrink();
    final park = db.parkById(shift.parkId);
    final rides = shift.rideIds
        .map((id) => db.rideById(id))
        .whereType<Ride>()
        .toList();
    final started = DateFormat('HH:mm').format(shift.startedAt);
    final durStr = _durShort(DateTime.now().difference(shift.startedAt));

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- header ---
            Container(
              padding: const EdgeInsets.all(16),
              decoration: _cardDeco,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('ТЕКУЩАЯ СМЕНА',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppColors.dim,
                                letterSpacing: 0.6,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text(park?.name ?? '—',
                            style: const TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text('Начало: $started · Идёт $durStr',
                            style: const TextStyle(
                                fontSize: 11.5, color: AppColors.dim)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (shift.isRelief) ...[
                        _badge('Подменный', AppColors.pur),
                        const SizedBox(height: 6),
                      ],
                      TextButton(
                        onPressed: () => _confirmEndShift(context),
                        child: const Text('Завершить смену',
                            style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // --- current rides ---
            Container(
              padding: const EdgeInsets.all(18),
              decoration: _cardDeco,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Я сейчас стою на',
                            style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700)),
                      ),
                      TextButton.icon(
                        onPressed: () => db.setOpSelectingRides(true),
                        icon: const Icon(Icons.edit, size: 14),
                        label: const Text('Изменить',
                            style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (rides.isEmpty)
                    const Text('Аттракционы не выбраны',
                        style: TextStyle(color: AppColors.mut, fontSize: 12))
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final r in rides)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: AppColors.panel2,
                              border: Border.all(color: AppColors.line2),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: r.status.color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(r.name,
                                    style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // --- big buttons ---
            Container(
              padding: const EdgeInsets.all(20),
              decoration: _cardDeco,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InkWell(
                    onTap: () => _openReportDialog(context, db, shift),
                    borderRadius: BorderRadius.circular(11),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [AppColors.amb, Color(0xFFFF9A3D)]),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              size: 20, color: Color(0xFF1C1204)),
                          SizedBox(width: 10),
                          Text('Сообщить о проблеме',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1C1204))),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _outlineBtn(
                          label: shift.isRelief
                              ? 'Выйти из подмены'
                              : 'Режим подмены',
                          onTap: () {
                            db.toggleRelief();
                            _snack(
                                context,
                                shift.isRelief
                                    ? 'Режим подмены выключен'
                                    : 'Режим подмены включён');
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _outlineBtn(
                          label: 'Мои сообщения',
                          onTap: () {
                            // нужен переход на incidents — см. примечание ниже
                            _snack(context, 'Откройте вкладку «События»');
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // --- all park rides ---
            Container(
              padding: const EdgeInsets.all(18),
              decoration: _cardDeco,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Аттракционы парка',
                      style: TextStyle(
                          fontSize: 14.5, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  ...db.rides
                      .where((r) => r.parkId == shift.parkId)
                      .map((r) => _statusRow(r, shift)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusRow(Ride r, Shift shift) {
    final mine = shift.rideIds.contains(r.id);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF1C2739))),
      ),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
                color: r.status.color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(r.name,
                style: const TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis),
          ),
          if (mine)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.amb.withValues(alpha: 0.1),
                  border: Border.all(
                      color: AppColors.amb.withValues(alpha: 0.4)),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: const Text('я здесь',
                    style: TextStyle(
                        fontSize: 10.5,
                        color: AppColors.amb2,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          _badge(r.status.label, r.status.color),
        ],
      ),
    );
  }

  Widget _outlineBtn({required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.panel2,
          border: Border.all(color: AppColors.line2),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12.5)),
      ),
    );
  }

  Future<void> _confirmEndShift(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: const Text('Завершить смену?'),
        content: const Text('Текущая смена будет закрыта.',
            style: TextStyle(fontSize: 13, color: AppColors.mut)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.amb,
                foregroundColor: const Color(0xFF1C1204)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Завершить'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    db.endShift();
    if (!context.mounted) return;
    _snack(context, 'Смена завершена');
  }

  Future<void> _openReportDialog(
      BuildContext context, AppDatabase db, Shift shift) async {
    final parkRides = db.rides.where((r) => r.parkId == shift.parkId).toList();
    if (parkRides.isEmpty) {
      _snack(context, 'В парке нет аттракционов');
      return;
    }
    final shiftRides = shift.rideIds
        .map((id) => db.rideById(id))
        .whereType<Ride>()
        .toList();
    String? rideId = shiftRides.isNotEmpty
        ? shiftRides.first.id
        : parkRides.first.id;
    IncidentType type = IncidentType.breakdown;
    Severity sev = Severity.major;
    String? techId;
    final descCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: AppColors.panel,
          title: const Text('Сообщить о проблеме'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: rideId,
                    decoration: const InputDecoration(labelText: 'Аттракцион'),
                    isExpanded: true,
                    items: [
                      for (final r in parkRides)
                        DropdownMenuItem(
                            value: r.id, child: Text(r.name)),
                    ],
                    onChanged: (v) => setS(() => rideId = v),
                  ),
                  const SizedBox(height: 14),
                  const Text('Тип события',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.mut)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final t in IncidentType.values)
                      _chip(
                        label: t.label,
                        active: type == t,
                        color: t.color,
                        onTap: () => setS(() => type = t),
                      ),
                  ]),
                  const SizedBox(height: 14),
                  const Text('Степень важности',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.mut)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final s in Severity.values)
                      _chip(
                        label: s.label,
                        active: sev == s,
                        color: s.color,
                        onTap: () => setS(() => sev = s),
                      ),
                  ]),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: techId ?? '',
                    decoration:
                        const InputDecoration(labelText: 'Обнаружил'),
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem(
                          value: '', child: Text('— не назначен —')),
                      for (final t in db.technicians)
                        DropdownMenuItem(
                          value: t.id,
                          child: Text('${t.name} · ${t.role}',
                              overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (v) => setS(
                        () => techId = (v == null || v.isEmpty) ? null : v),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Описание проблемы *',
                      hintText: 'Что обнаружено, при каких обстоятельствах…',
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Отмена')),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.amb,
                foregroundColor: const Color(0xFF1C1204),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Сообщить'),
            ),
          ],
        ),
      ),
    );

    if (ok != true) return;
    final desc = descCtrl.text.trim();
    if (rideId == null || desc.isEmpty) {
      if (!context.mounted) return;
      _snack(context, 'Заполните обязательные поля');
      return;
    }
    db.incidents.add(Incident(
      id: 'x${DateTime.now().microsecondsSinceEpoch}',
      rideId: rideId!,
      type: type,
      severity: sev,
      status: IncidentStatus.isNew,
      techId: techId,
      ts: DateTime.now(),
      desc: desc,
    ));
    await db.save();
    if (!context.mounted) return;
    _snack(context, 'Событие зарегистрировано');
  }
}

// =====================================================================
// ОБЩИЕ ХЕЛПЕРЫ
// =====================================================================
final _cardDeco = BoxDecoration(
  color: AppColors.panel,
  border: Border.all(color: AppColors.line),
  borderRadius: BorderRadius.circular(14),
);

Widget _badge(String text, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );

Widget _chip({
  required String label,
  required bool active,
  required Color color,
  required VoidCallback onTap,
}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(99),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(
        color: active ? color.withValues(alpha: 0.1) : AppColors.panel2,
        border: Border.all(
          color: active ? color.withValues(alpha: 0.4) : AppColors.line2,
        ),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: active ? color : AppColors.mut,
          )),
    ),
  );
}

String _durShort(Duration d) {
  if (d.inDays > 0) return '${d.inDays} д ${d.inHours % 24} ч';
  if (d.inHours > 0) return '${d.inHours} ч ${d.inMinutes % 60} м';
  return '${d.inMinutes} м';
}

void _snack(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
  );
}
