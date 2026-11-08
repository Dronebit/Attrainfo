import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../data/debug_log.dart';
import '../../theme.dart';

class ScanResult {
  final String raw;
  final ScanKind kind;
  final String code;
  const ScanResult(this.raw, this.kind, this.code);
}

enum ScanKind { location, item, unknown }

Future<ScanResult?> showScannerSheet(BuildContext context) {
  return showModalBottomSheet<ScanResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _ScannerSheet(),
  );
}

class _ScannerSheet extends StatefulWidget {
  const _ScannerSheet();
  @override
  State<_ScannerSheet> createState() => _ScannerSheetState();
}

class _ScannerSheetState extends State<_ScannerSheet>
    with WidgetsBindingObserver {
  final _ctrl = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    autoStart: false,          // стартуем явно — чтобы поймать ошибку
  );

  bool _handled = false;
  bool _torchOn = false;
  bool _cameraReady = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    DebugLog.instance.nfc('--- Scanner: initState ---');
    _startCamera();
  }

  Future<void> _startCamera() async {
    DebugLog.instance.nfc('scanner.start: begin');
    try {
      await _ctrl.start();
      DebugLog.instance.nfc('scanner.start: OK');
      if (mounted) setState(() => _cameraReady = true);
    } catch (e, st) {
      final short = st.toString().split('\n').take(3).join(' | ');
      DebugLog.instance.error('scanner.start failed: $e');
      DebugLog.instance.error('  stack: $short');
      if (mounted) {
        setState(() {
          _errorText = e.toString();
          _cameraReady = false;
        });
      }
    }
  }

  @override
  void dispose() {
    DebugLog.instance.nfc('scanner.dispose');
    WidgetsBinding.instance.removeObserver(this);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    DebugLog.instance.nfc('scanner.lifecycle: $state');
    switch (state) {
      case AppLifecycleState.resumed:
        _startCamera();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _ctrl.stop().catchError((e) {
          DebugLog.instance.warn('scanner.stop error: $e');
        });
        break;
      case AppLifecycleState.hidden:
        break;
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    if (capture.barcodes.isEmpty) return;
    final raw = capture.barcodes.first.rawValue;
    if (raw == null || raw.isEmpty) return;
    DebugLog.instance.nfc('scanner.detected: $raw');
    _handled = true;
    Navigator.pop(context, _makeResult(raw));
  }

  ScanResult _makeResult(String raw) {
    if (raw.startsWith('LOC:')) {
      return ScanResult(raw, ScanKind.location, raw.substring(4));
    }
    if (raw.startsWith('SKU:')) {
      return ScanResult(raw, ScanKind.item, raw.substring(4));
    }
    return ScanResult(raw, ScanKind.unknown, raw);
  }

  Future<void> _manualInput() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: const Text('Ввести код вручную'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Код',
            hintText: 'P1-R2-P3 или BR-6204',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.amb,
                foregroundColor: const Color(0xFF1C1204)),
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (ok == null || ok.isEmpty) return;
    if (!mounted) return;
    Navigator.pop(context, _makeResult(ok));
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.95,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: AppColors.panel,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.line2,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(children: [
              const Icon(Icons.qr_code_scanner,
                  size: 20, color: AppColors.amb),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Сканирование',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _buildCameraArea(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(children: [
              Text(
                _cameraReady
                    ? 'Наведите на QR полки или позиции'
                    : (_errorText == null
                        ? 'Запуск камеры…'
                        : 'Камера недоступна'),
                style: TextStyle(
                    fontSize: 12,
                    color: _cameraReady ? AppColors.mut : AppColors.amb),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _cameraReady
                        ? () {
                            setState(() => _torchOn = !_torchOn);
                            _ctrl.toggleTorch();
                          }
                        : null,
                    icon: Icon(
                      _torchOn
                          ? Icons.flashlight_on
                          : Icons.flashlight_off,
                      size: 16,
                    ),
                    label: Text(_torchOn ? 'Свет вкл' : 'Свет'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _manualInput,
                    icon: const Icon(Icons.keyboard, size: 16),
                    label: const Text('Вручную'),
                  ),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildCameraArea() {
    if (_errorText != null) {
      return _errorPanel();
    }
    return Stack(children: [
      MobileScanner(
        controller: _ctrl,
        onDetect: _onDetect,
        errorBuilder: (context, error,child) {
          DebugLog.instance.error(
              'MobileScanner.error: ${error.errorCode} — ${error.errorDetails?.message ?? ""}');
          return _errorPanelWith(error);
        },
      ),
      // Рамка
      Center(
        child: Container(
          width: 250,
          height: 250,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.amb, width: 3),
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    ]);
  }

  Widget _errorPanel() {
    return Container(
      color: const Color(0xFF0E1420),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.videocam_off, size: 48, color: AppColors.red),
          const SizedBox(height: 12),
          const Text('Не удалось запустить камеру',
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text(
            'Проверьте разрешение камеры в настройках Android:\n'
            'Настройки → Приложения → АттраКонтроль → Разрешения → Камера',
            style: TextStyle(fontSize: 11.5, color: AppColors.mut),
            textAlign: TextAlign.center,
          ),
          if (_errorText != null) ...[
            const SizedBox(height: 10),
            SelectableText(
              _errorText!,
              style: const TextStyle(
                  fontSize: 9.5,
                  fontFamily: 'monospace',
                  color: AppColors.dim),
              maxLines: 4,
            ),
          ],
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _errorText = null;
                    _cameraReady = false;
                  });
                  _startCamera();
                },
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Повторить'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.amb,
                    foregroundColor: const Color(0xFF1C1204)),
                onPressed: _manualInput,
                icon: const Icon(Icons.keyboard, size: 16),
                label: const Text('Ввести код'),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _errorPanelWith(MobileScannerException error) {
    return Container(
      color: const Color(0xFF0E1420),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.videocam_off, size: 48, color: AppColors.red),
          const SizedBox(height: 12),
          const Text('Ошибка камеры',
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            error.errorCode.name,
            style: const TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                color: AppColors.amb),
          ),
          if (error.errorDetails?.message != null) ...[
            const SizedBox(height: 6),
            Text(error.errorDetails!.message!,
                style: const TextStyle(fontSize: 11, color: AppColors.mut),
                textAlign: TextAlign.center),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.amb,
                foregroundColor: const Color(0xFF1C1204)),
            onPressed: _manualInput,
            icon: const Icon(Icons.keyboard, size: 16),
            label: const Text('Ввести код вручную'),
          ),
        ],
      ),
    );
  }
}