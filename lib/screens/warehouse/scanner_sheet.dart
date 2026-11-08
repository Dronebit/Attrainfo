import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
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

class _ScannerSheetState extends State<_ScannerSheet> {
  bool _handled = false;
  bool _isTorchOn = false;
  
  // Ключ для управления встроенной камерой (включая фонарик)
  final GlobalKey<ReaderWidgetState> _readerKey = GlobalKey<ReaderWidgetState>();

  void _onScan(Code code) {
    if (_handled) return;
    if (!code.isValid || code.text == null || code.text!.isEmpty) return;
    
    final raw = code.text!;
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
          // 1. Наш кастомный заголовок (шторка)
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
              const Icon(Icons.qr_code_scanner, size: 20, color: AppColors.amb),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Сканирование',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),
          
          // 2. Зона камеры с нашей кастомной рамкой
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Сама камера (чистый видеопоток без UI ZXing)
                    ReaderWidget(
                      key: _readerKey,
                      onScan: _onScan,
                      showScannerOverlay: false, // выкл рамку ZXing
                      showFlashlight: false,     // выкл кнопку ZXing
                      showGallery: false,        // выкл галерею ZXing
                      showToggleCamera: false,   // выкл переключение камеры
                    ),
                    
                    // Наша кастомная золотая рамка
                    Container(
                      width: 250,
                      height: 250,
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.amb, width: 3),
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 3. Наши кастомные кнопки внизу
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(children: [
              const Text(
                'Наведите на QR полки или позиции',
                style: TextStyle(fontSize: 12, color: AppColors.mut),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // Управляем вспышкой через GlobalKey
                      setState(() => _isTorchOn = !_isTorchOn);
                      _readerKey.currentState?.toggleTorch();
                    },
                    icon: Icon(
                      _isTorchOn ? Icons.flashlight_on : Icons.flashlight_off,
                      size: 16,
                    ),
                    label: Text(_isTorchOn ? 'Свет вкл' : 'Свет'),
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
}