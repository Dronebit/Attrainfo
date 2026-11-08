import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/app_database.dart';
import '../../models/inventory.dart';
import '../../theme.dart';

// ═══════════════════════════════════════════════════════════════════
// КОРНЕВОЙ ЭКРАН — 3 вкладки
// ═══════════════════════════════════════════════════════════════════

class WarehouseScreen extends StatefulWidget {
  const WarehouseScreen({super.key});
  @override
  State<WarehouseScreen> createState() => _WarehouseScreenState();
}

class _WarehouseScreenState extends State<WarehouseScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: AppColors.panel,
          child: TabBar(
            controller: _tab,
            indicatorColor: AppColors.amb,
            labelColor: AppColors.amb2,
            unselectedLabelColor: AppColors.mut,
            labelStyle:
                const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            tabs: const [
              Tab(text: 'Позиции'),
              Tab(text: 'Локации'),
              Tab(text: 'Операции'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: const [
              _ItemsTab(),
              _LocationsTab(),
              _TransactionsTab(),
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// ВКЛАДКА 1 — ПОЗИЦИИ
// ═══════════════════════════════════════════════════════════════════

class _ItemsTab extends StatefulWidget {
  const _ItemsTab();
  @override
  State<_ItemsTab> createState() => _ItemsTabState();
}

class _ItemsTabState extends State<_ItemsTab> {
  String _query = '';
  InventoryCategory? _filterCategory;
  bool _onlyBelowMin = false;
  final _searchCtrl = TextEditingController();

  String _uid() => 'x${DateTime.now().microsecondsSinceEpoch}';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<InventoryItem> _filtered(AppDatabase db) {
    final q = _query.toLowerCase().trim();
    return db.inventoryItems.where((it) {
      if (_filterCategory != null && it.category != _filterCategory) {
        return false;
      }
      if (_onlyBelowMin && !db.isBelowMin(it.id)) return false;
      if (q.isNotEmpty) {
        final hay = '${it.name} ${it.sku}'.toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  @override
  Widget build(BuildContext context) {
    final db = context.watch<AppDatabase>();
    final filtered = _filtered(db);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _kpiRow(db),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: Text('Найдено: ${filtered.length}',
                style:
                    const TextStyle(fontSize: 11, color: AppColors.dim)),
          ),
          if (_hasActiveFilters)
            TextButton(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 30),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () => setState(() {
                _filterCategory = null;
                _onlyBelowMin = false;
                _query = '';
                _searchCtrl.clear();
              }),
              child: const Text('Сбросить',
                  style: TextStyle(fontSize: 11.5)),
            ),
          const SizedBox(width: 8),
          _primaryBtn(
            icon: Icons.add,
            label: 'Позиция',
            onTap: () => _openItemDialog(db, null),
          ),
        ]),
        const SizedBox(height: 12),
        _filtersCard(),
        const SizedBox(height: 12),
        if (db.inventoryItems.isEmpty)
          _emptyState(
            icon: Icons.inventory_2_outlined,
            title: 'Склад пуст',
            subtitle: 'Создайте первую позицию',
            action: _primaryBtn(
              icon: Icons.add,
              label: 'Создать',
              onTap: () => _openItemDialog(db, null),
            ),
          )
        else if (filtered.isEmpty)
          _emptyState(
            icon: Icons.search_off,
            title: 'Ничего не найдено',
            subtitle: 'Измените фильтры или запрос',
          )
        else
          for (final it in filtered) _itemRow(db, it),
      ]),
    );
  }

  Widget _kpiRow(AppDatabase db) {
    final total = db.inventoryItems.length;
    final below = db.belowMinCount;
    final value = db.totalStockValue;

    return LayoutBuilder(builder: (c, box) {
      final cols = box.maxWidth > 900 ? 3 : box.maxWidth > 500 ? 2 : 1;
      final w = (box.maxWidth - (cols - 1) * 12) / cols;
      return Wrap(spacing: 12, runSpacing: 12, children: [
        SizedBox(
          width: w,
          child: _Kpi(
            label: 'Позиций',
            value: '$total',
            sub: 'в справочнике',
            icon: Icons.inventory_2_outlined,
            color: AppColors.blu,
          ),
        ),
        SizedBox(
          width: w,
          child: _Kpi(
            label: 'Ниже минимума',
            value: '$below',
            sub: below > 0 ? 'требуют закупки' : 'всё в норме',
            icon: Icons.warning_amber_rounded,
            color: below > 0 ? AppColors.red : AppColors.grn,
          ),
        ),
        SizedBox(
          width: w,
          child: _Kpi(
            label: 'Стоимость остатков',
            value: value == 0
                ? '—'
                : '${(value / 1000).toStringAsFixed(1)}К ₽',
            sub: 'по цене справочника',
            icon: Icons.payments_outlined,
            color: AppColors.amb,
          ),
        ),
      ]);
    });
  }

  Widget _filtersCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _cardDeco,
      child:
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(spacing: 6, runSpacing: 6, children: [
          _chip('Все', _filterCategory == null,
              () => setState(() => _filterCategory = null)),
          for (final c in InventoryCategory.values)
            _chip(c.label, _filterCategory == c,
                () => setState(() => _filterCategory = c)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Поиск по SKU или названию…',
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                prefixIcon: const Icon(Icons.search, size: 16),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 14),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('⚠ Ниже минимума',
                style: TextStyle(fontSize: 11.5)),
            selected: _onlyBelowMin,
            onSelected: (v) => setState(() => _onlyBelowMin = v),
            backgroundColor: AppColors.panel2,
            selectedColor: AppColors.red.withValues(alpha: 0.15),
            side: BorderSide(
                color: _onlyBelowMin ? AppColors.red : AppColors.line2),
            labelStyle: TextStyle(
              fontSize: 11.5,
              color: _onlyBelowMin ? AppColors.red : AppColors.mut,
              fontWeight: FontWeight.w600,
            ),
          ),
        ]),
      ]),
    );
  }

  bool get _hasActiveFilters =>
      _filterCategory != null || _onlyBelowMin || _query.isNotEmpty;

  Widget _itemRow(AppDatabase db, InventoryItem it) {
    final total = db.stockTotal(it.id);
    final belowMin = total < it.minQuantity;
    final locations = db.stockByLocation(it.id);
    final locNames = locations.entries
        .map((e) {
          final loc = db.locationById(e.key);
          return '${loc?.code ?? "—"} (${_num(e.value)})';
        })
        .take(3)
        .join(' · ');
    final more =
        locations.length > 3 ? ' +${locations.length - 3}' : '';

    return InkWell(
      onTap: () => _showItemCard(db, it),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.panel,
          border: Border.all(
              color: belowMin
                  ? AppColors.red.withValues(alpha: 0.3)
                  : AppColors.line),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _categoryColor(it.category).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(_categoryIcon(it.category),
                size: 20, color: _categoryColor(it.category)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(
                    child: Text(it.name,
                        style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis),
                  ),
                  if (belowMin) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.red.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: const Text('⚠ ниже',
                          style: TextStyle(
                              fontSize: 9,
                              color: AppColors.red,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ]),
                const SizedBox(height: 3),
                Text('${it.sku} · ${it.category.label}',
                    style: const TextStyle(
                        fontSize: 10.5, color: AppColors.dim)),
                if (locNames.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('$locNames$more',
                      style: const TextStyle(
                          fontSize: 10.5, color: AppColors.mut),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${_num(total)} ${it.unit.label}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                    color: belowMin ? AppColors.red : AppColors.txt,
                  )),
              Text('мин ${_num(it.minQuantity.toDouble())}',
                  style:
                      const TextStyle(fontSize: 10, color: AppColors.dim)),
            ],
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, size: 16, color: AppColors.dim),
        ]),
      ),
    );
  }

  Future<void> _showItemCard(AppDatabase db, InventoryItem it) async {
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: AppColors.panel,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(children: [
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.line2,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: _categoryColor(it.category)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(_categoryIcon(it.category),
                            size: 26,
                            color: _categoryColor(it.category)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(it.name,
                                style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text('${it.sku} · ${it.category.label}',
                                style: const TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.dim)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        color: AppColors.mut,
                        onPressed: () {
                          Navigator.pop(ctx);
                          _openItemDialog(db, it);
                        },
                      ),
                    ]),
                    const SizedBox(height: 16),
                    _sectionTitle('ОСТАТКИ'),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0E1420),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(children: [
                        _kv('Всего',
                            '${_num(db.stockTotal(it.id))} ${it.unit.label}',
                            bold: true),
                        _kv('Минимум', _num(it.minQuantity.toDouble())),
                        if (it.price != null)
                          _kv('Цена',
                              '${it.price!.toStringAsFixed(0)} ₽ / ${it.unit.label}'),
                      ]),
                    ),
                    const SizedBox(height: 12),
                    _sectionTitle('ПО ЛОКАЦИЯМ'),
                    const SizedBox(height: 6),
                    if (db.stockByLocation(it.id).isEmpty)
                      const Text('Нет остатков',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.dim))
                    else
                      for (final e in db.stockByLocation(it.id).entries)
                        _locationRow(db, e.key, e.value, it, onTapShelf: true),
                    const SizedBox(height: 16),
                    _sectionTitle('ПОСЛЕДНИЕ ОПЕРАЦИИ'),
                    const SizedBox(height: 6),
                    if (db.transactionsForItem(it.id).isEmpty)
                      const Text('Операций нет',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.dim))
                    else
                      for (final t in db.transactionsForItem(it.id).take(10))
                        _txRow(t, item: it, db: db),
                    const SizedBox(height: 16),
                    _sectionTitle('ДЕЙСТВИЯ'),
                    const SizedBox(height: 6),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      _actionBtn(
                        icon: Icons.add,
                        label: 'Приход',
                        color: AppColors.grn,
                        onTap: () {
                          Navigator.pop(ctx);
                          _openTransactionDialog(
                              db, it, StockTransactionType.income);
                        },
                      ),
                      _actionBtn(
                        icon: Icons.remove,
                        label: 'Выдача',
                        color: AppColors.amb,
                        onTap: () {
                          Navigator.pop(ctx);
                          _openTransactionDialog(
                              db, it, StockTransactionType.outcome);
                        },
                      ),
                      _actionBtn(
                        icon: Icons.delete_outline,
                        label: 'Списать',
                        color: AppColors.red,
                        onTap: () {
                          Navigator.pop(ctx);
                          _openTransactionDialog(
                              db, it, StockTransactionType.writeOff);
                        },
                      ),
                      _actionBtn(
                        icon: Icons.swap_horiz,
                        label: 'Переместить',
                        color: AppColors.cyn,
                        onTap: () {
                          Navigator.pop(ctx);
                          _openTransactionDialog(
                              db, it, StockTransactionType.transfer);
                        },
                      ),
                      _actionBtn(
                        icon: Icons.fact_check_outlined,
                        label: 'Инвентаризация',
                        color: AppColors.pur,
                        onTap: () {
                          Navigator.pop(ctx);
                          _openTransactionDialog(
                              db, it, StockTransactionType.inventory);
                        },
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _openItemDialog(
      AppDatabase db, InventoryItem? editing) async {
    final skuCtrl = TextEditingController(text: editing?.sku ?? '');
    final nameCtrl = TextEditingController(text: editing?.name ?? '');
    final minCtrl =
        TextEditingController(text: (editing?.minQuantity ?? 0).toString());
    final priceCtrl = TextEditingController(
        text: editing?.price?.toStringAsFixed(0) ?? '');
    InventoryCategory cat =
        editing?.category ?? InventoryCategory.bearing;
    InventoryUnit unit = editing?.unit ?? InventoryUnit.piece;

    final ok = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: AppColors.panel,
          title: Text(editing == null
              ? 'Новая позиция'
              : 'Редактировать позицию'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: skuCtrl,
                      decoration: const InputDecoration(
                          labelText: 'SKU *', hintText: 'BR-6204'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Название *',
                          hintText: 'Подшипник 6204'),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<InventoryCategory>(
                      initialValue: cat,
                      isExpanded: true,
                      decoration:
                          const InputDecoration(labelText: 'Категория'),
                      items: [
                        for (final c in InventoryCategory.values)
                          DropdownMenuItem(value: c, child: Text(c.label)),
                      ],
                      onChanged: (v) => setS(() => cat = v ?? cat),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<InventoryUnit>(
                      initialValue: unit,
                      isExpanded: true,
                      decoration:
                          const InputDecoration(labelText: 'Ед. изм.'),
                      items: [
                        for (final u in InventoryUnit.values)
                          DropdownMenuItem(value: u, child: Text(u.label)),
                      ],
                      onChanged: (v) => setS(() => unit = v ?? unit),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: minCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: const InputDecoration(
                          labelText: 'Мин. остаток'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: priceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: const InputDecoration(
                          labelText: 'Цена, ₽', hintText: 'необязательно'),
                    ),
                  ),
                ]),
              ]),
            ),
          ),
          actions: [
            if (editing != null)
              TextButton(
                style:
                    TextButton.styleFrom(foregroundColor: AppColors.red),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: ctx,
                    builder: (c) => AlertDialog(
                      backgroundColor: AppColors.panel,
                      title: const Text('Удалить позицию?'),
                      content: const Text(
                          'Все операции по этой позиции тоже будут удалены.',
                          style: TextStyle(
                              fontSize: 13, color: AppColors.mut)),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(c, false),
                            child: const Text('Отмена')),
                        FilledButton(
                          style: FilledButton.styleFrom(
                              backgroundColor: AppColors.red),
                          onPressed: () => Navigator.pop(c, true),
                          child: const Text('Удалить'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    db.deleteInventoryItem(editing.id);
                    if (ctx.mounted) Navigator.pop(ctx, false);
                  }
                },
                child: const Text('Удалить'),
              ),
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

    final sku = skuCtrl.text.trim();
    final name = nameCtrl.text.trim();
    final min = int.tryParse(minCtrl.text.trim()) ?? 0;
    final price =
        double.tryParse(priceCtrl.text.trim().replaceAll(',', '.'));

    if (sku.isEmpty || name.isEmpty) {
      _snack('SKU и название обязательны');
      return;
    }

    final conflict = db.inventoryItems.firstWhere(
      (x) =>
          x.sku.toLowerCase() == sku.toLowerCase() && x.id != editing?.id,
      orElse: () => InventoryItem(
          id: '', sku: '', name: '', category: cat, unit: unit),
    );
    if (conflict.id.isNotEmpty) {
      _snack('SKU «$sku» уже занят');
      return;
    }

    if (editing == null) {
      db.addInventoryItem(InventoryItem(
        id: _uid(),
        sku: sku,
        name: name,
        category: cat,
        unit: unit,
        minQuantity: min,
        price: price,
      ));
      _snack('Позиция создана');
    } else {
      editing.sku = sku;
      editing.name = name;
      editing.category = cat;
      editing.unit = unit;
      editing.minQuantity = min;
      editing.price = price;
      db.updateInventoryItem(editing);
      _snack('Сохранено');
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// ВКЛАДКА 2 — ЛОКАЦИИ
// ═══════════════════════════════════════════════════════════════════

class _LocationsTab extends StatefulWidget {
  const _LocationsTab();
  @override
  State<_LocationsTab> createState() => _LocationsTabState();
}

class _LocationsTabState extends State<_LocationsTab> {
  String? _filterParkId;
  String _query = '';
  final _searchCtrl = TextEditingController();
  final Set<String> _collapsedParks = {};

  String _uid() => 'x${DateTime.now().microsecondsSinceEpoch}';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<StorageLocation> _filtered(AppDatabase db) {
    final q = _query.toLowerCase().trim();
    return db.storageLocations.where((l) {
      if (_filterParkId != null && l.parkId != _filterParkId) return false;
      if (q.isNotEmpty) {
        final hay = '${l.code} ${l.name}'.toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => a.code.compareTo(b.code));
  }

  @override
  Widget build(BuildContext context) {
    final db = context.watch<AppDatabase>();
    final filtered = _filtered(db);

    final byPark = <String?, List<StorageLocation>>{};
    for (final l in filtered) {
      byPark.putIfAbsent(l.parkId, () => []).add(l);
    }

    final parkKeys = byPark.keys.toList()
      ..sort((a, b) {
        if (a == null) return 1;
        if (b == null) return -1;
        final pa = db.parkById(a);
        final pb = db.parkById(b);
        return (pa?.name ?? '').compareTo(pb?.name ?? '');
      });

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: Text(
              'Локаций: ${db.storageLocations.length} · найдено: ${filtered.length}',
              style: const TextStyle(fontSize: 11, color: AppColors.dim),
            ),
          ),
          _primaryBtn(
            icon: Icons.add,
            label: 'Локация',
            onTap: () => _openLocationDialog(db, null),
          ),
        ]),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: _cardDeco,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(
                child: DropdownButtonFormField<String?>(
                  initialValue: _filterParkId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Парк',
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                        value: null, child: Text('Все парки')),
                    for (final p in db.parks)
                      DropdownMenuItem<String?>(
                          value: p.id, child: Text(p.name)),
                  ],
                  onChanged: (v) => setState(() => _filterParkId = v),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'Поиск по коду/названию',
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 8),
                    prefixIcon: const Icon(Icons.search, size: 16),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close, size: 14),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _query = '');
                            },
                          ),
                  ),
                ),
              ),
            ]),
          ]),
        ),
        const SizedBox(height: 12),
        if (db.storageLocations.isEmpty)
          _emptyState(
            icon: Icons.place_outlined,
            title: 'Нет локаций',
            subtitle: 'Создайте первую (полка, стеллаж, склад)',
            action: _primaryBtn(
              icon: Icons.add,
              label: 'Создать',
              onTap: () => _openLocationDialog(db, null),
            ),
          )
        else if (filtered.isEmpty)
          _emptyState(
            icon: Icons.search_off,
            title: 'Ничего не найдено',
            subtitle: 'Измените фильтры или запрос',
          )
        else
          for (final parkKey in parkKeys)
            _parkBlock(db, parkKey, byPark[parkKey]!),
      ]),
    );
  }

  Widget _parkBlock(
      AppDatabase db, String? parkKey, List<StorageLocation> locs) {
    final park = parkKey == null ? null : db.parkById(parkKey);
    final collapsed = _collapsedParks.contains(parkKey ?? '__none__');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: _cardDeco,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() {
              if (collapsed) {
                _collapsedParks.remove(parkKey ?? '__none__');
              } else {
                _collapsedParks.add(parkKey ?? '__none__');
              }
            }),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Row(children: [
                Icon(
                    collapsed
                        ? Icons.chevron_right
                        : Icons.expand_more,
                    size: 18,
                    color: AppColors.mut),
                const SizedBox(width: 6),
                const Icon(Icons.park_outlined,
                    size: 15, color: AppColors.cyn),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(park?.name ?? 'Без парка',
                      style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.panel2,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text('${locs.length}',
                      style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.mut)),
                ),
              ]),
            ),
          ),
          if (!collapsed) ...[
            const Divider(height: 1, color: AppColors.line),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  for (final l in locs) _locationTile(db, l),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _locationTile(AppDatabase db, StorageLocation l) {
    final items = db.itemsAtLocation(l.id);
    return InkWell(
      onTap: () => _showShelfCard(db, l),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFF0E1420),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          const Icon(Icons.inventory_2_outlined,
              size: 15, color: AppColors.amb),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.code,
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'monospace')),
                if (l.name.isNotEmpty)
                  Text(l.name,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.dim),
                      overflow: TextOverflow.ellipsis),
                Text('позиций: ${items.length}',
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.mut)),
              ],
            ),
          ),
          _iconBtn(
            icon: Icons.edit_outlined,
            onTap: () => _openLocationDialog(db, l),
          ),
          _iconBtn(
            icon: Icons.delete_outline,
            danger: true,
            onTap: () => _deleteLocation(db, l),
          ),
        ]),
      ),
    );
  }

  Future<void> _showShelfCard(
      AppDatabase db, StorageLocation loc) async {
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: AppColors.panel,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(children: [
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.line2,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      const Icon(Icons.inventory_2_outlined,
                          size: 26, color: AppColors.amb),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(loc.code,
                                style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'monospace')),
                            if (loc.name.isNotEmpty)
                              Text(loc.name,
                                  style: const TextStyle(
                                      fontSize: 11.5,
                                      color: AppColors.dim)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        color: AppColors.mut,
                        onPressed: () {
                          Navigator.pop(ctx);
                          _openLocationDialog(db, loc);
                        },
                      ),
                    ]),
                    const SizedBox(height: 16),
                    _sectionTitle('ПОЗИЦИИ НА ЛОКАЦИИ'),
                    const SizedBox(height: 6),
                    if (db.itemsAtLocation(loc.id).isEmpty)
                      const Text('Пусто',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.dim))
                    else
                      for (final it in db.itemsAtLocation(loc.id))
                        _shelfItemRow(db, loc, it),
                    const SizedBox(height: 16),
                    _sectionTitle('ДЕЙСТВИЯ'),
                    const SizedBox(height: 6),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      _actionBtn(
                        icon: Icons.add,
                        label: 'Приход',
                        color: AppColors.grn,
                        onTap: () {
                          Navigator.pop(ctx);
                          _openShelfTransaction(db, loc, StockTransactionType.income);
                        },
                      ),
                      _actionBtn(
                        icon: Icons.remove,
                        label: 'Выдача',
                        color: AppColors.amb,
                        onTap: () {
                          Navigator.pop(ctx);
                          _openShelfTransaction(db, loc, StockTransactionType.outcome);
                        },
                      ),
                      _actionBtn(
                        icon: Icons.delete_outline,
                        label: 'Списать',
                        color: AppColors.red,
                        onTap: () {
                          Navigator.pop(ctx);
                          _openShelfTransaction(db, loc, StockTransactionType.writeOff);
                        },
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _shelfItemRow(AppDatabase db, StorageLocation loc, InventoryItem it) {
    final qty = db.stockAt(it.id, loc.id);
    final belowMin = qty < it.minQuantity;
    return InkWell(
      onTap: () => _openTransactionDialogFromShelf(db, loc, it),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF0E1420),
          borderRadius: BorderRadius.circular(8),
          border: belowMin
              ? Border.all(color: AppColors.red.withValues(alpha: 0.3))
              : null,
        ),
        child: Row(children: [
          const Icon(Icons.circle, size: 8, color: AppColors.mut),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(it.name,
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
                Text('${it.sku} · мин ${_num(it.minQuantity.toDouble())}',
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.dim)),
              ],
            ),
          ),
          Text('${_num(qty)} ${it.unit.label}',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace',
                  color: belowMin ? AppColors.red : AppColors.txt)),
        ]),
      ),
    );
  }

  Future<void> _openLocationDialog(
      AppDatabase db, StorageLocation? editing) async {
    final codeCtrl = TextEditingController(text: editing?.code ?? '');
    final nameCtrl = TextEditingController(text: editing?.name ?? '');
    String? parkId = editing?.parkId ??
        (db.parks.isNotEmpty ? db.parks.first.id : null);

    final ok = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: AppColors.panel,
          title: Text(editing == null
              ? 'Новая локация'
              : 'Редактировать локацию'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                  controller: codeCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                      labelText: 'Код *',
                      hintText: 'P1-R2-P3',
                      helperText: 'Уникальный код для QR'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Название',
                      hintText: 'Стеллаж 2, полка 3'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: parkId,
                  isExpanded: true,
                  decoration:
                      const InputDecoration(labelText: 'Парк'),
                  items: [
                    const DropdownMenuItem<String?>(
                        value: null, child: Text('— без парка —')),
                    for (final p in db.parks)
                      DropdownMenuItem<String?>(
                          value: p.id, child: Text(p.name)),
                  ],
                  onChanged: (v) => setS(() => parkId = v),
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
              child: Text(editing == null ? 'Создать' : 'Сохранить'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;

    final code = codeCtrl.text.trim();
    final name = nameCtrl.text.trim();
    if (code.isEmpty) {
      _snack('Код обязателен');
      return;
    }

    final conflict = db.storageLocations.firstWhere(
      (x) => x.code.toLowerCase() == code.toLowerCase() &&
          x.id != editing?.id,
      orElse: () => StorageLocation(
          id: '', parkId: parkId, code: '', name: ''),
    );
    if (conflict.id.isNotEmpty) {
      _snack('Код «$code» уже используется');
      return;
    }

    if (editing == null) {
      db.addStorageLocation(StorageLocation(
        id: _uid(),
        parkId: parkId,
        code: code,
        name: name,
      ));
      _snack('Локация создана');
    } else {
      editing.code = code;
      editing.name = name;
      editing.parkId = parkId;
      db.updateStorageLocation(editing);
      _snack('Сохранено');
    }
  }

  Future<void> _deleteLocation(AppDatabase db, StorageLocation l) async {
    final qty = db.itemsAtLocation(l.id).length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: const Text('Удалить локацию?'),
        content: Text(
            '${l.code}${l.name.isNotEmpty ? " · ${l.name}" : ""}\n'
            'Позиций на локации: $qty.\n'
            'История транзакций сохранится, но локация станет «висячей».',
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
    db.deleteStorageLocation(l.id);
    _snack('Локация удалена');
  }

  Future<void> _openShelfTransaction(AppDatabase db, StorageLocation loc,
      StockTransactionType type) async {
    if (db.inventoryItems.isEmpty) {
      _snack('Сначала создайте хотя бы одну позицию');
      return;
    }
    final item = await _pickItem(db);
    if (item == null) return;
    _openTransactionDialog(db, item, type, prefilledLocation: loc);
  }

  Future<InventoryItem?> _pickItem(AppDatabase db) async {
    return showDialog<InventoryItem>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: const Text('Выберите позицию'),
        content: SizedBox(
          width: 440,
          child: SizedBox(
            height: 400,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: db.inventoryItems.length,
              itemBuilder: (_, i) {
                final it = db.inventoryItems[i];
                return ListTile(
                  title: Text(it.name,
                      style: const TextStyle(fontSize: 13)),
                  subtitle: Text('${it.sku} · ${it.category.label}',
                      style: const TextStyle(fontSize: 10.5)),
                  onTap: () => Navigator.pop(ctx, it),
                );
              },
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
  }

  Future<void> _openTransactionDialogFromShelf(
      AppDatabase db, StorageLocation loc, InventoryItem it) async {
    _openTransactionDialog(db, it, StockTransactionType.income,
        prefilledLocation: loc);
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// ВКЛАДКА 3 — ОПЕРАЦИИ (полная история)
// ═══════════════════════════════════════════════════════════════════

class _TransactionsTab extends StatefulWidget {
  const _TransactionsTab();
  @override
  State<_TransactionsTab> createState() => _TransactionsTabState();
}

class _TransactionsTabState extends State<_TransactionsTab> {
  StockTransactionType? _filterType;
  String? _filterItemId;
  String _query = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = context.watch<AppDatabase>();
    final all = db.stockTransactions;
    final filtered = all.where((t) {
      if (_filterType != null && t.type != _filterType) return false;
      if (_filterItemId != null && t.itemId != _filterItemId) return false;
      if (_query.isNotEmpty) {
        final item = db.itemById(t.itemId);
        final q = _query.toLowerCase().trim();
        final hay =
            '${item?.name ?? ''} ${item?.sku ?? ''} ${t.comment ?? ''}'
                .toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: Text('Всего: ${all.length} · показано: ${filtered.length}',
                style:
                    const TextStyle(fontSize: 11, color: AppColors.dim)),
          ),
        ]),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: _cardDeco,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Wrap(spacing: 6, runSpacing: 6, children: [
              _chip('Все', _filterType == null,
                  () => setState(() => _filterType = null)),
              for (final t in StockTransactionType.values)
                _chip(t.label, _filterType == t,
                    () => setState(() => _filterType = t)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'Поиск по названию/SKU/комментарию',
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 8),
                    prefixIcon: const Icon(Icons.search, size: 16),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close, size: 14),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _query = '');
                            },
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Сбросить',
                icon: const Icon(Icons.refresh, size: 18),
                onPressed: () => setState(() {
                  _filterType = null;
                  _filterItemId = null;
                  _query = '';
                  _searchCtrl.clear();
                }),
              ),
            ]),
          ]),
        ),
        const SizedBox(height: 12),
        if (filtered.isEmpty)
          _emptyState(
            icon: Icons.receipt_long_outlined,
            title: 'Операций нет',
            subtitle: all.isEmpty
                ? 'Проведите первую транзакцию'
                : 'Измените фильтры',
          )
        else
          for (final t in filtered) _txCard(db, t),
      ]),
    );
  }

  Widget _txCard(AppDatabase db, StockTransaction t) {
    final item = db.itemById(t.itemId);
    final color = _txColor(t.type);
    final date = t.createdAt;
    final dateStr =
        '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    final from = t.fromLocationId == null
        ? null
        : db.locationById(t.fromLocationId!);
    final to =
        t.toLocationId == null ? null : db.locationById(t.toLocationId!);
    final ride = t.rideId == null ? null : db.rideById(t.rideId);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: _cardDeco,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(t.type.label,
                style: TextStyle(
                    fontSize: 10, color: color, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(dateStr,
                style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.dim,
                    fontFamily: 'monospace')),
          ),
        ]),
        const SizedBox(height: 6),
        Text(item?.name ?? '—',
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600)),
        Text('${item?.sku ?? ''} · ${item?.category.label ?? ''}',
            style: const TextStyle(fontSize: 10.5, color: AppColors.dim)),
        const SizedBox(height: 6),
        if (from != null || to != null)
          Text(
            '${from?.code ?? '—'} → ${to?.code ?? '—'}',
            style: const TextStyle(
                fontSize: 11.5,
                fontFamily: 'monospace',
                color: AppColors.mut),
          ),
        if (ride != null)
          Text('на «${ride.name}»',
              style: const TextStyle(fontSize: 11, color: AppColors.cyn)),
        if (t.comment != null && t.comment!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text('· ${t.comment}',
                style: const TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: AppColors.dim)),
          ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '${t.quantity > 0 ? '' : ''}${_num(t.quantity)} ${item?.unit.label ?? ''}',
            style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
                color: color),
          ),
        ),
      ]),
    );
  }

  Color _txColor(StockTransactionType t) => switch (t) {
        StockTransactionType.income => AppColors.grn,
        StockTransactionType.outcome => AppColors.amb,
        StockTransactionType.writeOff => AppColors.red,
        StockTransactionType.transfer => AppColors.cyn,
        StockTransactionType.inventory => AppColors.pur,
      };

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// ДИАЛОГ ТРАНЗАКЦИИ (общий, расширен для transfer/inventory)
// ═══════════════════════════════════════════════════════════════════

