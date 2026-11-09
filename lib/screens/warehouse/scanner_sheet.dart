import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback, rootBundle;
import 'package:permission_handler/permission_handler.dart';
import 'package:wxscan_live/wxscan_live.dart' as wx;

import '../../data/app_database.dart';
import '../../models/inventory.dart';
import '../../theme.dart';

// ═══════════════════════════════════════════════════════════════════
// Публичный API
// ═══════════════════════════════════════════════════════════════════

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

// ═══════════════════════════════════════════════════════════════════
// Экран сканера
// ═══════════════════════════════════════════════════════════════════

class _ScannerSheet extends StatefulWidget {
  final AppDatabase db;
  const _ScannerSheet({required this.db});

  @override
  State<_ScannerSheet> createState() => _ScannerSheetState();
}

class _ScannerSheetState extends State<_ScannerSheet>
    with WidgetsBindingObserver {
  late final wx.WxScanController _controller;

  // Состояние фиксации
  bool _isProcessing = false;
  String? _rawCodeString;
  InventoryItem? _foundItem;
  StorageLocation? _foundLoc;

  // Живые рамки
  List<wx.ScanResult> _liveResults = [];

  // Инициализация
  bool _initializing = true;
  String? _initError;
  bool _hasTorch = false; // проверяется один раз через controller.hasTorch()

  DateTime _lastHaptic = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = wx.WxScanController(resolution: wx.WxResolution.p720);
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (mounted) {
          setState(() {
            _initializing = false;
            _initError = 'Нет разрешения на камеру.\n'
                'Настройки → Приложения → АттраКонтроль → Камера';
          });
        }
        return;
      }

      final detectModel = await _loadAsset('assets/models/detect.tflite');
      final srModel = await _loadAsset('assets/models/sr.tflite');

      await _controller.initialize(
        detectModel: detectModel,
        srModel: srModel,
      );

      // Проверяем поддержку фонарика один раз
      _hasTorch = await _controller.hasTorch();

      _controller.scans.listen(_onScanFrame);

      if (mounted) setState(() => _initializing = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _initializing = false;
          _initError = 'Ошибка инициализации сканера:\n$e';
        });
      }
    }
  }

  Future<Uint8List> _loadAsset(String path) async {
    final data = await rootBundle.load(path);
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  void _onScanFrame(wx.ScanOutcome outcome) {
    if (!mounted) return;

    final results = outcome.results;

    if (!_isProcessing) {
      wx.ScanResult? valid;
      for (final r in results) {
        if (r.text.isNotEmpty) {
          valid = r;
          break;
        }
      }

      if (valid != null) {
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
          loc = widget.db.storageLocations
              .where((l) =>
                  l.code.toLowerCase() == searchCode.toLowerCase())
              .firstOrNull;
        } else if (kind == ScanKind.item) {
          item = widget.db.inventoryItems
              .where((i) =>
                  i.kind == InventoryItemKind.item &&
                  i.sku.toLowerCase() == searchCode.toLowerCase())
              .firstOrNull;
        } else {
          loc = widget.db.storageLocations
              .where((l) =>
                  l.code.toLowerCase() == searchCode.toLowerCase())
              .firstOrNull;
          if (loc == null) {
            item = widget.db.inventoryItems
                .where((i) =>
                    i.kind == InventoryItemKind.item &&
                    i.sku.toLowerCase() == searchCode.toLowerCase())
                .firstOrNull;
          }
        }

        setState(() {
          _isProcessing = true;
          _rawCodeString = raw;
          _foundItem = item;
          _foundLoc = loc;
          _liveResults = results;
        });
        return;
      }
    }

    setState(() => _liveResults = results);
  }

  void _resetScanner() {
    setState(() {
      _isProcessing = false;
      _rawCodeString = null;
      _foundItem = null;
      _foundLoc = null;
      _liveResults = [];
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

    Navigator.pop(
      context,
      AppScanResult(
        ok,
        ok.startsWith('LOC:')
            ? ScanKind.location
            : (ok.startsWith('SKU:') ? ScanKind.item : ScanKind.unknown),
        ok.replaceAll(RegExp(r'^(LOC:|SKU:)'), ''),
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _controller.setScanning(state == AppLifecycleState.resumed);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
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
          _buildBottomPanel(),
        ]),
      ),
    );
  }

  // ─── Камера ───

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
            const Text('Камера недоступна',
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(_initError!,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 12, color: AppColors.mut)),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.amb,
                foregroundColor: const Color(0xFF1C1204),
              ),
              onPressed: _manualInput,
              icon: const Icon(Icons.keyboard, size: 16),
              label: const Text('Ввести код вручную'),
            ),
          ],
        ),
      );
    }

    if (_initializing) {
      return const ColoredBox(
        color: Color(0xFF0E1420),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return ValueListenableBuilder<wx.WxScanValue>(
      valueListenable: _controller,
      builder: (context, value, _) {
        final previewSize = value.previewSize;
        if (previewSize == null) {
          return const ColoredBox(
            color: Color(0xFF0E1420),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        return LayoutBuilder(builder: (context, constraints) {
          return Stack(
            fit: StackFit.expand,
            children: [
              // Превью
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
                        child: wx.WxScanPreview(controller: _controller),
                      ),
                    ),
                  ),
                ),
              ),

              // Прицел
              if (!_isProcessing)
                Center(
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      border:
                          Border.all(color: AppColors.amb, width: 3),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),

              // AR-рамки
              if (_liveResults.isNotEmpty)
                IgnorePointer(
                  child: CustomPaint(
                    painter: _TrackingPainter(
                      results: _liveResults,
                      previewSize: previewSize,
                    ),
                  ),
                ),

              // Карточка
              if (_isProcessing)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: _buildFloatingCard(),
                ),
            ],
          );
        });
      },
    );
  }

  // ─── Нижняя панель ───

  Widget _buildBottomPanel() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(children: [
        Text(
          _isProcessing
              ? 'Подтвердите выбор'
              : (_initError != null
                  ? 'Введите код вручную'
                  : 'Наведите на QR полки или позиции'),
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
                child: ValueListenableBuilder<wx.WxScanValue>(
                  valueListenable: _controller,
                  builder: (context, value, _) {
                    return OutlinedButton.icon(
                      onPressed: () =>
                          _controller.setTorch(!value.torchEnabled),
                      icon: Icon(
                        value.torchEnabled
                            ? Icons.flashlight_on
                            : Icons.flashlight_off,
                        size: 16,
                      ),
                      label: Text(
                          value.torchEnabled ? 'Свет вкл' : 'Свет'),
                    );
                  },
                ),
              ),
            ),
          ],
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _isProcessing ? _resetScanner : _manualInput,
              icon: Icon(
                _isProcessing ? Icons.refresh : Icons.keyboard,
                size: 16,
              ),
              label: Text(
                _isProcessing
                    ? 'Сканировать другое'
                    : 'Ввести вручную',
              ),
            ),
          ),
        ]),
      ]),
    );
  }

  // ─── Карточка ───

  Widget _buildFloatingCard() {
    final isFound = _foundItem != null || _foundLoc != null;
    final title =
        _foundItem?.name ?? _foundLoc?.name ?? 'Не найдено в базе';

    final subtitle = _foundItem != null
        ? '${_foundItem!.sku} · Остаток: '
            '${widget.db.stockTotal(_foundItem!.id)} '
            '${_foundItem!.unit.label}'
        : (_foundLoc != null
            ? 'Локация: ${_foundLoc!.code}'
            : (_rawCodeString ?? 'Неизвестный код'));

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isFound
              ? AppColors.grn.withValues(alpha: 0.5)
              : AppColors.red.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Icon(
              isFound
                  ? (_foundLoc != null
                      ? Icons.inventory_2_outlined
                      : Icons.check_circle_outline)
                  : Icons.error_outline,
              color: isFound ? AppColors.grn : AppColors.red,
              size: 24,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.dim),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
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
                child: const Text('Выбрать',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// AR-оверлей (по corners)
// ═══════════════════════════════════════════════════════════════════

class _TrackingPainter extends CustomPainter {
  final List<wx.ScanResult> results;
  final wx.WxPreviewSize previewSize;

  _TrackingPainter({required this.results, required this.previewSize});

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.max(
      size.width / previewSize.rotatedWidth,
      size.height / previewSize.rotatedHeight,
    );
    final dx = (size.width - previewSize.rotatedWidth * scale) / 2;
    final dy = (size.height - previewSize.rotatedHeight * scale) / 2;

    final fillPaint = Paint()
      ..color = AppColors.grn.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;

    final glowPaint = Paint()
      ..color = AppColors.grn.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    final borderPaint = Paint()
      ..color = AppColors.grn
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    for (final result in results) {
      if (result.corners.length < 4) continue;

      // Строим ограничивающий прямоугольник по четырём углам
      double minX = double.infinity, minY = double.infinity;
      double maxX = -double.infinity, maxY = -double.infinity;
      for (final p in result.corners) {
        if (p.x < minX) minX = p.x.toDouble();
        if (p.y < minY) minY = p.y.toDouble();
        if (p.x > maxX) maxX = p.x.toDouble();
        if (p.y > maxY) maxY = p.y.toDouble();
      }

      final screenRect = Rect.fromLTWH(
        dx + minX * scale,
        dy + minY * scale,
        (maxX - minX) * scale,
        (maxY - minY) * scale,
      );

      canvas.drawRect(screenRect, fillPaint);
      canvas.drawRect(screenRect, glowPaint);
      canvas.drawRect(screenRect, borderPaint);

      _drawCorner(canvas, screenRect.topLeft, 1, 1, borderPaint);
      _drawCorner(canvas, screenRect.topRight, -1, 1, borderPaint);
      _drawCorner(canvas, screenRect.bottomLeft, 1, -1, borderPaint);
      _drawCorner(canvas, screenRect.bottomRight, -1, -1, borderPaint);
    }
  }

  void _drawCorner(
      Canvas canvas, Offset p, double dx, double dy, Paint paint) {
    const len = 15.0;
    canvas.drawLine(p, p + Offset(len * dx, 0), paint);
    canvas.drawLine(p, p + Offset(0, len * dy), paint);
  }

  @override
  bool shouldRepaint(covariant _TrackingPainter oldDelegate) {
    return oldDelegate.results != results;
  }
}