import 'enums.dart';

class City {
  final String id;
  String name;
  City({required this.id, required this.name});
  Map<String, dynamic> toJson() => {'id': id, 'name': name};
  factory City.fromJson(Map<String, dynamic> j) => City(id: j['id'], name: j['name']);
}

class ParkLocation { // избегаем конфликта с dart:core Location
  final String id;
  String cityId;
  String name;
  ParkLocation({required this.id, required this.cityId, required this.name});
  Map<String, dynamic> toJson() => {'id': id, 'cityId': cityId, 'name': name};
  factory ParkLocation.fromJson(Map<String, dynamic> j) =>
      ParkLocation(id: j['id'], cityId: j['cityId'], name: j['name']);
}

class Park {
  final String id;
  String locId;
  String name;
  DateTime? openedAt;
  String? address;
  String? phone;

  Park({
    required this.id,
    required this.locId,
    required this.name,
    this.openedAt,
    this.address,
    this.phone,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'locId': locId,
        'name': name,
        'openedAt': openedAt?.toIso8601String(),
        'address': address,
        'phone': phone,
      };

  factory Park.fromJson(Map<String, dynamic> j) => Park(
        id: j['id'],
        locId: j['locId'],
        name: j['name'],
        openedAt:
            j['openedAt'] != null ? DateTime.parse(j['openedAt']) : null,
        address: j['address'],
        phone: j['phone'],
      );
}

class Ride {
  final String id;
  String parkId;
  String name;
  RideType type;
  int? year;
  RideStatus status;

  Ride({required this.id, required this.parkId, required this.name,
      required this.type, this.year, required this.status});

  Map<String, dynamic> toJson() => {
        'id': id, 'parkId': parkId, 'name': name,
        'type': type.name, 'year': year, 'status': status.name,
      };
  factory Ride.fromJson(Map<String, dynamic> j) => Ride(
        id: j['id'], parkId: j['parkId'], name: j['name'],
        type: RideType.values.firstWhere((e) => e.name == j['type']),
        year: j['year'],
        status: RideStatus.values.firstWhere((e) => e.name == j['status']),
      );
}



class Downtime {
  final String id;
  String rideId;
  DowntimeReason reason;
  String? techId;
  DateTime start;
  DateTime? planned;
  DateTime? end;
  String comment;
  String? done;

  Downtime({
    required this.id, required this.rideId, required this.reason,
    this.techId, required this.start, this.planned, this.end,
    this.comment = '', this.done,
  });

  Duration get elapsed => (end ?? DateTime.now()).difference(start);

  Map<String, dynamic> toJson() => {
        'id': id, 'rideId': rideId, 'reason': reason.name,
        'techId': techId, 'start': start.toIso8601String(),
        'planned': planned?.toIso8601String(),
        'end': end?.toIso8601String(),
        'comment': comment, 'done': done,
      };
  factory Downtime.fromJson(Map<String, dynamic> j) => Downtime(
        id: j['id'], rideId: j['rideId'],
        reason: DowntimeReason.values.firstWhere((e) => e.name == j['reason']),
        techId: j['techId'],
        start: DateTime.parse(j['start']),
        planned: j['planned'] != null ? DateTime.parse(j['planned']) : null,
        end: j['end'] != null ? DateTime.parse(j['end']) : null,
        comment: j['comment'] ?? '',
        done: j['done'],
      );
}

class Incident {
  final String id;
  String rideId;
  IncidentType type;
  Severity severity;
  IncidentStatus status;
  String? techId;
  DateTime ts;
  String desc;
  DateTime? resolvedTs;

  Incident({
    required this.id, required this.rideId, required this.type,
    required this.severity, required this.status, this.techId,
    required this.ts, required this.desc, this.resolvedTs,
  });

  Map<String, dynamic> toJson() => {
        'id': id, 'rideId': rideId, 'type': type.name,
        'severity': severity.name, 'status': status.name,
        'techId': techId, 'ts': ts.toIso8601String(),
        'desc': desc, 'resolvedTs': resolvedTs?.toIso8601String(),
      };
  factory Incident.fromJson(Map<String, dynamic> j) => Incident(
        id: j['id'], rideId: j['rideId'],
        type: IncidentType.values.firstWhere((e) => e.name == j['type']),
        severity: Severity.values.firstWhere((e) => e.name == j['severity']),
        status: IncidentStatus.values.firstWhere((e) => e.name == j['status']),
        techId: j['techId'],
        ts: DateTime.parse(j['ts']),
        desc: j['desc'],
        resolvedTs: j['resolvedTs'] != null ? DateTime.parse(j['resolvedTs']) : null,
      );
}