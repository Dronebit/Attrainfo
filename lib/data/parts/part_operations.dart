part of '../app_database.dart';

// ═══════════ Аттракционы, простои, инциденты, аналитика ═══════════

extension _OperationsOps on AppDatabase {
  // ─── базовые геттеры ───

  Ride? rideById(String? id) => rides.firstWhereOrNull((r) => r.id == id);

  String ridePath(String rideId) {
    final r = rideById(rideId);
    if (r == null) return '—';
    final p = parkById(r.parkId);
    final l = p == null ? null : locById(p.locId);
    final c = l == null ? null : cityById(l.cityId);
    return [c?.name, l?.name, p?.name].where((x) => x != null).join(' · ');
  }

  List<Ride> ridesOfPark(String parkId) =>
      rides.where((r) => r.parkId == parkId).toList()
        ..sort((a, b) => a.name.compareTo(b.name));

  List<Downtime> activeDowntimes() =>
      downtimes.where((d) => d.end == null).toList();

  List<Downtime> activeDowntimesOfPark(String parkId) {
    final rideIds = rides
        .where((r) => r.parkId == parkId)
        .map((r) => r.id)
        .toSet();
    return downtimes
        .where((d) => d.end == null && rideIds.contains(d.rideId))
        .toList();
  }

  List<Incident> openIncidents() => incidents
      .where((i) => i.status != IncidentStatus.resolved)
      .toList()
    ..sort((a, b) => b.ts.compareTo(a.ts));

  List<Incident> openIncidentsOfPark(String parkId) {
    final rideIds = rides
        .where((r) => r.parkId == parkId)
        .map((r) => r.id)
        .toSet();
    return incidents
        .where((i) =>
            i.status != IncidentStatus.resolved &&
            rideIds.contains(i.rideId))
        .toList()
      ..sort((a, b) => b.ts.compareTo(a.ts));
  }

  // ─── операции с простоями ───

  void addDowntime(Downtime d) {
    downtimes.add(d);
    // Аттракцион → в статус "простой"
    final r = rideById(d.rideId);
    if (r != null) r.status = RideStatus.downtime;
    save();
  }

  void closeDowntime(String downtimeId, {String? done}) {
    final d = downtimes.firstWhereOrNull((x) => x.id == downtimeId);
    if (d == null) return;
    d.end = DateTime.now();
    if (done != null && done.isNotEmpty) d.done = done;

    // Если больше нет открытых простоев на этом аттракционе — вернуть в работу
    final r = rideById(d.rideId);
    if (r != null) {
      final stillOpen = downtimes.any(
          (x) => x.rideId == d.rideId && x.end == null && x.id != d.id);
      if (!stillOpen) r.status = RideStatus.active;
    }
    save();
  }

  void updateDowntime(Downtime d) {
    final idx = downtimes.indexWhere((x) => x.id == d.id);
    if (idx >= 0) downtimes[idx] = d;
    save();
  }

  // ─── операции с инцидентами ───

  void addIncident(Incident i) {
    incidents.add(i);
    save();
  }

  void updateIncident(Incident i) {
    final idx = incidents.indexWhere((x) => x.id == i.id);
    if (idx >= 0) incidents[idx] = i;
    save();
  }

  void resolveIncident(String incidentId) {
    final i = incidents.firstWhereOrNull((x) => x.id == incidentId);
    if (i == null) return;
    i.status = IncidentStatus.resolved;
    i.resolvedTs = DateTime.now();
    save();
  }

  void deleteIncident(String incidentId) {
    incidents.removeWhere((x) => x.id == incidentId);
    save();
  }

  // ─── аналитика ───

  List<({String rideId, double total, Map<DowntimeReason, double> byReason})>
      downtimeByRide(int periodDays) {
    final now = DateTime.now();
    final from = now.subtract(Duration(days: periodDays));
    final map = <String,
        ({double total, Map<DowntimeReason, double> byReason})>{};
    for (final d in downtimes) {
      final s = d.start.isAfter(from) ? d.start : from;
      final e = (d.end ?? now).isBefore(now) ? (d.end ?? now) : now;
      if (!e.isAfter(s)) continue;
      final hrs = e.difference(s).inMinutes / 60.0;
      final cur =
          map[d.rideId] ?? (total: 0.0, byReason: <DowntimeReason, double>{});
      final br = Map<DowntimeReason, double>.from(cur.byReason);
      br[d.reason] = (br[d.reason] ?? 0) + hrs;
      map[d.rideId] = (total: cur.total + hrs, byReason: br);
    }
    return map.entries
        .map((e) =>
            (rideId: e.key, total: e.value.total, byReason: e.value.byReason))
        .toList()
      ..sort((a, b) => b.total.compareTo(a.total));
  }

  /// Быстрый счётчик для дашборда.
  /// Возвращает: total / active / downtime / retired / openIncidents / activeDowntimes.
  ({
    int total,
    int active,
    int downtime,
    int retired,
    int openIncidents,
    int activeDowntimes,
  }) ridesSummary() {
    final activeN = rides.where((r) => r.status == RideStatus.active).length;
    final downtimeN =
        rides.where((r) => r.status == RideStatus.downtime).length;
    final retiredN =
        rides.where((r) => r.status == RideStatus.retired).length;
    return (
      total: rides.length,
      active: activeN,
      downtime: downtimeN,
      retired: retiredN,
      openIncidents: openIncidents().length,
      activeDowntimes: activeDowntimes().length,
    );
  }
}