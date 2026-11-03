import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'data/app_database.dart';
import 'screens/home_shell.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = AppDatabase();
  await db.load();
  runApp(ChangeNotifierProvider.value(value: db, child: const AttraControlApp()));
}

class AttraControlApp extends StatelessWidget {
  const AttraControlApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'АттраКонтроль',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: const HomeShell(),
    );
  }
}