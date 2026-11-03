import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/app_database.dart';
import '../models/enums.dart';
import '../models/models.dart';
import '../theme.dart';

class InfrastructureScreen extends StatefulWidget {
  const InfrastructureScreen({super.key});
  @override
  State<InfrastructureScreen> createState() => _InfrastructureScreenState();
}

class _InfrastructureScreenState extends State<InfrastructureScreen> {
  String? _selCityId;
  String? _selLocId;
  String? _selParkId;

  String _uid() => 'x${DateTime.now().microsecondsSinceEpoch}';

  @override
  Widget build(BuildContext context) {
    final db = context.watch<AppDatabase>();

    final selCity = _selCityId == null ? null : db.cityById(_selCityId);
    final selLoc = _selLocId == null ? null : db.locById(_selLocId);
    final selPark = _selParkId == null ? null : db.parkById(_selParkId);

    final locs = selCity == null
        ? <ParkLocation>[]
        : db.locations.where((l) => l.cityId == selCity.id).toList();
    final parks = selLoc == null
        ? <Park>[]
        : db.parks.where((p) => p.locId == selLoc.id).toList();
    final rides = selPark == null
        ? <Ride>[]
        : db.rides.where((r) => r.parkId == selPark.id).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _section(
        title: 'Города',
        count: db.cities.length,
        enabled: true,
        onAdd: () => _openCityDialog(context, db, null),
        body: db.cities.isEmpty
            ? _empty(Icons.location_city_outlined, 'Добавьте первый город')
            : Column(children: [
                for (final c in db.cities)
                  _treeItem(
                    label: c.name,
                    count: db.locations.where((l) => l.cityId == c.id).length,
                    selected: selCity?.id == c.id,
                    onTap: () => setState(() {
                      if (_selCityId == c.id) {
                        _selCityId = null;
                        _selLocId = null;
                        _selParkId = null;
                      } else {
                        _selCityId = c.id;
                        _selLocId = null;
                        _selParkId = null;
                      }
                    }),
                    onEdit: () => _openCityDialog(context, db, c),
                    onDelete: () => _deleteCity(context, db, c),
                  ),
              ]),
      ),
      const SizedBox(height: 14),
      _section(
        title: 'Локации',
        count: locs.length,
        enabled: selCity != null,
        onAdd: selCity == null
            ? null
            : () => _openLocDialog(context, db, null, preselectedCityId: selCity.id),
        body: selCity == null
            ? _empty(Icons.chevron_right, 'Выберите город')
            : locs.isEmpty
                ? _empty(Icons.map_outlined, 'В городе пока нет локаций')
                : Column(children: [
                    for (final l in locs)
                      _treeItem(
                        label: l.name,
                        count: db.parks.where((p) => p.locId == l.id).length,
                        selected: selLoc?.id == l.id,
                        onTap: () => setState(() {
                          if (_selLocId == l.id) {
                            _selLocId = null;
                            _selParkId = null;
                          } else {
                            _selLocId = l.id;
                            _selParkId = null;
                          }
                        }),
                        onEdit: () => _openLocDialog(context, db, l,
                            preselectedCityId: selCity.id),
                        onDelete: () => _deleteLoc(context, db, l),
                      ),
                  ]),
      ),
      const SizedBox(height: 14),
      _section(
        title: 'Парки',
        count: parks.length,
        enabled: selLoc != null,
        onAdd: selLoc == null
            ? null
            : () => _openParkDialog(context, db, null, preselectedLocId: selLoc.id),
        body: selLoc == null
            ? _empty(Icons.chevron_right, 'Выберите локацию')
            : parks.isEmpty
                ? _empty(Icons.park_outlined, 'В локации пока нет парков')
                : Column(children: [
                    for (final p in parks)
                      _treeItem(
                        label: p.name,
                        count: db.rides.where((r) => r.parkId == p.id).length,
                        selected: selPark?.id == p.id,
                        onTap: () => setState(() {
                          _selParkId = _selParkId == p.id ? null : p.id;
                        }),
                        onEdit: () =>
                            _openParkDialog(context, db, p, preselectedLocId: selLoc.id),
                        onDelete: () => _deletePark(context, db, p),
                      ),
                  ]),
      ),
      const SizedBox(height: 14),
      _section(
        title: 'Аттракционы',
        count: rides.length,
        enabled: selPark != null,
        onAdd: selPark == null
            ? null
            : () => _openRideDialog(context, db, null, preselectedParkId: selPark.id),
        body: selPark == null
            ? _empty(Icons.chevron_right, 'Выберите парк')
            : rides.isEmpty
                ? _empty(Icons.attractions_outlined, 'В парке пока нет аттракционов')
                : Column(children: [
                    for (final r in rides) _rideCard(context, db, r),
                  ]),
      ),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.panel,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Row(children: [
          Icon(Icons.info_outline, size: 15, color: AppColors.dim),
          SizedBox(width: 9),
          Expanded(
            child: Text(
              'Иерархия: город → локация → парк → аттракцион. Удаление элемента приводит к удалению всех вложенных объектов и связанных записей.',
              style: TextStyle(fontSize: 12, color: AppColors.dim),
            ),
          ),
        ]),
      ),
    ]);
  }

  // ============ UI building blocks ============

  Widget _section({
    required String title,
    required int count,
    required bool enabled,
    required VoidCallback? onAdd,
    required Widget body,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: const BoxDecoration(
            color: Color(0x04FFFFFF),
            border: Border(bottom: BorderSide(color: AppColors.line)),
          ),
          child: Row(children: [
            Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            _count(count),
            const Spacer(),
            _iconBtn(
              icon: Icons.add,
              onTap: enabled && onAdd != null ? onAdd : null,
            ),
          ]),
        ),
        Padding(padding: const EdgeInsets.all(6), child: body),
      ]),
    );
  }

  Widget _treeItem({
    required String label,
    required int count,
    required bool selected,
    required VoidCallback onTap,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        margin: const EdgeInsets.only(bottom: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: selected ? AppColors.amb.withValues(alpha: 0.08) : Colors.transparent,
          border: Border.all(
            color: selected ? AppColors.amb.withValues(alpha: 0.22) : Colors.transparent,
          ),
        ),
        child: Row(children: [
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          _count(count),
          const SizedBox(width: 4),
          _iconBtn(icon: Icons.edit_outlined, onTap: onEdit, compact: true),
          _iconBtn(icon: Icons.delete_outline, onTap: onDelete, danger: true, compact: true),
        ]),
      ),
    );
  }

  Widget _rideCard(BuildContext context, AppDatabase db, Ride ride) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1420),
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(ride.name,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
          ),
          _badge(ride.status.label, ride.status.color),
        ]),
        const SizedBox(height: 4),
        Text(
          '${ride.type.label}${ride.year != null ? ' · с ${ride.year} г.' : ''}',
          style: const TextStyle(fontSize: 11.5, color: AppColors.dim),
        ),
        const SizedBox(height: 9),
        Wrap(spacing: 6, runSpacing: 6, children: [
          if (ride.status == RideStatus.active)
            _actionBtn(
              icon: Icons.timer_outlined,
              label: 'В простой',
              onTap: () => _openDowntimeMini(context, db, ride),
            ),
          if (ride.status == RideStatus.downtime)
            _actionBtn(
              icon: Icons.timer,
              label: 'Простой активен',
              disabled: true,
              onTap: () {},
            ),
          if (ride.status == RideStatus.retired)
            _actionBtn(
              icon: Icons.power_settings_new,
              label: 'Вернуть в работу',
              onTap: () => _reviveRide(context, db, ride),
            ),
          _iconBtn(icon: Icons.edit_outlined, compact: true,
              onTap: () => _openRideDialog(context, db, ride, preselectedParkId: ride.parkId)),
          _iconBtn(icon: Icons.delete_outline, danger: true, compact: true,
              onTap: () => _deleteRide(context, db, ride)),
        ]),
      ]),
    );
  }

  Widget _empty(IconData icon, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 14),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 22, color: AppColors.dim),
          const SizedBox(height: 8),
          Text(text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12.5, color: AppColors.dim)),
        ]),
      );

  Widget _count(int n) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
        decoration: BoxDecoration(
          color: AppColors.panel2,
          border: Border.all(color: AppColors.line2),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text('$n',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.mut)),
      );

  Widget _badge(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(text,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      );

  Widget _iconBtn({
    required IconData icon,
    VoidCallback? onTap,
    bool danger = false,
    bool compact = false,
  }) {
    final sz = compact ? 26.0 : 30.0;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        width: sz,
        height: sz,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: AppColors.line2),
        ),
        child: Icon(icon,
            size: compact ? 12 : 15,
            color: onTap == null
                ? AppColors.dim
                : danger
                    ? AppColors.mut
                    : AppColors.mut),
      ),
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool disabled = false,
  }) {
    return InkWell(
      onTap: disabled ? null : onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: disabled ? Colors.transparent : AppColors.panel2,
          border: Border.all(color: AppColors.line2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: disabled ? AppColors.dim : AppColors.txt),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(fontSize: 12, color: disabled ? AppColors.dim : AppColors.txt)),
        ]),
      ),
    );
  }

  // ============ Dialogs ============

  Future<bool> _confirm(
    BuildContext context,
    String title,
    String text, {
    bool danger = true,
  }) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: Text(title),
        content: Text(text, style: const TextStyle(fontSize: 13, color: AppColors.mut)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: danger ? AppColors.red : AppColors.amb,
              foregroundColor: danger ? Colors.white : const Color(0xFF1C1204),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(danger ? 'Удалить' : 'OK'),
          ),
        ],
      ),
    );
    return res == true;
  }

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _openCityDialog(BuildContext context, AppDatabase db, City? editing) async {
    final ctrl = TextEditingController(text: editing?.name ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: Text(editing == null ? 'Новый город' : 'Город — редактирование'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Название города',
            hintText: 'Например, Москва',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Сохранить')),
        ],
      ),
    );
    if (ok != true) return;
    final name = ctrl.text.trim();
    if (name.isEmpty) return;
    if (editing == null) {
      final newCity = City(id: _uid(), name: name);
      db.cities.add(newCity);
      if (mounted) setState(() => _selCityId = newCity.id);
    } else {
      editing.name = name;
    }
    await db.save();
    if (mounted) _snack(context, editing == null ? 'Город создан' : 'Изменения сохранены');
  }

  Future<void> _openLocDialog(
    BuildContext context,
    AppDatabase db,
    ParkLocation? editing, {
    String? preselectedCityId,
  }) async {
    String? cityId = editing?.cityId ?? preselectedCityId ?? (db.cities.isNotEmpty ? db.cities.first.id : null);
    final ctrl = TextEditingController(text: editing?.name ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: AppColors.panel,
          title: Text(editing == null ? 'Новая локация' : 'Локация — редактирование'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                value: cityId,
                decoration: const InputDecoration(labelText: 'Город'),
                items: [
                  for (final c in db.cities)
                    DropdownMenuItem(value: c.id, child: Text(c.name)),
                ],
                onChanged: (v) => setS(() => cityId = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Название локации',
                  hintText: 'Например, ВДНХ',
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Сохранить')),
          ],
        ),
      ),
    );
    if (ok != true || cityId == null) return;
    final name = ctrl.text.trim();
    if (name.isEmpty) return;
    if (editing == null) {
      final newLoc = ParkLocation(id: _uid(), cityId: cityId!, name: name);
      db.locations.add(newLoc);
      if (mounted) setState(() {
        _selCityId = cityId;
        _selLocId = newLoc.id;
        _selParkId = null;
      });
    } else {
      editing.name = name;
      editing.cityId = cityId!;
    }
    await db.save();
    if (mounted) _snack(context, editing == null ? 'Локация создана' : 'Изменения сохранены');
  }

  Future<void> _openParkDialog(
    BuildContext context,
    AppDatabase db,
    Park? editing, {
    String? preselectedLocId,
  }) async {
    String? locId = editing?.locId ?? preselectedLocId;
    final ctrl = TextEditingController(text: editing?.name ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: AppColors.panel,
          title: Text(editing == null ? 'Новый парк' : 'Парк — редактирование'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                value: locId,
                decoration: const InputDecoration(labelText: 'Локация'),
                isExpanded: true,
                items: [
                  for (final c in db.cities) ...[
                    for (final l in db.locations.where((l) => l.cityId == c.id))
                      DropdownMenuItem(
                        value: l.id,
                        child: Text('${c.name} · ${l.name}',
                            overflow: TextOverflow.ellipsis),
                      ),
                  ],
                ],
                onChanged: (v) => setS(() => locId = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Название парка',
                  hintText: 'Например, Парк Чудес',
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Сохранить')),
          ],
        ),
      ),
    );
    if (ok != true || locId == null) return;
    final name = ctrl.text.trim();
    if (name.isEmpty) return;
    if (editing == null) {
      final newPark = Park(id: _uid(), locId: locId!, name: name);
      db.parks.add(newPark);
      if (mounted) {
        final loc = db.locById(locId);
        setState(() {
          _selCityId = loc?.cityId;
          _selLocId = locId;
          _selParkId = newPark.id;
        });
      }
    } else {
      editing.name = name;
      editing.locId = locId!;
    }
    await db.save();
    if (mounted) _snack(context, editing == null ? 'Парк создан' : 'Изменения сохранены');
  }

  Future<void> _openRideDialog(
    BuildContext context,
    AppDatabase db,
    Ride? editing, {
    String? preselectedParkId,
  }) async {
    String? parkId = editing?.parkId ?? preselectedParkId;
    RideType type = editing?.type ?? RideType.other;
    final nameCtrl = TextEditingController(text: editing?.name ?? '');
    final yearCtrl = TextEditingController(text: editing?.year?.toString() ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: AppColors.panel,
          title: Text(editing == null ? 'Новый аттракцион' : 'Аттракцион — редактирование'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                value: parkId,
                decoration: const InputDecoration(labelText: 'Парк'),
                isExpanded: true,
                items: [
                  for (final p in db.parks)
                    DropdownMenuItem(
                      value: p.id,
                      child: Text('${p.name} · ${db.cityOfPark(p)}',
                          overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) => setS(() => parkId = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Название аттракциона',
                  hintText: 'Например, Колесо обозрения «Горизонт»',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<RideType>(
                value: type,
                decoration: const InputDecoration(labelText: 'Тип'),
                items: [
                  for (final t in RideType.values)
                    DropdownMenuItem(value: t, child: Text(t.label)),
                ],
                onChanged: (v) => setS(() => type = v ?? RideType.other),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: yearCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Год ввода в эксплуатацию',
                  hintText: '2024',
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Сохранить')),
          ],
        ),
      ),
    );
    if (ok != true || parkId == null) return;
    final name = nameCtrl.text.trim();
    if (name.isEmpty) return;
    final year = int.tryParse(yearCtrl.text.trim());
    if (editing == null) {
      final newRide = Ride(
        id: _uid(),
        parkId: parkId!,
        name: name,
        type: type,
        year: year,
        status: RideStatus.active,
      );
      db.rides.add(newRide);
      if (mounted) setState(() => _selParkId = parkId);
    } else {
      editing.name = name;
      editing.parkId = parkId!;
      editing.type = type;
      editing.year = year;
    }
    await db.save();
    if (mounted) _snack(context, editing == null ? 'Аттракцион создан' : 'Изменения сохранены');
  }

  Future<void> _openDowntimeMini(BuildContext context, AppDatabase db, Ride ride) async {
    DowntimeReason reason = DowntimeReason.diagnostics;
    String? techId;
    final commentCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: AppColors.panel,
          title: Text('Ввод в простой · ${ride.name}', style: const TextStyle(fontSize: 16)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('Причина простоя', style: TextStyle(fontSize: 12.5, color: AppColors.mut)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final r in [
                  DowntimeReason.diagnostics,
                  DowntimeReason.repair,
                  DowntimeReason.parts,
                ])
                  ChoiceChip(
                    label: Text(r.label),
                    selected: reason == r,
                    onSelected: (_) => setS(() => reason = r),
                    selectedColor: r.color.withValues(alpha: 0.22),
                    labelStyle: TextStyle(
                      color: reason == r ? r.color : AppColors.mut,
                      fontSize: 12,
                    ),
                    backgroundColor: AppColors.panel2,
                    side: BorderSide(
                      color: reason == r ? r.color.withValues(alpha: 0.4) : AppColors.line2,
                    ),
                  ),
              ]),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: techId ?? '',
                decoration: const InputDecoration(labelText: 'Сервисный сотрудник'),
                isExpanded: true,
                items: [
                  const DropdownMenuItem(value: '', child: Text('— не назначен —')),
                  for (final t in db.techs)
                    DropdownMenuItem(
                      value: t.id,
                      child: Text('${t.name} · ${t.role}', overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) => setS(() => techId = (v == null || v.isEmpty) ? null : v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: commentCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Комментарий',
                  hintText: 'Причина, характер работ…',
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.amb, foregroundColor: const Color(0xFF1C1204)),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Оформить'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    db.downtimes.add(Downtime(
      id: _uid(),
      rideId: ride.id,
      reason: reason,
      techId: techId,
      start: DateTime.now(),
      comment: commentCtrl.text.trim(),
    ));
    ride.status = RideStatus.downtime;
    await db.save();
    if (mounted) _snack(context, '«${ride.name}» переведён в простой');
  }

  Future<void> _reviveRide(BuildContext context, AppDatabase db, Ride ride) async {
    final ok = await _confirm(
      context,
      'Вернуть в эксплуатацию?',
      '«${ride.name}» снова получит статус «В работе».',
      danger: false,
    );
    if (!ok) return;
    ride.status = RideStatus.active;
    await db.save();
    if (mounted) _snack(context, '«${ride.name}» возвращён в работу');
  }

  // ============ Deletions ============

  Future<void> _deleteCity(BuildContext context, AppDatabase db, City city) async {
    final locIds = db.locations.where((l) => l.cityId == city.id).map((l) => l.id).toSet();
    final parkIds = db.parks.where((p) => locIds.contains(p.locId)).map((p) => p.id).toSet();
    final rideIds = db.rides.where((r) => parkIds.contains(r.parkId)).map((r) => r.id).toSet();
    final ok = await _confirm(
      context,
      'Удалить город?',
      'Будут удалены: локаций — ${locIds.length}, парков — ${parkIds.length}, '
          'аттракционов — ${rideIds.length}, а также связанные события и простои.',
    );
    if (!ok) return;
    db.incidents.removeWhere((i) => rideIds.contains(i.rideId));
    db.downtimes.removeWhere((d) => rideIds.contains(d.rideId));
    db.rides.removeWhere((r) => parkIds.contains(r.parkId));
    db.parks.removeWhere((p) => locIds.contains(p.locId));
    db.locations.removeWhere((l) => l.cityId == city.id);
    db.cities.remove(city);
    if (mounted) setState(() { _selCityId = null; _selLocId = null; _selParkId = null; });
    await db.save();
    if (mounted) _snack(context, 'Город и вложенные объекты удалены');
  }

  Future<void> _deleteLoc(BuildContext context, AppDatabase db, ParkLocation loc) async {
    final parkIds = db.parks.where((p) => p.locId == loc.id).map((p) => p.id).toSet();
    final rideIds = db.rides.where((r) => parkIds.contains(r.parkId)).map((r) => r.id).toSet();
    final ok = await _confirm(
      context,
      'Удалить локацию?',
      'Будут удалены: парков — ${parkIds.length}, аттракционов — ${rideIds.length}, '
          'а также связанные события и простои.',
    );
    if (!ok) return;
    db.incidents.removeWhere((i) => rideIds.contains(i.rideId));
    db.downtimes.removeWhere((d) => rideIds.contains(d.rideId));
    db.rides.removeWhere((r) => parkIds.contains(r.parkId));
    db.parks.removeWhere((p) => p.locId == loc.id);
    db.locations.remove(loc);
    if (mounted) setState(() { _selLocId = null; _selParkId = null; });
    await db.save();
    if (mounted) _snack(context, 'Локация удалена');
  }

  Future<void> _deletePark(BuildContext context, AppDatabase db, Park park) async {
    final rideIds = db.rides.where((r) => r.parkId == park.id).map((r) => r.id).toSet();
    final ok = await _confirm(
      context,
      'Удалить парк?',
      'Будут удалены аттракционы (${rideIds.length}) и связанные события и простои.',
    );
    if (!ok) return;
    db.incidents.removeWhere((i) => rideIds.contains(i.rideId));
    db.downtimes.removeWhere((d) => rideIds.contains(d.rideId));
    db.rides.removeWhere((r) => r.parkId == park.id);
    db.parks.remove(park);
    if (mounted) setState(() => _selParkId = null);
    await db.save();
    if (mounted) _snack(context, 'Парк удалён');
  }

  Future<void> _deleteRide(BuildContext context, AppDatabase db, Ride ride) async {
    final ni = db.incidents.where((i) => i.rideId == ride.id).length;
    final nd = db.downtimes.where((d) => d.rideId == ride.id).length;
    final ok = await _confirm(
      context,
      'Удалить аттракцион?',
      '«${ride.name}». Будут также удалены связанные записи: событий — $ni, простоев — $nd.',
    );
    if (!ok) return;
    db.incidents.removeWhere((i) => i.rideId == ride.id);
    db.downtimes.removeWhere((d) => d.rideId == ride.id);
    db.rides.remove(ride);
    await db.save();
    if (mounted) _snack(context, 'Аттракцион удалён');
  }
}