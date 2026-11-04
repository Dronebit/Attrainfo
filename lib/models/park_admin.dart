class ParkAdmin {
  final String id;
  String name;
  String pin;
  bool active;
  String? parkId;

  ParkAdmin({
    required this.id,
    required this.name,
    this.pin = '0000',
    this.active = true,
    this.parkId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'pin': pin,
        'active': active,
        'parkId': parkId,
      };

  factory ParkAdmin.fromJson(Map<String, dynamic> j) => ParkAdmin(
        id: j['id'],
        name: j['name'],
        pin: j['pin'] ?? '0000',
        active: j['active'] ?? true,
        parkId: j['parkId'],
      );
}