Future<void> _openTransactionDialog(
  AppDatabase db,
  InventoryItem item,
  StockTransactionType type, {
  StorageLocation? prefilledLocation,
}) async {
  // Для inventory — двухшаговый: показываем учётный остаток,
  // пользователь вводит факт.
  if (type == StockTransactionType.inventory) {
    return _openInventoryDialog(db, item, prefilledLocation);
  }

  final qtyCtrl = TextEditingController(text: '1');
  final commentCtrl = TextEditingController();
  String? fromLocationId;
  String? toLocationId;
  String? rideId;

  if (type == StockTransactionType.income) {
    toLocationId = prefilledLocation?.id ??
        (db.storageLocations.isNotEmpty
            ? db.storageLocations.first.id
            : null);
  } else if (type == StockTransactionType.transfer) {
    final locs = db.locationsOfItem(item.id);
    if (locs.isNotEmpty) fromLocationId = locs.first.id;
  } else {
    fromLocationId = prefilledLocation?.id ??
        (db.locationsOfItem(item.id).isNotEmpty
            ? db.locationsOfItem(item.id).first.id
            : null);
  }

  final ok = await showDialog<bool>(
    context: db.context,
    useRootNavigator: true,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: Text('${type.label} · ${item.name}'),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (type == StockTransactionType.income)
                  _locationDropdown(
                    db,
                    'Куда',
                    toLocationId,
                    (v) => setS(() => toLocationId = v),
                    emptyHint: 'Нет локаций — создайте на вкладке «Локации»',
                  )
                else if (type == StockTransactionType.transfer) ...[
                  _locationDropdown(
                    db,
                    'Откуда',
                    fromLocationId,
                    (v) => setS(() => fromLocationId = v),
                    onlyWithStock: item.id,
                  ),
                  const SizedBox(height: 12),
                  _locationDropdown(
                    db,
                    'Куда',
                    toLocationId,
                    (v) => setS(() => toLocationId = v),
                  ),
                ] else
                  _locationDropdown(
                    db,
                    'Откуда',
                    fromLocationId,
                    (v) => setS(() => fromLocationId = v),
                    onlyWithStock: item.id,
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: qtyCtrl,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Количество (${item.unit.label})',
                  ),
                ),
                const SizedBox(height: 12),
                if (type == StockTransactionType.outcome)
                  DropdownButtonFormField<String>(
                    initialValue: rideId ?? '',
                    isExpanded: true,
                    decoration: const InputDecoration(
                        labelText: 'На аттракцион (необязательно)'),
                    items: [
                      const DropdownMenuItem(
                          value: '', child: Text('— не указан —')),
                      for (final r in db.rides)
                        DropdownMenuItem(
                          value: r.id,
                          child: Text(r.name,
                              overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (v) => setS(() =>
                        rideId = (v == null || v.isEmpty) ? null : v),
                  ),
                if (type == StockTransactionType.outcome)
                  const SizedBox(height: 12),
                TextField(
                  controller: commentCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                      labelText: 'Комментарий',
                      hintText: 'Для чего / откуда / примечание'),
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
                foregroundColor: const Color(0xFF1C1204)),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(type.label),
          ),
        ],
      ),
    ),
  );

  if (ok != true) return;

  final qty = double.tryParse(qtyCtrl.text.trim().replaceAll(',', '.'));
  if (qty == null || qty <= 0) {
    _snackIn(db.context, 'Некорректное количество');
    return;
  }
  if (type == StockTransactionType.income && toLocationId == null) {
    _snackIn(db.context, 'Выберите локацию');
    return;
  }
  if (type != StockTransactionType.income && fromLocationId == null) {
    _snackIn(db.context, 'Выберите локацию');
    return;
  }
  if (type == StockTransactionType.transfer && toLocationId == null) {
    _snackIn(db.context, 'Выберите локацию назначения');
    return;
  }
  if (type == StockTransactionType.transfer &&
      fromLocationId == toLocationId) {
    _snackIn(db.context, 'Локации совпадают');
    return;
  }

  final tx = StockTransaction(
    id: 'x${DateTime.now().microsecondsSinceEpoch}',
    type: type,
    itemId: item.id,
    fromLocationId:
        type == StockTransactionType.income ? null : fromLocationId,
    toLocationId:
        type == StockTransactionType.income ? toLocationId : (type == StockTransactionType.transfer ? toLocationId : null),
    quantity: qty,
    rideId: rideId,
    comment: commentCtrl.text.trim().isEmpty
        ? null
        : commentCtrl.text.trim(),
  );

  final err = db.applyStockTransaction(tx);
  if (err != null) {
    _snackIn(db.context, err);
    return;
  }
  _snackIn(db.context, '${type.label}: ${_num(qty)} ${item.unit.label}');
}

