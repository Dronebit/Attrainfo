import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/debug_log.dart';
import '../data/nfc_helper.dart';
import '../theme.dart';

class DebugConsoleScreen extends StatefulWidget {
  const DebugConsoleScreen({super.key});
  @override
  State<DebugConsoleScreen> createState() => _DebugConsoleScreenState();
}

class _DebugConsoleScreenState extends State<DebugConsoleScreen> {
  bool _showInfo = true;
  bool _showWarn = true;
  bool _showError = true;
  bool _showNfc = true;

  Color _colorFor(LogLevel l) => switch (l) {
        LogLevel.info => AppColors.mut,
        LogLevel.warn => AppColors.amb,
        LogLevel.error => AppColors.red,
        LogLevel.nfc => AppColors.cyn,
      };

  bool _visible(LogEntry e) => switch (e.level) {
        LogLevel.info => _showInfo,
        LogLevel.warn => _showWarn,
        LogLevel.error => _showError,
        LogLevel.nfc => _showNfc,
      };

  Future<void> _testNfc() async {
    DebugLog.instance.nfc('=== manual NFC test ===');
    try {
      final uid = await NfcHelper.scanBadge();
      DebugLog.instance.nfc('manual result: ${uid ?? "(null)"}');
    } catch (e) {
      DebugLog.instance.error('manual test error: $e');
    }
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: DebugLog.instance.dump()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Логи скопированы в буфер обмена'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: DebugLog.instance,
      builder: (context, _) {
        final all = DebugLog.instance.entries;
        final filtered = all.where(_visible).toList();

        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Header row
          Row(children: [
            const Text('Консоль',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.panel2,
                border: Border.all(color: AppColors.line2),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text('${filtered.length} / ${all.length}',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.mut)),
            ),
            const Spacer(),
            _iconBtn(
              icon: Icons.wifi_tethering,
              label: 'NFC',
              color: AppColors.cyn,
              onTap: _testNfc,
            ),
            const SizedBox(width: 6),
            _iconBtn(
              icon: Icons.copy,
              label: 'Copy',
              onTap: _copy,
            ),
            const SizedBox(width: 6),
            _iconBtn(
              icon: Icons.delete_outline,
              label: 'Clear',
              color: AppColors.red,
              onTap: () => DebugLog.instance.clear(),
            ),
          ]),
          const SizedBox(height: 10),

          // Filters
          Wrap(spacing: 6, runSpacing: 6, children: [
            _filter('INFO', _showInfo, AppColors.mut,
                () => setState(() => _showInfo = !_showInfo)),
            _filter('WARN', _showWarn, AppColors.amb,
                () => setState(() => _showWarn = !_showWarn)),
            _filter('ERR', _showError, AppColors.red,
                () => setState(() => _showError = !_showError)),
            _filter('NFC', _showNfc, AppColors.cyn,
                () => setState(() => _showNfc = !_showNfc)),
          ]),
          const SizedBox(height: 10),

          // Log list
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0A0E14),
                border: Border.all(color: AppColors.line),
                borderRadius: BorderRadius.circular(10),
              ),
              child: filtered.isEmpty
                  ? const Center(
                      child: Text('Логов нет',
                          style: TextStyle(color: AppColors.dim, fontSize: 12)))
                  : ListView.builder(
                      reverse: false,
                      padding: const EdgeInsets.all(10),
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) {
                        final e = filtered[i];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: SelectableText(
                            e.formatted,
                            style: TextStyle(
                              fontSize: 11,
                              fontFamily: 'monospace',
                              color: _colorFor(e.level),
                              height: 1.4,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ]);
      },
    );
  }

  Widget _iconBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.line2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: color ?? AppColors.mut),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(fontSize: 11.5, color: color ?? AppColors.mut)),
        ]),
      ),
    );
  }

  Widget _filter(String label, bool active, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.15) : Colors.transparent,
          border: Border.all(
            color: active ? color.withValues(alpha: 0.5) : AppColors.line2,
          ),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: active ? color : AppColors.dim,
            )),
      ),
    );
  }
}
