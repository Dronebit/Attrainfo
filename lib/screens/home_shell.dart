import 'package:flutter/material.dart';
import '../theme.dart';
import 'admin_panel_screen.dart';
import 'dashboard_screen.dart';
import 'debug_console_screen.dart';
import 'downtime_screen.dart';
import 'incidents_screen.dart';
import 'infrastructure_screen.dart';
import 'operator_screen.dart';
import 'operators_screen.dart';
import 'technicians_screen.dart';
import 'warehouse/warehouse_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _tabs = <_TabDef>[
    _TabDef('Дашборд', Icons.dashboard_outlined, Icons.dashboard),
    _TabDef('События', Icons.warning_amber_outlined, Icons.warning_amber),
    _TabDef('Структура', Icons.account_tree_outlined, Icons.account_tree),
    _TabDef('Механики', Icons.build_outlined, Icons.build),
    _TabDef('Смена', Icons.play_circle_outline, Icons.play_circle),
    _TabDef('Склад', Icons.inventory_2_outlined, Icons.inventory_2),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_tabs[_index].title),
        actions: [
          Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.menu),
              tooltip: 'Меню',
              onPressed: () => Scaffold.of(ctx).openDrawer(),
            ),
          ),
        ],
      ),
      drawer: const _HomeDrawer(),
      body: SafeArea(
        child: IndexedStack(
          index: _index,
          children: const [
            _ScrollablePage(child: DashboardScreen()),
            _ScrollablePage(child: IncidentsScreen()),
            _ScrollablePage(child: InfrastructureScreen()),
            _ScrollablePage(child: TechniciansScreen()),
            _ScrollablePage(child: OperatorScreen()),
            _ScrollablePage(child: WarehouseScreen()),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final t in _tabs)
            NavigationDestination(
              icon: Icon(t.icon),
              selectedIcon: Icon(t.selectedIcon),
              label: t.title,
            ),
        ],
      ),
    );
  }
}

class _TabDef {
  final String title;
  final IconData icon;
  final IconData selectedIcon;
  const _TabDef(this.title, this.icon, this.selectedIcon);
}

/// Обёртка для скроллящихся экранов: даёт padding и вертикальный скролл,
/// потому что экраны — `Column` без собственного ScrollView.
class _ScrollablePage extends StatelessWidget {
  final Widget child;
  const _ScrollablePage({required this.child});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: child,
    );
  }
}

class _HomeDrawer extends StatelessWidget {
  const _HomeDrawer();

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: AppColors.panel),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('АттраКонтроль',
                    style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w700)),
                SizedBox(height: 4),
                Text('Учёт простоев и событий',
                    style: TextStyle(fontSize: 12, color: AppColors.dim)),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.admin_panel_settings),
            title: const Text('Админ-панель'),
            subtitle: const Text('Super / регион'),
            onTap: () {
              Navigator.pop(context);
              _push(context, 'Админ-панель', const AdminPanelScreen());
            },
          ),
          ListTile(
            leading: const Icon(Icons.support_agent),
            title: const Text('Панель админа парка'),
            subtitle: const Text('Операторы парка'),
            onTap: () {
              Navigator.pop(context);
              _push(context, 'Админ парка', const OperatorsScreen(),
                  scroll: true);
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.inventory_2_outlined),
            title: const Text('Склад ТМЦ'),
            subtitle: const Text('Позиции, остатки, операции'),
            onTap: () {
              Navigator.pop(context);
              _push(context, 'Склад ТМЦ', const WarehouseScreen(),
                  scroll: true);
            },
          ),
          ListTile(
            leading: const Icon(Icons.timer_outlined),
            title: const Text('Простои'),
            onTap: () {
              Navigator.pop(context);
              _push(context, 'Простои', const DowntimeScreen());
            },
          ),
          ListTile(
            leading: const Icon(Icons.bug_report_outlined),
            title: const Text('Логи'),
            onTap: () {
              Navigator.pop(context);
              _push(context, 'Логи', const DebugConsoleScreen());
            },
          ),
        ],
      ),
    );
  }

  void _push(BuildContext context, String title, Widget screen,
      {bool scroll = false}) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: scroll ? SingleChildScrollView(child: screen) : screen,
          ),
        ),
      ),
    ));
  }
}