Future<void> _openInventoryDialog(
  AppDatabase db,
  InventoryItem item,
  StorageLocation? prefilled,
) async {
  final locs = prefilled != null
      ? [prefilled]
      : db.locationsOfItem(item.id);
  if (locs.isEmpty) {
    _snackIn(db.context,
        'Нет локаций с остатком этой позиции');
    return;
  }
  String? locId = locs.first.id;
  final factCtrl = TextEditingController();

  final ok = await showDialog<bool>(
    context: db.context,
    useRootNavigator: true,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) {
        final systemQty = db.stockAt(item.id, locId!);
        return AlertDialog(
          backgroundColor: AppColors.panel,
          title: Text('Инвентаризация · ${item.name}'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: locId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Локация'),
                    items: [
                      for (final l in locs)
                        DropdownMenuItem(
                          value: l.id,
                          child: Text('${l.code} · ${l.name}',
                              overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (v) => setS(() {
                      locId = v;
                      factCtrl.clear();
                    }),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0E1420),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(children: [
                      const Text('Учётный остаток:',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.dim)),
                      const Spacer(),
                      Text(
                          '${_num(systemQty)} ${item.unit.label}',
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'monospace')),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: factCtrl,
                    autofocus: true,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Фактический остаток',
                      suffixText: item.unit.label,
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
                  backgroundColor: AppColors.pur,
                  foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Применить'),
            ),
          ],
        );
      },
    ),
  );
  if (ok != true) return;

  final fact = double.tryParse(factCtrl.text.trim().replaceAll(',', '.'));
  if (fact == null || fact < 0) {
    _snackIn(db.context, 'Некорректное количество');
    return;
  }
  final system = db.stockAt(item.id, locId!);
  final diff = fact - system;
  if (diff.abs() < 0.001) {
    _snackIn(db.context, 'Расхождений нет');
    return;
  }

  final tx = StockTransaction(
    id: 'x${DateTime.now().microsecondsSinceEpoch}',
    type: StockTransactionType.inventory,
    itemId: item.id,
    toLocationId: locId,
    quantity: diff,
    comment:
        'Инвентаризация: учёт ${_num(system)}, факт ${_num(fact)}, разница ${diff > 0 ? "+" : ""}${_num(diff)}',
  );
  final err = db.applyStockTransaction(tx);
  if (err != null) {
    _snackIn(db.context, err);
    return;
  }
  _snackIn(db.context,
      'Скорректировано на ${diff > 0 ? "+" : ""}${_num(diff)} ${item.unit.label}');
}

