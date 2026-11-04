class Region {
  final String id;
  String name;
  List<String> parkIds;
  bool active;
  DateTime createdAt;

  Region({
    required this.id,
    required this.name,
    List<String>? parkIds,
    this.active = true,
    DateTime? createdAt,
  })  : parkIds = parkIds ?? [],
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'parkIds': parkIds,
        'active': active,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Region.fromJson(Map<String, dynamic> j) => Region(
        id: j['id'],
        name: j['name'],
        parkIds: List<String>.from(j['parkIds'] ?? []),
        active: j['active'] ?? true,
        createdAt: DateTime.parse(j['createdAt']),
      );
}