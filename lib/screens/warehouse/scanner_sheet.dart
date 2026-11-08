import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../theme.dart';

// ─────────────────────────────────────────────────────────────
// Результат сканирования
// ─────────────────────────────────────────────────────────────

class ScanResult {
  final String raw;
  final ScanKind kind;
  final String code;
  const ScanResult(this.raw, this.kind, this.code);
}

enum ScanKind { location, item, unknown }

// ─────────────────────────────────────────────────────────────
// Публичный API
// ─────────────────────────────────────────────────────────────

Future<ScanResult?> showScannerSheet(BuildContext context) {
  return showModalBottomSheet<ScanResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _ScannerSheet(),
  );
}

// ─────────────────────────────────────────────────────────────
// Сам bottom sheet со сканером
// ─────────────────────────────────────────────────────────────

class _ScannerSheet extends StatefulWidget {
  const _ScannerSheet();
  @override
  State<_ScannerSheet> createState() => _ScannerSheetState();
}

class _ScannerSheetState extends State<_ScannerSheet> {
  final _ctrl = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );
  bool _handled = false;
  bool _torchOn = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    if (capture.barcodes.isEmpty) return;
    final raw = capture.barcodes.first.rawValue;
    if (raw == null || raw.isEmpty) return;

    _handled = true;

    ScanKind kind = ScanKind.unknown;
    String code = raw;
    if (raw.startsWith('LOC:')) {
      kind = ScanKind.location;
      code = raw.substring(4);
    } else if (raw.startsWith('SKU:')) {
      kind = ScanKind.item;
      code = raw.substring(4);
    }

    Navigator.pop(context, ScanResult(raw, kind, code));
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

    ScanKind kind = ScanKind.unknown;
    String code = ok;
    if (ok.startsWith('LOC:')) {
      kind = ScanKind.location;
      code = ok.substring(4);
    } else if (ok.startsWith('SKU:')) {
      kind = ScanKind.item;
      code = ok.substring(4);
    }

    Navigator.pop(context, ScanResult(ok, kind, code));
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
                child: Stack(children: [
                  MobileScanner(
                    controller: _ctrl,
                    onDetect: _onDetect,
                  ),
                  // Рамка по центру
                  Center(
                    child: Container(
                      width: 250,
                      height: 250,
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: AppColors.amb, width: 3),
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(children: [
              const Text(
                'Наведите на QR полки или позиции',
                style: TextStyle(fontSize: 12, color: AppColors.mut),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() {
                      _torchOn = !_torchOn;
                      _ctrl.toggleTorch();
                    }),
                    icon: Icon(
                      _torchOn ? Icons.flashlight_on : Icons.flashlight_off,
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
}