Widget _locationDropdown(
  AppDatabase db,
  String label,
  String? selected,
  ValueChanged<String?> onChanged, {
  String? onlyWithStock,
  String? emptyHint,
}) {
  final locs = onlyWithStock == null
      ? db.storageLocations
      : db
          .locationsOfItem(onlyWithStock)
          .where((l) => db.stockAt(onlyWithStock, l.id) > 0)
          .toList();

  return DropdownButtonFormField<String>(
    initialValue: selected,
    isExpanded: true,
    decoration: InputDecoration(
      labelText: label,
      hintText: locs.isEmpty ? (emptyHint ?? 'Нет локаций') : null,
    ),
    items: [
      for (final l in locs)
        DropdownMenuItem(
          value: l.id,
          child: Text(
            '${l.code}${l.name.isNotEmpty ? " · ${l.name}" : ""}',
            overflow: TextOverflow.ellipsis,
          ),
        ),
    ],
    onChanged: onChanged,
  );
}

void _snackIn(BuildContext ctx, String msg) {
  ScaffoldMessenger.of(ctx).showSnackBar(
    SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
  );
}

// ═══════════════════════════════════════════════════════════════════
// ОБЩИЕ UI-ХЕЛПЕРЫ (используются всеми вкладками)
// ═══════════════════════════════════════════════════════════════════

