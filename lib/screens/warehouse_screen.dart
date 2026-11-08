import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/app_database.dart';
import '../../models/inventory.dart';
import '../../theme.dart';

class WarehouseScreen extends StatefulWidget {
  const WarehouseScreen({super.key});
  @override
  State<WarehouseScreen> createState() => _WarehouseScreenState();
}

class _WarehouseScreenState extends State<WarehouseScreen> {
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

    final total = db.inventoryItems.length;
    final below = db.belowMinCount;
    final value = db.totalStockValue;
    final filtered = _filtered(db);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // ─── KPI ───
      LayoutBuilder(builder: (c, box) {
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
      }),

      const SizedBox(height: 14),

      // ─── Верхняя панель ───
      Row(children: [
        Expanded(
          child: Text(
            'Найдено: ${filtered.length}',
            style: const TextStyle(fontSize: 11, color: AppColors.dim),
          ),
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

      // ─── Фильтры ───
      Container(
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
      ),

      const SizedBox(height: 12),

      // ─── Список ───
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
    ]);
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
          final code = loc?.code ?? '—';
          return '$code (${_num(e.value)})';
        })
        .take(3)
        .join(' · ');
    final more = locations.length > 3 ? ' +${locations.length - 3}' : '';

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
          // Иконка категории
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
                Text(
                  '${it.sku} · ${it.category.label}',
                  style: const TextStyle(fontSize: 10.5, color: AppColors.dim),
                ),
                if (locNames.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '$locNames$more',
                    style: const TextStyle(fontSize: 10.5, color: AppColors.mut),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${_num(total)} ${it.unit.label}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace',
                  color: belowMin ? AppColors.red : AppColors.txt,
                ),
              ),
              Text(
                'мин ${_num(it.minQuantity.toDouble())}',
                style: const TextStyle(fontSize: 10, color: AppColors.dim),
              ),
            ],
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, size: 16, color: AppColors.dim),
        ]),
      ),
    );
  }

  String _num(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(2);
  }

  // ─── КАРТОЧКА ───

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
                            size: 26, color: _categoryColor(it.category)),
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
                                    fontSize: 11.5, color: AppColors.dim)),
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
                        _kv('Всего', '${_num(db.stockTotal(it.id))} ${it.unit.label}',
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
                          style: TextStyle(fontSize: 12, color: AppColors.dim))
                    else
                      for (final e in db.stockByLocation(it.id).entries)
                        _locationRow(db, e.key, e.value, it),
                    const SizedBox(height: 16),
                    _sectionTitle('ПОСЛЕДНИЕ ОПЕРАЦИИ'),
                    const SizedBox(height: 6),
                    if (db.transactionsForItem(it.id).isEmpty)
                      const Text('Операций нет',
                          style: TextStyle(fontSize: 12, color: AppColors.dim))
                    else
                      for (final t in db.transactionsForItem(it.id).take(10))
                        _txRow(t),
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

  Widget _locationRow(
      AppDatabase db, String locId, double qty, InventoryItem it) {
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
                  style:
                      const TextStyle(fontSize: 10, color: AppColors.dim),
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

  Widget _txRow(StockTransaction t) {
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
      StockTransactionType.transfer => '',
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

  // ─── ДИАЛОГ: СОЗДАНИЕ / РЕДАКТИРОВАНИЕ ───

  Future<void> _openItemDialog(AppDatabase db, InventoryItem? editing) async {
    final skuCtrl = TextEditingController(text: editing?.sku ?? '');
    final nameCtrl = TextEditingController(text: editing?.name ?? '');
    final minCtrl =
        TextEditingController(text: (editing?.minQuantity ?? 0).toString());
    final priceCtrl = TextEditingController(
        text: editing?.price?.toStringAsFixed(0) ?? '');
    InventoryCategory cat = editing?.category ?? InventoryCategory.bearing;
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: skuCtrl,
                        decoration: const InputDecoration(
                            labelText: 'SKU *',
                            hintText: 'BR-6204'),
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
                            DropdownMenuItem(
                                value: c, child: Text(c.label)),
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
                            DropdownMenuItem(
                                value: u, child: Text(u.label)),
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
                        keyboardType:
                            const TextInputType.numberWithOptions(
                                decimal: true),
                        decoration:
                            const InputDecoration(labelText: 'Мин. остаток'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: priceCtrl,
                        keyboardType:
                            const TextInputType.numberWithOptions(
                                decimal: true),
                        decoration: const InputDecoration(
                            labelText: 'Цена, ₽',
                            hintText: 'необязательно'),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ),
          actions: [
            if (editing != null)
              TextButton(
                style: TextButton.styleFrom(
                    foregroundColor: AppColors.red),
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
    final price = double.tryParse(
        priceCtrl.text.trim().replaceAll(',', '.'));

    if (sku.isEmpty || name.isEmpty) {
      _snack('SKU и название обязательны');
      return;
    }

    // Проверка уникальности SKU
    final conflict = db.inventoryItems.firstWhere(
      (x) => x.sku.toLowerCase() == sku.toLowerCase() && x.id != editing?.id,
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

  // ─── ДИАЛОГ: ТРАНЗАКЦИЯ ───

  Future<void> _openTransactionDialog(
    AppDatabase db,
    InventoryItem item,
    StockTransactionType type,
  ) async {
    final qtyCtrl = TextEditingController(text: '1');
    final commentCtrl = TextEditingController();
    String? fromLocationId;
    String? toLocationId;
    String? rideId;

    // Дефолтные локации: для прихода — первая попавшаяся, для выдачи —
    // та, где реально есть остаток.
    if (type == StockTransactionType.income) {
      if (db.storageLocations.isNotEmpty) {
        toLocationId = db.storageLocations.first.id;
      }
    } else {
      final locs = db.locationsOfItem(item.id);
      if (locs.isNotEmpty) fromLocationId = locs.first.id;
    }

    final ok = await showDialog<bool>(
      context: context,
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
                  if (type == StockTransactionType.income) ...[
                    _locationDropdown(
                      db,
                      'Куда',
                      toLocationId,
                      (v) => setS(() => toLocationId = v),
                    ),
                  ] else ...[
                    _locationDropdown(
                      db,
                      'Откуда',
                      fromLocationId,
                      (v) => setS(() => fromLocationId = v),
                      onlyWithStock: type != StockTransactionType.transfer
                          ? item.id
                          : null,
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: qtyCtrl,
                    autofocus: true,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
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
                            child: Text(
                                '${r.name} · ${db.cityOfPark(db.parkById(r.parkId)!)}',
                                overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged: (v) => setS(
                          () => rideId = (v == null || v.isEmpty) ? null : v),
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
                  if (db.storageLocations.isEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.amb.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppColors.amb.withValues(alpha: 0.3)),
                      ),
                      child: const Row(children: [
                        Icon(Icons.warning_amber,
                            size: 14, color: AppColors.amb),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Нет ни одной локации. Создайте локацию сначала.',
                            style: TextStyle(
                                fontSize: 11, color: AppColors.amb),
                          ),
                        ),
                      ]),
                    ),
                  ],
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
      _snack('Некорректное количество');
      return;
    }
    if (type == StockTransactionType.income && toLocationId == null) {
      _snack('Выберите локацию');
      return;
    }
    if (type != StockTransactionType.income && fromLocationId == null) {
      _snack('Выберите локацию');
      return;
    }

    final tx = StockTransaction(
      id: _uid(),
      type: type,
      itemId: item.id,
      fromLocationId:
          type == StockTransactionType.income ? null : fromLocationId,
      toLocationId:
          type == StockTransactionType.income ? toLocationId : null,
      quantity: qty,
      rideId: rideId,
      comment: commentCtrl.text.trim().isEmpty
          ? null
          : commentCtrl.text.trim(),
    );

    final err = db.applyStockTransaction(tx);
    if (err != null) {
      _snack(err);
      return;
    }
    _snack('${type.label}: ${_num(qty)} ${item.unit.label}');
  }

  Widget _locationDropdown(
    AppDatabase db,
    String label,
    String? selected,
    ValueChanged<String?> onChanged, {
    String? onlyWithStock,
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
      decoration: InputDecoration(labelText: label),
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

  // ─── UI-хелперы ───

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
                    fontSize: 12, fontWeight: FontWeight.w600, color: color)),
          ]),
        ),
      );

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

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }
}

// ─── KPI ───

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
                  style: const TextStyle(fontSize: 10.5, color: AppColors.dim)),
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