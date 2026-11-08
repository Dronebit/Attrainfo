part of '../app_database.dart';

// ═══════════ Склад ТМЦ (Товарно-материальные ценности) ═══════════

extension _InventoryOps on AppDatabase {
  // ─── базовые геттеры ───

  InventoryItem? itemById(String? id) =>
      inventoryItems.firstWhereOrNull((e) => e.id == id);

  InventoryItem? itemBySku(String sku) =>
      inventoryItems.firstWhereOrNull((e) => e.sku == sku);

  StorageLocation? locationById(String? id) =>
      storageLocations.firstWhereOrNull((e) => e.id == id);

  StorageLocation? locationByCode(String code) =>
      storageLocations.firstWhereOrNull((e) => e.code == code);

  // ─── остатки ───

  /// Остаток позиции на конкретной локации.
  double stockAt(String itemId, String locationId) {
    double total = 0;
    for (final t in stockTransactions) {
      if (t.itemId != itemId) continue;
      if (t.toLocationId == locationId) total += t.quantity;
      if (t.fromLocationId == locationId) total -= t.quantity;
    }
    return total;
  }

  /// Общий остаток позиции по всем локациям.
  double stockTotal(String itemId) {
    double total = 0;
    for (final t in stockTransactions) {
      if (t.itemId != itemId) continue;
      if (t.toLocationId != null) total += t.quantity;
      if (t.fromLocationId != null) total -= t.quantity;
    }
    return total;
  }

  /// Распределение остатков по локациям (только непустые).
  Map<String, double> stockByLocation(String itemId) {
    final map = <String, double>{};
    for (final t in stockTransactions) {
      if (t.itemId != itemId) continue;
      if (t.toLocationId != null) {
        map[t.toLocationId!] = (map[t.toLocationId!] ?? 0) + t.quantity;
      }
      if (t.fromLocationId != null) {
        map[t.fromLocationId!] = (map[t.fromLocationId!] ?? 0) - t.quantity;
      }
    }
    map.removeWhere((k, v) => v.abs() < 0.001);
    return map;
  }

  /// Все позиции на локации (только с ненулевым остатком).
  List<InventoryItem> itemsAtLocation(String locationId) {
    final ids = <String>{};
    for (final t in stockTransactions) {
      if (t.toLocationId == locationId || t.fromLocationId == locationId) {
        ids.add(t.itemId);
      }
    }
    return ids
        .map(itemById)
        .whereType<InventoryItem>()
        .where((it) => stockAt(it.id, locationId).abs() > 0.001)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  /// Все локации, где есть остаток этой позиции.
  List<StorageLocation> locationsOfItem(String itemId) {
    final map = stockByLocation(itemId);
    return map.keys
        .map(locationById)
        .whereType<StorageLocation>()
        .toList()
      ..sort((a, b) => a.code.compareTo(b.code));
  }

  /// История операций по позиции (свежие сверху).
  List<StockTransaction> transactionsForItem(String itemId) =>
      stockTransactions.where((t) => t.itemId == itemId).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  /// Проверка «ниже минимума».
  bool isBelowMin(String itemId) {
    final item = itemById(itemId);
    if (item == null) return false;
    return stockTotal(itemId) < item.minQuantity;
  }

  // ─── операции ───

  /// Проводит транзакцию. Валидирует остаток при выдаче/списании/перемещении.
  /// Возвращает null при успехе или текст ошибки.
  String? applyStockTransaction(StockTransaction t) {
    if (t.fromLocationId != null &&
        (t.type == StockTransactionType.outcome ||
            t.type == StockTransactionType.writeOff ||
            t.type == StockTransactionType.transfer)) {
      final available = stockAt(t.itemId, t.fromLocationId!);
      if (available + 0.001 < t.quantity) {
        return 'Недостаточно на локации: есть ${available.toStringAsFixed(2)}, '
            'нужно ${t.quantity.toStringAsFixed(2)}';
      }
    }
    stockTransactions.add(t);
    save();
    return null;
  }

  // ─── CRUD предметов ───

  void addInventoryItem(InventoryItem item) {
    inventoryItems.add(item);
    save();
  }

  void updateInventoryItem(InventoryItem item) {
    final idx = inventoryItems.indexWhere((e) => e.id == item.id);
    if (idx >= 0) inventoryItems[idx] = item;
    save();
  }

  void deleteInventoryItem(String itemId) {
    inventoryItems.removeWhere((e) => e.id == itemId);
    stockTransactions.removeWhere((t) => t.itemId == itemId);
    save();
  }

  // ─── CRUD локаций ───

  void addStorageLocation(StorageLocation loc) {
    storageLocations.add(loc);
    save();
  }

  void updateStorageLocation(StorageLocation loc) {
    final idx = storageLocations.indexWhere((e) => e.id == loc.id);
    if (idx >= 0) storageLocations[idx] = loc;
    save();
  }

  void deleteStorageLocation(String locId) {
    storageLocations.removeWhere((e) => e.id == locId);
    // Транзакции оставляем (они — история). Локация в них станет "висячей",
    // но её можно будет найти по id, если понадобится.
    save();
  }

  // ─── быстрые сводки для UI ───

  /// Сколько позиций ниже минимума (для дашборда).
  int get belowMinCount =>
      inventoryItems.where((it) => stockTotal(it.id) < it.minQuantity).length;

  /// Общая стоимость остатков (если у позиции указана цена).
  double get totalStockValue {
    double total = 0;
    for (final it in inventoryItems) {
      if (it.price == null) continue;
      total += stockTotal(it.id) * it.price!;
    }
    return total;
  }
}