Widget _sectionTitle(String t) => Text(t,
    style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: AppColors.dim,
        letterSpacing: 0.5));

Widget _kv(String k, String v, {bool bold = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        Expanded(
          child: Text(k,
              style: const TextStyle(fontSize: 12, color: AppColors.dim)),
        ),
        Text(v,
            style: TextStyle(
                fontSize: 12.5,
                fontFamily: 'monospace',
                fontWeight: bold ? FontWeight.w700 : FontWeight.w600)),
      ]),
    );

Widget _locationRow(AppDatabase db, String locId, double qty,
    InventoryItem it, {bool onTapShelf = false}) {
  final loc = db.locationById(locId);
  final park = loc?.parkId == null ? null : db.parkById(loc!.parkId);
  return Container(
    margin: const EdgeInsets.only(bottom: 4),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFF0E1420),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(children: [
      const Icon(Icons.place_outlined, size: 13, color: AppColors.mut),
      const SizedBox(width: 8),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(loc?.code ?? '—',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'monospace')),
            if (loc?.name != null)
              Text(
                '${loc!.name}${park != null ? " · ${park.name}" : ""}',
                style: const TextStyle(fontSize: 10, color: AppColors.dim),
              ),
          ],
        ),
      ),
      Text('${_num(qty)} ${it.unit.label}',
          style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              fontFamily: 'monospace')),
    ]),
  );
}

