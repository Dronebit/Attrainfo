import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../data/app_database.dart';
import '../models/enums.dart';
import '../models/models.dart';
import '../theme.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final db = context.watch<AppDatabase>();
    final now = DateTime.now();
    final retiredN = db.rides.where((r) => r.status == RideStatus.retired).length;
    final inService = db.rides.length - retiredN;
    final activeN = db.rides.where((r) => r.status == RideStatus.active).length;
    final avail = inService == 0 ? 0 : (activeN / inService * 100).round();
    final actDt = db.downtimes.where((d) => d.end == null && d.reason != DowntimeReason.retired).toList();
    final actHours = actDt.fold<double>(0, (a, d) => a + now.difference(d.start).inMinutes / 60.0);
    final t30 = now.subtract(const Duration(days: 30));
    final inc30 = db.incidents.where((i) => i.ts.isAfter(t30)).toList();
    final br30 = inc30.where((i) => i.type == IncidentType.breakdown).length;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // KPI row
      LayoutBuilder(builder: (c, box) {
        final cols = box.maxWidth > 900 ? 4 : box.maxWidth > 500 ? 2 : 1;
        final w = (box.maxWidth - (cols - 1) * 14) / cols;
        return Wrap(spacing: 14, runSpacing: 14, children: [
          SizedBox(width: w, child: _Kpi(label: 'Аттракционов всего', value: '${db.rides.length}', sub: '$retiredN выведено', icon: Icons.layers_outlined, color: AppColors.blu)),
          SizedBox(width: w, child: _Kpi(label: 'В работе', value: '$activeN', sub: 'Готовность — $avail%', icon: Icons.speed, color: AppColors.grn)),
          SizedBox(width: w, child: _Kpi(label: 'Активных простоев', value: '${actDt.length}', sub: 'Накоплено ${actHours.toStringAsFixed(1)} ч', icon: Icons.timer_outlined, color: AppColors.amb)),
          SizedBox(width: w, child: _Kpi(label: 'Событий за 30 дней', value: '${inc30.length}', sub: 'Из них поломок: $br30', icon: Icons.warning_amber_rounded, color: AppColors.red)),
        ]);
      }),
      const SizedBox(height: 14),

      // 2 charts row
      LayoutBuilder(builder: (c, box) {
        final wide = box.maxWidth > 800;
        final donut = _ChartCard(
          title: 'События по типам · 30 дней',
          icon: Icons.warning_amber_rounded,
          height: 250,
          child: _DonutChart(incidents: inc30),
        );
        final reasons = _ChartCard(
          title: 'Часы простоя по причинам',
          icon: Icons.timer_outlined,
          height: 250,
          child: _ReasonsChart(downtimes: db.downtimes),
        );
        return wide
            ? Row(children: [Expanded(child: donut), const SizedBox(width: 14), Expanded(child: reasons)])
            : Column(children: [donut, const SizedBox(height: 14), reasons]);
      }),
      const SizedBox(height: 14),

      // 14-day bar chart
      _ChartCard(
        title: 'Динамика событий · 14 дней',
        icon: Icons.calendar_month,
        height: 280,
        child: _DaysChart(incidents: db.incidents),
      ),
      const SizedBox(height: 14),

      // Top downtime cards
      LayoutBuilder(builder: (c, box) {
        final wide = box.maxWidth > 800;
        final top30 = _TopDowntimeCard(db: db, days: 30, title: 'Дольше всех в простое · 30 дней');
        final top365 = _TopDowntimeCard(db: db, days: 365, title: 'Дольше всех в простое · 1 год');
        return wide
            ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: top30),
                const SizedBox(width: 14),
                Expanded(child: top365),
              ])
            : Column(children: [top30, const SizedBox(height: 14), top365]);
      }),
    ]);
  }
}

class _Kpi extends StatelessWidget {
  final String label, value, sub;
  final IconData icon;
  final Color color;
  const _Kpi({required this.label, required this.value, required this.sub, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha:0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w700, height: 1.1)),
          Text(label, style: const TextStyle(fontSize: 12.5, color: AppColors.mut, fontWeight: FontWeight.w500)),
          Text(sub, style: const TextStyle(fontSize: 11.5, color: AppColors.dim)),
        ])),
      ]),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final double height;
  final Widget child;
  const _ChartCard({required this.title, required this.icon, required this.height, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 16, color: AppColors.mut),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 14),
        SizedBox(height: height, child: child),
      ]),
    );
  }
}

class _DonutChart extends StatelessWidget {
  final List<Incident> incidents;
  const _DonutChart({required this.incidents});
  @override
  Widget build(BuildContext context) {
    final entries = IncidentType.values.map((t) => MapEntry(t, incidents.where((i) => i.type == t).length)).toList();
    final total = entries.fold<int>(0, (a, e) => a + e.value);
    if (total == 0) return const Center(child: Text('Нет данных', style: TextStyle(color: AppColors.dim)));
    return Row(children: [
      Expanded(child: PieChart(PieChartData(
        sectionsSpace: 3,
        centerSpaceRadius: 55,
        sections: entries.where((e) => e.value > 0).map((e) => PieChartSectionData(
          value: e.value.toDouble(),
          color: e.key.color,
          radius: 40,
          showTitle: false,
        )).toList(),
      ))),
      const SizedBox(width: 14),
      Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: entries.map((e) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Container(width: 9, height: 9, decoration: BoxDecoration(color: e.key.color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text('${e.key.label} — ${e.value}', style: const TextStyle(fontSize: 12, color: AppColors.mut)),
          ]),
        )).toList(),
      ),
    ]);
  }
}

