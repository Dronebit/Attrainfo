import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../data/app_database.dart';
import '../models/enums.dart';
import '../models/models.dart';
import '../theme.dart';

class IncidentsScreen extends StatefulWidget {
  const IncidentsScreen({super.key});
  @override
  State<IncidentsScreen> createState() => _IncidentsScreenState();
}

class _IncidentsScreenState extends State<IncidentsScreen> {
  IncidentType? _filterType;
  Severity? _filterSev;
  String? _filterParkId;
  String? _filterRideId;
  String _query = '';
  final _searchCtrl = TextEditingController();

  String _uid() => 'x${DateTime.now().microsecondsSinceEpoch}';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Incident> _applyFilters(AppDatabase db) {
    final q = _query.toLowerCase().trim();
    return db.incidents.where((i) {
      if (_filterType != null && i.type != _filterType) return false;
      if (_filterSev != null && i.severity != _filterSev) return false;
      if (_filterParkId != null) {
        final r = db.rideById(i.rideId);
        if (r == null || r.parkId != _filterParkId) return false;
      }
      if (_filterRideId != null && i.rideId != _filterRideId) return false;
      if (q.isNotEmpty) {
        final r = db.rideById(i.rideId);
        final tech = db.techById(i.techId);
        final hay = '${r?.name ?? ''} ${i.desc} ${i.type.label} '
                '${db.ridePath(i.rideId)} ${tech?.name ?? ''}'
            .toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => b.ts.compareTo(a.ts));
  }

  @override
  Widget build(BuildContext context) {
    final db = context.watch<AppDatabase>();
    final filtered = _applyFilters(db);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // ----- header row -----
      Row(children: [
        const Spacer(),
        _ghostBtn(
          icon: Icons.download_outlined,
          label: 'CSV',
          onTap: () => _exportCsv(db, filtered),
        ),
        const SizedBox(width: 8),
        _primaryBtn(
          icon: Icons.add,
          label: 'Событие',
          onTap: () => _openIncidentDialog(db, null),
        ),
      ]),
      const SizedBox(height: 14),

      // ----- filters -----
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.panel,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // type chips
          Wrap(spacing: 8, runSpacing: 8, children: [
            _chip(
              label: 'Все типы',
              active: _filterType == null,
              onTap: () => setState(() => _filterType = null),
            ),
            for (final t in IncidentType.values)
              _chip(
                label: t.label,
                icon: t.icon,
                color: t.color,
                active: _filterType == t,
                onTap: () => setState(() => _filterType = _filterType == t ? null : t),
              ),
          ]),
          const SizedBox(height: 12),
          // search + dropdowns
          TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Поиск по описанию, аттракциону, парку…',
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
          const SizedBox(height: 10),
          LayoutBuilder(builder: (c, box) {
            final cols = box.maxWidth > 720 ? 3 : 1;
            final w = (box.maxWidth - (cols - 1) * 10) / cols;
            return Wrap(spacing: 10, runSpacing: 10, children: [
              SizedBox(
                width: w,
                child: _dropdown<String>(
                  initialValue: _filterParkId,
                  label: 'Парк',
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Все парки')),
                    for (final p in db.parks)
                      DropdownMenuItem(
                        value: p.id,
                        child: Text('${p.name} (${db.cityOfPark(p)})',
                            overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) => setState(() {
                    _filterParkId = v;
                    _filterRideId = null;
                  }),
                ),
              ),
              SizedBox(
                width: w,
                child: _dropdown<String>(
                  initialValue: _filterRideId,
                  label: 'Аттракцион',
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Все аттракционы')),
                    for (final r in (_filterParkId == null
                        ? db.rides
                        : db.rides.where((r) => r.parkId == _filterParkId)))
                      DropdownMenuItem(
                        value: r.id,
                        child: Text(r.name, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) => setState(() => _filterRideId = v),
                ),
              ),
              SizedBox(
                width: w,
                child: _dropdown<Severity>(
                  initialValue: _filterSev,
                  label: 'Важность',
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Любая важность')),
                    for (final s in Severity.values)
                      DropdownMenuItem(value: s, child: Text(s.label)),
                  ],
                  onChanged: (v) => setState(() => _filterSev = v),
                ),
              ),
            ]);
          }),
        ]),
      ),
      const SizedBox(height: 14),

      // ----- list header -----
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(children: [
          const Text('Журнал событий',
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          _countBadge('Показано: ${filtered.length}'),
        ]),
      ),
      const SizedBox(height: 8),

      // ----- list -----
      if (filtered.isEmpty)
        _emptyState()
      else
        for (final i in filtered) _incidentCard(db, i),
    ]);
  }

  // ============ card ============

  Widget _incidentCard(AppDatabase db, Incident i) {
    final ride = db.rideById(i.rideId);
    final tech = db.techById(i.techId);
    final isResolved = i.status == IncidentStatus.resolved;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // top row: icon + name + time + status
        Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: i.type.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(i.type.icon, size: 17, color: i.type.color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(ride?.name ?? '—',
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis),
              Text(db.ridePath(i.rideId),
                  style: const TextStyle(fontSize: 11, color: AppColors.dim),
                  overflow: TextOverflow.ellipsis),
            ]),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(DateFormat('dd.MM.yyyy HH:mm').format(i.ts),
                style: const TextStyle(
                    fontSize: 11.5, color: AppColors.mut, fontFamily: 'monospace')),
            const SizedBox(height: 2),
            _badge(i.status.label, i.status.color),
          ]),
        ]),
        const SizedBox(height: 10),

        // type + severity badges
        Wrap(spacing: 6, runSpacing: 6, children: [
          _badge(i.type.label, i.type.color),
          _badge(i.severity.label, i.severity.color),
        ]),
        const SizedBox(height: 8),

        // description
        Text(i.desc,
            style: const TextStyle(fontSize: 13, color: AppColors.txt, height: 1.4)),
        if (tech != null) ...[
          const SizedBox(height: 6),
          Text('Обнаружил: ${tech.name}',
              style: const TextStyle(fontSize: 11.5, color: AppColors.dim)),
        ],

        const SizedBox(height: 10),
        // actions
        Row(children: [
          if (!isResolved)
            _actionBtn(
              icon: Icons.check,
              label: 'Устранено',
              color: AppColors.grn,
              onTap: () => _resolveIncident(db, i),
            ),
          const Spacer(),
          _iconBtn(icon: Icons.edit_outlined, onTap: () => _openIncidentDialog(db, i)),
          const SizedBox(width: 6),
          _iconBtn(
            icon: Icons.delete_outline,
            danger: true,
            onTap: () => _deleteIncident(db, i),
          ),
        ]),
      ]),
    );
  }

  Widget _emptyState() => Container(
        padding: const EdgeInsets.symmetric(vertical: 46, horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.panel,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Column(children: [
          Icon(Icons.check_circle_outline, size: 28, color: AppColors.dim),
          SizedBox(height: 10),
          Text('По выбранным фильтрам событий не найдено',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: AppColors.dim)),
        ]),
      );

  // ============ dialog: create / edit ============

  Future<void> _openIncidentDialog(AppDatabase db, Incident? editing) async {
    if (db.rides.isEmpty) {
      _snack('Сначала добавьте аттракцион в разделе «Инфраструктура»');
      return;
    }

    String? rideId = editing?.rideId;
    IncidentType type = editing?.type ?? IncidentType.breakdown;
    Severity sev = editing?.severity ?? Severity.major;
    IncidentStatus status = editing?.status ?? IncidentStatus.isNew;
    String? techId = editing?.techId;
    DateTime ts = editing?.ts ?? DateTime.now();
    final descCtrl = TextEditingController(text: editing?.desc ?? '');

    // build grouped ride items
    final rideItems = <DropdownMenuItem<String>>[];
    for (final p in db.parks) {
      final rides = db.rides.where((r) => r.parkId == p.id).toList();
      if (rides.isEmpty) continue;
      rideItems.add(DropdownMenuItem(
        enabled: false,
        value: '__h_${p.id}',
        child: Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 2),
          child: Text('${db.cityOfPark(p)} · ${p.name}',
              style: const TextStyle(fontSize: 11, color: AppColors.dim)),
        ),
      ));
      for (final r in rides) {
        rideItems.add(DropdownMenuItem(value: r.id, child: Text(r.name)));
      }
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: AppColors.panel,
          title: Text(editing == null
              ? 'Регистрация события'
              : 'Редактирование события'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ride
                    DropdownButtonFormField<String>(
                      initialValue: rideId,
                      decoration: const InputDecoration(labelText: 'Аттракцион *'),
                      isExpanded: true,
                      items: rideItems,
                      onChanged: (v) {
                        if (v != null && !v.startsWith('__h_')) {
                          setS(() => rideId = v);
                        }
                      },
                    ),
                    const SizedBox(height: 14),

                    // type chips
                    const Text('Тип события *',
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.mut)),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final t in IncidentType.values)
                        _chip(
                          label: t.label,
                          icon: t.icon,
                          color: t.color,
                          active: type == t,
                          onTap: () => setS(() => type = t),
                        ),
                    ]),
                    const SizedBox(height: 14),

                    // severity chips
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
                          color: s.color,
                          active: sev == s,
                          onTap: () => setS(() => sev = s),
                        ),
                    ]),
                    const SizedBox(height: 14),

                    // date + status
                    Row(children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await _pickDateTime(ctx, ts);
                            if (picked != null) {
                              setS(() => ts = picked);
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Дата и время *',
                              suffixIcon: Icon(Icons.calendar_today, size: 16),
                            ),
                            child: Text(DateFormat('dd.MM.yyyy HH:mm').format(ts),
                                style: const TextStyle(fontSize: 13)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<IncidentStatus>(
                          initialValue: status,
                          decoration: const InputDecoration(labelText: 'Статус'),
                          items: [
                            for (final st in IncidentStatus.values)
                              DropdownMenuItem(value: st, child: Text(st.label)),
                          ],
                          onChanged: (v) => setS(() => status = v ?? status),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 12),

                    // tech
                    DropdownButtonFormField<String>(
                      initialValue: techId ?? '',
                      decoration:
                          const InputDecoration(labelText: 'Обнаружил (сотрудник)'),
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

                    // description
                    TextField(
                      controller: descCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Описание неисправности *',
                        hintText:
                            'Что обнаружено, при каких обстоятельствах, характер проявления…',
                        alignLabelWithHint: true,
                      ),
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
                foregroundColor: const Color(0xFF1C1204),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(editing == null ? 'Создать' : 'Сохранить'),
            ),
          ],
        ),
      ),
    );

    if (result != true) return;

    final desc = descCtrl.text.trim();
    if (rideId == null || desc.isEmpty) {
      if (!mounted) return;
      _snack('Заполните обязательные поля');
      return;
    }
    final rid = rideId!;

    if (editing == null) {
      db.incidents.add(Incident(
        id: _uid(),
        rideId: rid,
        type: type,
        severity: sev,
        status: status,
        techId: techId,
        ts: ts,
        desc: desc,
        resolvedTs: status == IncidentStatus.resolved ? ts : null,
      ));
    } else {
      editing.rideId = rid;
      editing.type = type;
      editing.severity = sev;
      editing.status = status;
      editing.techId = techId;
      editing.ts = ts;
      editing.desc = desc;
      if (status == IncidentStatus.resolved) {
        editing.resolvedTs ??= ts;
      } else {
        editing.resolvedTs = null;
      }
    }
    await db.save();
    if (!mounted) return;
    _snack(editing == null ? 'Событие создано' : 'Событие обновлено');
  }

  // ============ actions ============

  Future<void> _resolveIncident(AppDatabase db, Incident i) async {
    i.status = IncidentStatus.resolved;
    i.resolvedTs = DateTime.now();
    await db.save();
    if (!mounted) return;
    _snack('Событие отмечено как устранённое');
  }

  Future<void> _deleteIncident(AppDatabase db, Incident i) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: const Text('Удалить событие?'),
        content: const Text('Запись будет удалена без возможности восстановления.',
            style: TextStyle(fontSize: 13, color: AppColors.mut)),
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
    db.incidents.removeWhere((x) => x.id == i.id);
    await db.save();
    if (!mounted) return;
    _snack('Событие удалено');
  }

  // ============ export csv ============

  Future<void> _exportCsv(AppDatabase db, List<Incident> list) async {
    final buf = StringBuffer();
    buf.writeln(
        'Дата;Город;Локация;Парк;Аттракцион;Тип;Важность;Описание;Статус;Обнаружил;Устранено');
    for (final i in list) {
      final r = db.rideById(i.rideId);
      final p = r == null ? null : db.parkById(r.parkId);
      final l = p == null ? null : db.locById(p.locId);
      final c = l == null ? null : db.cityById(l.cityId);
      final t = db.techById(i.techId);
      final row = [
        DateFormat('dd.MM.yyyy HH:mm').format(i.ts),
        c?.name ?? '',
        l?.name ?? '',
        p?.name ?? '',
        r?.name ?? '',
        i.type.label,
        i.severity.label,
        i.desc,
        i.status.label,
        t?.name ?? '',
        i.resolvedTs != null
            ? DateFormat('dd.MM.yyyy HH:mm').format(i.resolvedTs!)
            : '',
      ];
      buf.writeln(row.map((v) => '"${v.replaceAll('"', '""')}"').join(';'));
    }
    await Clipboard.setData(ClipboardData(text: buf.toString()));
    if (!mounted) return;
    _snack('CSV (${list.length} строк) скопирован в буфер обмена');
  }

  // ============ helpers ============

  Future<DateTime?> _pickDateTime(BuildContext context, DateTime initial) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) return null;
    if (!context.mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  Widget _chip({
    required String label,
    required bool active,
    required VoidCallback onTap,
    IconData? icon,
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
            color: active ? c.withValues(alpha: 0.4) : AppColors.line2,
          ),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: active ? c : AppColors.mut),
            const SizedBox(width: 6),
          ],
          Text(label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: active ? c : AppColors.mut,
              )),
        ]),
      ),
    );
  }

  Widget _dropdown<T>({
    required T? initialValue,
    required String label,
    required List<DropdownMenuItem<T?>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T?>(
      initialValue: initialValue,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: items,
      onChanged: onChanged,
    );
  }

  Widget _badge(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(text,
            style:
                TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      );

  Widget _countBadge(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.panel2,
          border: Border.all(color: AppColors.line2),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(text,
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.mut)),
      );

  Widget _iconBtn({
    required IconData icon,
    required VoidCallback onTap,
    bool danger = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.line2),
        ),
        child: Icon(icon, size: 15, color: AppColors.mut),
      ),
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          border: Border.all(color: color.withValues(alpha: 0.35)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ]),
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
          gradient: const LinearGradient(colors: [AppColors.amb, Color(0xFFFF9A3D)]),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: const Color(0xFF1C1204)),
          const SizedBox(width: 7),
          Text(label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1C1204),
              )),
        ]),
      ),
    );
  }

  Widget _ghostBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.line2),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: AppColors.mut),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.mut,
                  fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}