Widget _txRow(StockTransaction t, {InventoryItem? item, AppDatabase? db}) {
  final date = t.createdAt;
  final dateStr = '${date.day.toString().padLeft(2, '0')}.'
      '${date.month.toString().padLeft(2, '0')} '
      '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';
  final color = switch (t.type) {
    StockTransactionType.income => AppColors.grn,
    StockTransactionType.outcome => AppColors.amb,
    StockTransactionType.writeOff => AppColors.red,
    StockTransactionType.transfer => AppColors.cyn,
    StockTransactionType.inventory => AppColors.pur,
  };
  final sign = switch (t.type) {
    StockTransactionType.income => '+',
    StockTransactionType.outcome => '−',
    StockTransactionType.writeOff => '−',
    StockTransactionType.transfer => '↔',
    StockTransactionType.inventory => '±',
  };
  return Container(
    margin: const EdgeInsets.only(bottom: 4),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xFF0E1420),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(t.type.label,
            style: TextStyle(
                fontSize: 9.5, color: color, fontWeight: FontWeight.w700)),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          dateStr,
          style: const TextStyle(
              fontSize: 11, color: AppColors.dim, fontFamily: 'monospace'),
        ),
      ),
      Text('$sign${_num(t.quantity)}',
          style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: color,
              fontFamily: 'monospace')),
    ]),
  );
}