class _ReasonsChart extends StatelessWidget {
  final List<Downtime> downtimes;
  const _ReasonsChart({required this.downtimes});
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final hours = DowntimeReason.values.map((r) => downtimes
        .where((d) => d.reason == r)
        .fold<double>(0, (a, d) => a + (d.end ?? now).difference(d.start).inMinutes / 60.0)).toList();
    final maxH = hours.isEmpty ? 1.0 : hours.reduce((a, b) => a > b ? a : b);
    return BarChart(BarChartData(
      alignment: BarChartAlignment.spaceAround,
      maxY: maxH * 1.15,
      gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => const FlLine(color: Color(0x0FFFFFFF))),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true,
          getTitlesWidget: (v, meta) {
            final i = v.toInt();
            if (i < 0 || i >= DowntimeReason.values.length) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(DowntimeReason.values[i].label.split(' ').first, style: const TextStyle(fontSize: 10, color: AppColors.mut)),
            );
          },
        )),
      ),
      barGroups: List.generate(DowntimeReason.values.length, (i) => BarChartGroupData(
        x: i,
        barRods: [BarChartRodData(
          toY: hours[i],
          color: DowntimeReason.values[i].color,
          width: 22,
          borderRadius: BorderRadius.circular(6),
        )],
      )),
    ));
  }
}

class _DaysChart extends StatelessWidget {
  final List<Incident> incidents;
  const _DaysChart({required this.incidents});
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final days = List.generate(14, (i) => DateTime(now.year, now.month, now.day).subtract(Duration(days: 13 - i)));
    final maxY = 5.0 + days.map((d) => incidents.where((i) =>
        i.ts.isAfter(d) && i.ts.isBefore(d.add(const Duration(days: 1)))).length).reduce((a, b) => a > b ? a : b).toDouble();

    return BarChart(BarChartData(
      alignment: BarChartAlignment.spaceAround,
      maxY: maxY * 1.15,
      gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => const FlLine(color: Color(0x0FFFFFFF))),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true,
          getTitlesWidget: (v, meta) {
            final i = v.toInt();
            if (i < 0 || i >= days.length) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(DateFormat('dd.MM').format(days[i]), style: const TextStyle(fontSize: 9, color: AppColors.mut)),
            );
          },
        )),
      ),
      barGroups: List.generate(days.length, (i) {
        final day = days[i];
        final counts = IncidentType.values.map((t) => incidents.where((inc) =>
            inc.type == t && inc.ts.isAfter(day) && inc.ts.isBefore(day.add(const Duration(days: 1)))).length).toList();
        double bottom = 0;
        final rods = <BarChartRodData>[];
        for (var k = 0; k < counts.length; k++) {
          if (counts[k] > 0) {
            rods.add(BarChartRodData(
              toY: bottom + counts[k],
              fromY: bottom,
              color: IncidentType.values[k].color,
              width: 18,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
            ));
            bottom += counts[k];
          }
        }
        return BarChartGroupData(x: i, barRods: rods, barsSpace: 2);
      }),
    ));
  }
}

class _TopDowntimeCard extends StatelessWidget {
  final AppDatabase db;
  final int days;
  final String title;
  const _TopDowntimeCard({required this.db, required this.days, required this.title});

  @override
  Widget build(BuildContext context) {
    final data = db.downtimeByRide(days).take(5).toList();
    final max = data.isEmpty ? 1.0 : data.first.total;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.timer_outlined, size: 16, color: AppColors.mut),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          if (data.isNotEmpty) Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
            decoration: BoxDecoration(color: AppColors.panel2, borderRadius: BorderRadius.circular(99)),
            child: Text('топ-${data.length}', style: const TextStyle(fontSize: 11, color: AppColors.mut, fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 14),
        if (data.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 26),
            child: Center(child: Text('За период простоев не зафиксировано', style: TextStyle(color: AppColors.dim, fontSize: 12.5))),
          )
        else
          ...List.generate(data.length, (i) {
            final d = data[i];
            final ride = db.rideById(d.rideId);
            final pct = (d.total / max).clamp(0.04, 1.0);
            return Padding(
              padding: EdgeInsets.only(bottom: i == data.length - 1 ? 0 : 12),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 26, height: 26,
                  decoration: BoxDecoration(
                    color: i < 3 ? AppColors.amb.withValues(alpha:0.14) : AppColors.panel2,
                    border: Border.all(color: i < 3 ? AppColors.amb.withValues(alpha:0.35) : AppColors.line2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(child: Text('${i + 1}', style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700,
                    color: i < 3 ? AppColors.amb2 : AppColors.mut,
                  ))),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(ride?.name ?? '—', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                    Text('${d.total.toStringAsFixed(1)} ч', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.amb2)),
                  ]),
                  const SizedBox(height: 2),
                  Text(db.ridePath(d.rideId), style: const TextStyle(fontSize: 11.5, color: AppColors.dim)),
                  const SizedBox(height: 7),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: pct.toDouble(),
                      minHeight: 6,
                      backgroundColor: const Color(0xFF0E1420),
                      valueColor: const AlwaysStoppedAnimation(Color(0xFFFF9F43)),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Wrap(spacing: 6, runSpacing: 6, children: d.byReason.entries
                      .where((e) => e.value > 0)
                      .map((e) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: e.key.color.withValues(alpha:0.1),
                              border: Border.all(color: e.key.color.withValues(alpha:0.27)),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text('${e.key.label}: ${e.value.toStringAsFixed(1)} ч', style: TextStyle(
                              fontSize: 10.5, fontWeight: FontWeight.w600, color: e.key.color,
                            )),
                          )).toList()),
                ])),
              ]),
            );
          }),
      ]),
    );
  }
}
