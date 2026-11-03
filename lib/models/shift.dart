class Shift {
  String parkId;
  DateTime startedAt;
  List<String> rideIds;
  bool isRelief;
  String? operatorId;

  Shift({
    required this.parkId,
    required this.startedAt,
    List<String>? rideIds,
    this.isRelief = false,
    this.operatorId,
  }) : rideIds = rideIds ?? [];

  Map<String, dynamic> toJson() => {
        'parkId': parkId,
        'startedAt': startedAt.toIso8601String(),
        'rideIds': rideIds,
        'isRelief': isRelief,
        'operatorId': operatorId,
      };

  factory Shift.fromJson(Map<String, dynamic> j) => Shift(
        parkId: j['parkId'],
        startedAt: DateTime.parse(j['startedAt']),
        rideIds: List<String>.from(j['rideIds'] ?? []),
        isRelief: j['isRelief'] ?? false,
        operatorId: j['operatorId'],
      );
}