String _num(double v) {
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.toStringAsFixed(2);
}

Widget _chip(String label, bool active, VoidCallback onTap) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(99),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: active
            ? AppColors.cyn.withValues(alpha: 0.12)
            : AppColors.panel2,
        border: Border.all(
            color: active
                ? AppColors.cyn.withValues(alpha: 0.4)
                : AppColors.line2),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: active ? AppColors.cyn : AppColors.mut)),
    ),
  );
}

Widget _emptyState({
  required IconData icon,
  required String title,
  required String subtitle,
  Widget? action,
}) =>
    Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: _cardDeco,
      child: Column(children: [
        Icon(icon, size: 32, color: AppColors.dim),
        const SizedBox(height: 10),
        Text(title,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.mut)),
        const SizedBox(height: 4),
        Text(subtitle,
            style: const TextStyle(fontSize: 12, color: AppColors.dim)),
        if (action != null) ...[
          const SizedBox(height: 16),
          action,
        ],
      ]),
    );

Widget _actionBtn({
  required IconData icon,
  required String label,
  required Color color,
  required VoidCallback onTap,
}) =>
    InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color)),
        ]),
      ),
    );

Widget _iconBtn({
  required IconData icon,
  VoidCallback? onTap,
  bool danger = false,
}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(7),
    child: Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: AppColors.line2),
      ),
      child: Icon(icon,
          size: 13, color: onTap == null ? AppColors.dim : (danger ? AppColors.red : AppColors.mut)),
    ),
  );
}

