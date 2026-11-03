import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/app_database.dart';
import '../theme.dart';
import 'dashboard_screen.dart';
import 'incidents_screen.dart';
import 'downtime_screen.dart';
import 'infrastructure_screen.dart';
import 'technicians_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _pages = [
    ('Панель управления', 'Сводная статистика отказов, дефектов и простоев', Icons.dashboard_outlined),
    ('События и отказы', 'Поломки · дефекты · посторонние шумы', Icons.warning_amber_rounded),
    ('Простои', 'Документирование простоя и ввода в эксплуатацию', Icons.timer_outlined),
    ('Инфраструктура', 'Города · локации · парки · аттракционы', Icons.layers_outlined),
    ('Сервисная служба', 'Сотрудники и назначения', Icons.people_outline),
  ];

  @override
  Widget build(BuildContext context) {
    final db = context.watch<AppDatabase>();
  
    // Примечание: см. enum IncidentStatus — здесь упрощённо
    final screens = const [
      DashboardScreen(),
      IncidentsScreen(),
      DowntimeScreen(),
      InfrastructureScreen(),
      TechniciansScreen(),
    ];

    final isWide = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      body: SafeArea(
        child: isWide
            ? Row(children: [
                _Sidebar(
                  index: _index,
                  onTap: (i) => setState(() => _index = i),
                  pages: _pages,
                ),
                Expanded(child: _MainArea(
                  title: _pages[_index].$1,
                  subtitle: _pages[_index].$2,
                  child: screens[_index],
                )),
              ])
            : Column(children: [
                _TopNavBar(
                  index: _index,
                  onTap: (i) => setState(() => _index = i),
                  pages: _pages,
                ),
                Expanded(child: _MainArea(
                  title: _pages[_index].$1,
                  subtitle: _pages[_index].$2,
                  child: screens[_index],
                )),
              ]),
      ),
    );
  }
}

// Простая обёртка, чтобы не тянуть enum из models в этот файл
class IncidentStatusLite { static const resolved = 'resolved'; }

class _MainArea extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  const _MainArea({required this.title, required this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        decoration: const BoxDecoration(
          color: Color(0xFF0C1016),
          border: Border(bottom: BorderSide(color: AppColors.line)),
        ),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
            Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.mut)),
          ])),
        ]),
      ),
      Expanded(child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 22, 28, 46),
        child: child,
      )),
    ]);
  }
}

class _Sidebar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  final List<(String, String, IconData)> pages;
  const _Sidebar({required this.index, required this.onTap, required this.pages});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 252,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Color(0xFF101823), Color(0xFF0B0F16)],
        ),
        border: Border(right: BorderSide(color: AppColors.line)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 18),
      child: Column(children: [
        const _Logo(),
        const SizedBox(height: 14),
        ...List.generate(pages.length, (i) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: _NavItem(
            icon: pages[i].$3,
            label: pages[i].$1,
            active: i == index,
            onTap: () => onTap(i),
          ),
        )),
        const Spacer(),
        TextButton.icon(
          onPressed: () => context.read<AppDatabase>().resetToSeed(),
          icon: const Icon(Icons.refresh, size: 14),
          label: const Text('Сбросить демо-данные', style: TextStyle(fontSize: 12)),
        ),
      ]),
    );
  }
}

class _TopNavBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  final List<(String, String, IconData)> pages;
  const _TopNavBar({required this.index, required this.onTap, required this.pages});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF101823),
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: List.generate(pages.length, (i) => Padding(
              padding: const EdgeInsets.only(right: 4),
              child: _NavItem(
                icon: pages[i].$3,
                label: pages[i].$1,
                active: i == index,
                onTap: () => onTap(i),
              ),
            ))),
          ),
        ),
      ]),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _NavItem({required this.icon, required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(11),
          color: active ? AppColors.amb.withOpacity(0.12) : Colors.transparent,
          border: Border.all(
            color: active ? AppColors.amb.withOpacity(0.22) : Colors.transparent,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 18, color: active ? AppColors.amb2 : AppColors.mut),
          const SizedBox(width: 11),
          Text(label, style: TextStyle(
            color: active ? AppColors.amb2 : AppColors.mut,
            fontWeight: FontWeight.w500,
          )),
        ]),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 42, height: 42,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: AppColors.amb.withOpacity(0.12),
          border: Border.all(color: AppColors.amb.withOpacity(0.25)),
        ),
        child: const Icon(Icons.attractions, color: AppColors.amb, size: 24),
      ),
      const SizedBox(width: 11),
      const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('АттраКонтроль', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
        Text('учёт отказов и простоев', style: TextStyle(fontSize: 11, color: AppColors.dim)),
      ]),
    ]);
  }
}