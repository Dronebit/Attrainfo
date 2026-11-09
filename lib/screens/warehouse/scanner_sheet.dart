import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback, rootBundle;
import 'package:permission_handler/permission_handler.dart';
import 'package:wxscan_live/wxscan_live.dart';
import 'package:wxscan/wxscan.dart'; // Для использования Scanner.init() если он есть, иначе грузим через rootBundle

import '../../data/app_database.dart';
import '../../models/inventory.dart';
import '../../theme.dart';

class AppScanResult {
  final String raw;
  final ScanKind kind;
  final String code;
  const AppScanResult(this.raw, this.kind, this.code);
}

enum ScanKind { location, item, unknown }

Future<AppScanResult?> showScannerSheet(
  BuildContext context,
  AppDatabase db,
) {
  return showModalBottomSheet<AppScanResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ScannerSheet(db: db),
  );
}

class _ScannerSheet extends StatefulWidget {
  final AppDatabase db;
  const _ScannerSheet({required this.db});

  @override
  State<_ScannerSheet> createState() => _ScannerSheetState();
}

class _ScannerSheetState extends State<_ScannerSheet> with WidgetsBindingObserver {
  WxScanController? _controller;
  StreamSubscription<ScanOutcome>? _sub;
  
  bool _isProcessing = false;
  String? _rawCodeString;
  InventoryItem? _foundItem;
  StorageLocation? _foundLoc;

  // Результаты текущего кадра для отрисовки AR-рамок
  ScanOutcome? _lastFrame;
  
  bool _hasTorch = false;
  String? _initError;
  bool _initializing = true;
  