Widget _primaryBtn({
  required IconData icon,
  required String label,
  required VoidCallback onTap,
}) =>
    InkWell(
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

Color _categoryColor(InventoryCategory c) => switch (c) {
      InventoryCategory.bearing => AppColors.blu,
      InventoryCategory.rti => AppColors.pur,
      InventoryCategory.fastener => AppColors.mut,
      InventoryCategory.lubricant => AppColors.amb,
      InventoryCategory.electric => AppColors.cyn,
      InventoryCategory.tool => AppColors.org,
      InventoryCategory.other => AppColors.dim,
    };

IconData _categoryIcon(InventoryCategory c) => switch (c) {
      InventoryCategory.bearing => Icons.circle_outlined,
      InventoryCategory.rti => Icons.grain,
      InventoryCategory.fastener => Icons.hardware,
      InventoryCategory.lubricant => Icons.water_drop,
      InventoryCategory.electric => Icons.bolt,
      InventoryCategory.tool => Icons.build,
      InventoryCategory.other => Icons.inventory_2_outlined,
    };

class _Kpi extends StatelessWidget {
  final String label, value, sub;
  final IconData icon;
  final Color color;
  const _Kpi({
    required this.label,
    required this.value,
    required this.sub,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      height: 1.1)),
              Text(label,
                  style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.mut,
                      fontWeight: FontWeight.w500)),
              Text(sub,
                  style: const TextStyle(
                      fontSize: 10.5, color: AppColors.dim)),
            ],
          ),
        ),
      ]),
    );
  }
}

final _cardDeco = BoxDecoration(
  color: AppColors.panel,
  border: Border.all(color: AppColors.line),
  borderRadius: BorderRadius.circular(14),
);