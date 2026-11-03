class ParkAdmin {
  final String id;
  String name;
  String pin;
  bool active;

  ParkAdmin({
    required this.id,
    required this.name,
    this.pin = '0000',
    this.active = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'pin': pin,
        'active': active,
      };

  factory ParkAdmin.fromJson(Map<String, dynamic> j) => ParkAdmin(
        id: j['id'],
        name: j['name'],
        pin: j['pin'] ?? '0000',
        active: j['active'] ?? true,
      );
}