  DateTime _lastHaptic = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _boot();
  }

  Future<void> _boot() async {
    try {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (mounted) {
          setState(() {
            _initializing = false;
            _initError = 'Нет разрешения на камеру.\nНастройки → Приложения → АттраКонтроль → Камера';
          });
        }
        return;
      }

      // Загружаем модели из assets (как в официальном примере Scanner.init())
      final detectModel = await _loadAsset('assets/models/detect.tflite');
      final srModel = await _loadAsset('assets/models/sr.tflite');

      final controller = WxScanController(resolution: WxResolution.p720);
      await controller.initialize(
        detectModel: detectModel,
        srModel: srModel,
      );

      final hasTorch = await controller.hasTorch();
      
      if (!mounted) {
        controller.dispose();
        return;
      }

      controller.addListener(_onControllerChanged);
      _sub = controller.scans.listen(_onFrame);

      setState(() {
        _controller = controller;
        _hasTorch = hasTorch;
        _initializing = false;
        _initError = controller.value.nativeReady ? null : 'Ошибка нативного сканера';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _initError = 'Ошибка инициализации: $e';
      });
    }
  }

  Future<Uint8List> _loadAsset(String path) async {
    final data = await rootBundle.load(path);
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  void _onFrame(ScanOutcome frame) {
    if (!mounted || _isProcessing) return;

    setState(() => _lastFrame = frame);

    if (frame.results.isEmpty) return;

    // Берем первый валидный результат
    final valid = frame.results.first;
    if (valid.text.isEmpty) return;

    final now = DateTime.now();
    if (now.difference(_lastHaptic).inMilliseconds > 800) {
      _lastHaptic = now;
      HapticFeedback.mediumImpact();
    }

    final raw = valid.text;
    String searchCode = raw;
    ScanKind kind = ScanKind.unknown;

    if (raw.startsWith('LOC:')) {
      searchCode = raw.substring(4);
      kind = ScanKind.location;
    } else if (raw.startsWith('SKU:')) {
      searchCode = raw.substring(4);
      kind = ScanKind.item;
    }

    InventoryItem? item;
    StorageLocation? loc;

    if (kind == ScanKind.location) {
      loc = widget.db.storageLocations.where((l) => l.code.toLowerCase() == searchCode.toLowerCase()).firstOrNull;
    } else if (kind == ScanKind.item) {
      item = widget.db.inventoryItems.where((i) => i.kind == InventoryItemKind.item && i.sku.toLowerCase() == searchCode.toLowerCase()).firstOrNull;
    } else {
      loc = widget.db.storageLocations.where((l) => l.code.toLowerCase() == searchCode.toLowerCase()).firstOrNull;
      if (loc == null) {
        item = widget.db.inventoryItems.where((i) => i.kind == InventoryItemKind.item && i.sku.toLowerCase() == searchCode.toLowerCase()).firstOrNull;
      }
    }

    // Фиксируем результат
    setState(() {
      _isProcessing = true;
      _rawCodeString = raw;
      _foundItem = item;
      _foundLoc = loc;
    });
  }

  void _resetScanner() {
    setState(() {
      _isProcessing = false;
      _rawCodeString = null;
      _foundItem = null;
      _foundLoc = null;
      _lastFrame = null;
    });
  }

  void _confirmSelection() {
    if (_rawCodeString == null) return;
    ScanKind kind = ScanKind.unknown;
    String code = _rawCodeString!;
    if (code.startsWith('LOC:')) {
      kind = ScanKind.location;
      code = code.substring(4);
    } else if (code.startsWith('SKU:')) {
      kind = ScanKind.item;
      code = code.substring(4);
    }
    Navigator.pop(context, AppScanResult(_rawCodeString!, kind, code));
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
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.amb,
              foregroundColor: const Color(0xFF1C1204),
            ),
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (ok == null || ok.isEmpty) return;
    if (!mounted) return;
    Navigator.pop(context, AppScanResult(
      ok,
      ok.startsWith('LOC:') ? ScanKind.location : (ok.startsWith('SKU:') ? ScanKind.item : ScanKind.unknown),
      ok.replaceAll(RegExp(r'^(LOC:|SKU:)'), ''),
    ));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _controller?.setScanning(!_isProcessing);
    } else {
      _controller?.setScanning(false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    _controller?.removeListener(_onControllerChanged);
    _controller?.dispose();
    super.dispose();
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
              const Icon(Icons.qr_code_scanner, size: 20, color: AppColors.amb),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Сканирование', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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
          _buildBottomPanel(),
        ]),
      ),
    );
  }

  Widget _buildCameraArea() {
    if (_initError != null) {
      return Container(
        color: const Color(0xFF0E1420),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.videocam_off, size: 48, color: AppColors.red),
            const SizedBox(height: 12),
            const Text('Камера недоступна', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(_initError!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: AppColors.mut)),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppColors.amb, foregroundColor: const Color(0xFF1C1204)),
              onPressed: _manualInput,
              icon: const Icon(Icons.keyboard, size: 16),
              label: const Text('Ввести код вручную'),
            ),
          ],
        ),
      );
    }

    if (_initializing || _controller == null) {
      return const ColoredBox(
        color: Color(0xFF0E1420),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return ValueListenableBuilder<WxScanValue>(
      valueListenable: _controller!,
      builder: (context, value, _) {
        final previewSize = value.previewSize;
        if (previewSize == null) {
          return const ColoredBox(
            color: Color(0xFF0E1420),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            // 1. Превью с корректным поворотом
            ClipRect(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: previewSize.rotatedWidth.toDouble(),
                  height: previewSize.rotatedHeight.toDouble(),
                  child: RotatedBox(
                    quarterTurns: previewSize.quarterTurns,
                    child: SizedBox(
                      width: previewSize.width.toDouble(),
                      height: previewSize.height.toDouble(),
                      child: WxScanPreview(controller: _controller!),
                    ),
                  ),
                ),
              ),
            ),

            // 2. AR-рамки (отрисовка по найденным кодам)
            if (_lastFrame != null && _lastFrame!.results.isNotEmpty)
              IgnorePointer(
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _CodeMarkerPainter(frame: _lastFrame!),
                ),
              ),

            // 3. Прицел (если ничего не найдено)
            if (!_isProcessing && (_lastFrame == null || _lastFrame!.results.isEmpty))
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

            // 4. Всплывающая карточка
            if (_isProcessing)
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: _buildFloatingCard(),
              ),
          ],
        );
      },
    );
  }

  Widget _buildBottomPanel() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(children: [
        Text(
          _isProcessing
              ? 'Подтвердите выбор'
              : (_initError != null ? 'Введите код вручную' : 'Наведите на QR полки или позиции'),
          style: TextStyle(
            fontSize: 12,
            color: _isProcessing ? AppColors.amb : AppColors.mut,
            fontWeight: _isProcessing ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        const SizedBox(height: 10),
        Row(children: [
          if (_initError == null && !_initializing && _hasTorch) ...[
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ValueListenableBuilder<WxScanValue>(
                  valueListenable: _controller!,
                  builder: (context, value, _) {
                    return OutlinedButton.icon(
                      onPressed: () => _controller!.setTorch(!value.torchEnabled),
                      icon: Icon(value.torchEnabled ? Icons.flashlight_on : Icons.flashlight_off, size: 16),
                      label: Text(value.torchEnabled ? 'Свет вкл' : 'Свет'),
                    );
                  },
                ),
              ),
            ),
          ],
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _isProcessing ? _resetScanner : _manualInput,
              icon: Icon(_isProcessing ? Icons.refresh : Icons.keyboard, size: 16),
              label: Text(_isProcessing ? 'Сканировать другое' : 'Ввести вручную'),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _buildFloatingCard() {
    final isFound = _foundItem != null || _foundLoc != null;
    final title = _foundItem?.name ?? _foundLoc?.name ?? 'Не найдено в базе';

    final subtitle = _foundItem != null
        ? '${_foundItem!.sku} · Остаток: ${widget.db.stockTotal(_foundItem!.id)} ${_foundItem!.unit.label}'
        : (_foundLoc != null ? 'Локация: ${_foundLoc!.code}' : (_rawCodeString ?? 'Неизвестный код'));

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isFound ? AppColors.grn.withValues(alpha: 0.5) : AppColors.red.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Icon(
              isFound ? (_foundLoc != null ? Icons.inventory_2_outlined : Icons.check_circle_outline) : Icons.error_outline,
              color: isFound ? AppColors.grn : AppColors.red,
              size: 24,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.dim), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ]),
          if (isFound) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.amb,
                  foregroundColor: const Color(0xFF1C1204),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onPressed: _confirmSelection,
                child: const Text('Выбрать', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Отрисовка рамок (полностью адаптировано из официального _CodeMarkerPainter)
// ═══════════════════════════════════════════════════════════════════

class _CodeMarkerPainter extends CustomPainter {
  final ScanOutcome frame;

  _CodeMarkerPainter({required this.frame});

  @override
  void paint(Canvas canvas, Size size) {
    if (frame.results.isEmpty || frame.width == 0 || frame.height == 0) return;

    // Вычисляем масштаб для BoxFit.cover
    final scale = math.max(size.width / frame.width, size.height / frame.height);
    final dx = (size.width - frame.width * scale) / 2;
    final dy = (size.height - frame.height * scale) / 2;

    final glowPaint = Paint()
      ..color = AppColors.grn.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    final fillPaint = Paint()
      ..color = AppColors.grn.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = AppColors.grn
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    for (final r in frame.results) {
      final path = Path();
      
      // Используем dx и dy, как в официальном примере
      for (var i = 0; i < r.corners.length; i++) {
        final p = Offset(
          r.corners[i].dx * scale + dx,
          r.corners[i].dy * scale + dy,
        );
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      path.close();

      canvas.drawPath(path, fillPaint);
      canvas.drawPath(path, glowPaint);
      canvas.drawPath(path, borderPaint);

      // Рисуем AR-уголки поверх прямоугольника
      final rect = path.getBounds();
      _drawCorner(canvas, rect.topLeft, 1, 1, borderPaint);
      _drawCorner(canvas, rect.topRight, -1, 1, borderPaint);
      _drawCorner(canvas, rect.bottomLeft, 1, -1, borderPaint);
      _drawCorner(canvas, rect.bottomRight, -1, -1, borderPaint);
    }
  }

  void _drawCorner(Canvas canvas, Offset p, double dx, double dy, Paint paint) {
    const len = 15.0;
    canvas.drawLine(p, p + Offset(len * dx, 0), paint);
    canvas.drawLine(p, p + Offset(0, len * dy), paint);
  }

  @override
  bool shouldRepaint(covariant _CodeMarkerPainter oldDelegate) {
    return oldDelegate.frame != frame;
  }
}