import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'data/app_database.dart';
import 'data/debug_log.dart';
import 'screens/home/home_shell.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    DebugLog.instance.error('FlutterError: ${details.exceptionAsString()}');
    FlutterError.presentError(details);
  };

  runZonedGuarded(() async {
    final db = AppDatabase();
    await db.load();
    runApp(ChangeNotifierProvider.value(
      value: db,
      child: const AttraControlApp(),
    ));
  }, (error, stack) {
    DebugLog.instance.error('Uncaught: $error');
    runApp(_ErrorApp(error: error, stack: stack));
  });
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

class _ErrorApp extends StatelessWidget {
  final Object error;
  final StackTrace stack;
  const _ErrorApp({required this.error, required this.stack});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF0C1016),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('⚠️ Ошибка при запуске',
                    style: TextStyle(
                        fontSize: 20,
                        color: Color(0xFFFF5D55),
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 14),
                const Text('Что упало:',
                    style: TextStyle(fontSize: 12, color: Color(0xFF93A1B8))),
                const SizedBox(height: 4),
                SelectableText('$error',
                    style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white,
                        fontFamily: 'monospace')),
                const SizedBox(height: 16),
                const Text('Стек (первые 30 строк):',
                    style: TextStyle(fontSize: 12, color: Color(0xFF93A1B8))),
                const SizedBox(height: 4),
                SelectableText(
                  stack.toString().split('\n').take(30).join('\n'),
                  style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF93A1B8),
                      fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}