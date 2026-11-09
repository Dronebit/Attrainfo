// ─────────────────────────────────────────────
// Категории — для фильтров и отчётов
// ─────────────────────────────────────────────
enum InventoryCategory {
  bearing,    // Подшипники
  rti,        // РТИ (резина)
  fastener,   // Крепёж
  lubricant,  // Смазки
  electric,   // Электрика
  tool,       // Инструмент
  other,      // Разное
}

extension InventoryCategoryX on InventoryCategory {
  String get label => const {
        InventoryCategory.bearing: 'Подшипники',
        InventoryCategory.rti: 'РТИ',
        InventoryCategory.fastener: 'Крепёж',
        InventoryCategory.lubricant: 'Смазки',
        InventoryCategory.electric: 'Электрика',
        InventoryCategory.tool: 'Инструмент',
        InventoryCategory.other: 'Разное',
      }[this]!;
}

// ─────────────────────────────────────────────
// Единицы измерения
// ─────────────────────────────────────────────
enum InventoryUnit { piece, kg, meter, liter, set }

extension InventoryUnitX on InventoryUnit {
  String get label => const {
        InventoryUnit.piece: 'шт',
        InventoryUnit.kg: 'кг',
        InventoryUnit.meter: 'м',
        InventoryUnit.liter: 'л',
        InventoryUnit.set: 'компл',
      }[this]!;
}

// ─────────────────────────────────────────────
// Локация (полка, стеллаж, склад)
// Иерархия: park → rack → shelf
// Код вида "P1-R2-P3" = парк 1, стеллаж 2, полка 3
// ─────────────────────────────────────────────
class StorageLocation {
  final String id;
  String? parkId;      // привязка к парку (p1, p2...)
  String? parentId;    // для иерархии (стеллаж → парк)
  String code;         // "P1-R2-P3"
  String name;         // "Стеллаж 2, полка 3"
  String? description;
  String? responsibleEmployeeId;
  String? photoPath;   // путь к фото "эталонной укладки"

  StorageLocation({
    required this.id,
    this.parkId,
    this.parentId,
    required this.code,
    required this.name,
    this.description,
    this.responsibleEmployeeId,
    this.photoPath,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'parkId': parkId,
        'parentId': parentId,
        'code': code,
        'name': name,
        'description': description,
        'responsibleEmployeeId': responsibleEmployeeId,
        'photoPath': photoPath,
      };

  factory StorageLocation.fromJson(Map<String, dynamic> j) => StorageLocation(
        id: j['id'],
        parkId: j['parkId'],
        parentId: j['parentId'],
        code: j['code'],
        name: j['name'],
        description: j['description'],
        responsibleEmployeeId: j['responsibleEmployeeId'],
        photoPath: j['photoPath'],
      );
}

// ─────────────────────────────────────────────
// Позиция (SKU) — то, что учитываем
// ─────────────────────────────────────────────
enum InventoryItemKind { group, item }

extension InventoryItemKindX on InventoryItemKind {
  String get label => const {
        InventoryItemKind.group: 'Группа',
        InventoryItemKind.item: 'Позиция',
      }[this]!;
}

class InventoryItem {
  final String id;
  String sku;
  String name;
  InventoryCategory category;
  InventoryUnit unit;
  int minQuantity;
  double? price;
  String? photoPath;
  List<String> compatibleRideIds;
  String? note;

  // ─── Дерево ───
  String? parentId;
  InventoryItemKind kind;

  InventoryItem({
    required this.id,
    required this.sku,
    required this.name,
    required this.category,
    required this.unit,
    this.minQuantity = 0,
    this.price,
    this.photoPath,
    List<String>? compatibleRideIds,
    this.note,
    this.parentId,
    this.kind = InventoryItemKind.item,
  }) : compatibleRideIds = compatibleRideIds ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'sku': sku,
        'name': name,
        'category': category.name,
        'unit': unit.name,
        'minQuantity': minQuantity,
        'price': price,
        'photoPath': photoPath,
        'compatibleRideIds': compatibleRideIds,
        'note': note,
        'parentId': parentId,
        'kind': kind.name,
      };

  factory InventoryItem.fromJson(Map<String, dynamic> j) => InventoryItem(
        id: j['id'],
        sku: j['sku'],
        name: j['name'],
        category: InventoryCategory.values.firstWhere(
          (e) => e.name == j['category'],
          orElse: () => InventoryCategory.other,
        ),
        unit: InventoryUnit.values.firstWhere(
          (e) => e.name == j['unit'],
          orElse: () => InventoryUnit.piece,
        ),
        minQuantity: j['minQuantity'] ?? 0,
        price: (j['price'] as num?)?.toDouble(),
        photoPath: j['photoPath'],
        compatibleRideIds:
            (j['compatibleRideIds'] as List?)?.cast<String>() ?? [],
        note: j['note'],
        parentId: j['parentId'],
        kind: InventoryItemKind.values.firstWhere(
          (e) => e.name == j['kind'],
          orElse: () => InventoryItemKind.item,
        ),
      );
}

// ─────────────────────────────────────────────
// Тип транзакции
// ─────────────────────────────────────────────
enum StockTransactionType {
  income,     // Приход
  outcome,    // Выдача (на аттракцион, механику)
  writeOff,   // Списание (износ, потеря)
  transfer,   // Перемещение между локациями
  inventory,  // Инвентаризация (корректировка)
}

extension StockTransactionTypeX on StockTransactionType {
  String get label => const {
        StockTransactionType.income: 'Приход',
        StockTransactionType.outcome: 'Выдача',
        StockTransactionType.writeOff: 'Списание',
        StockTransactionType.transfer: 'Перемещение',
        StockTransactionType.inventory: 'Инвентаризация',
      }[this]!;
}

// ─────────────────────────────────────────────
// Транзакция — движение ТМЦ
// ─────────────────────────────────────────────
class StockTransaction {
  final String id;
  StockTransactionType type;
  String itemId;
  String? fromLocationId;  // null для прихода
  String? toLocationId;    // null для списания/выдачи
  double quantity;
  String? rideId;          // если выдано на аттракцион
  String? employeeId;      // кто взял / кому выдано
  String? authorId;        // кто провёл транзакцию
  DateTime createdAt;
  String? comment;
  String? photoPath;

  StockTransaction({
    required this.id,
    required this.type,
    required this.itemId,
    this.fromLocationId,
    this.toLocationId,
    required this.quantity,
    this.rideId,
    this.employeeId,
    this.authorId,
    DateTime? createdAt,
    this.comment,
    this.photoPath,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'itemId': itemId,
        'fromLocationId': fromLocationId,
        'toLocationId': toLocationId,
        'quantity': quantity,
        'rideId': rideId,
        'employeeId': employeeId,
        'authorId': authorId,
        'createdAt': createdAt.toIso8601String(),
        'comment': comment,
        'photoPath': photoPath,
      };

  factory StockTransaction.fromJson(Map<String, dynamic> j) =>
      StockTransaction(
        id: j['id'],
        type: StockTransactionType.values.firstWhere(
          (e) => e.name == j['type'],
          orElse: () => StockTransactionType.income,
        ),
        itemId: j['itemId'],
        fromLocationId: j['fromLocationId'],
        toLocationId: j['toLocationId'],
        quantity: (j['quantity'] as num).toDouble(),
        rideId: j['rideId'],
        employeeId: j['employeeId'],
        authorId: j['authorId'],
        createdAt: DateTime.parse(j['createdAt']),
        comment: j['comment'],
        photoPath: j['photoPath'],
      );
}