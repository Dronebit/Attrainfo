import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
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

  bool _isProcessing = false;
  String? _rawCodeString;
  InventoryItem? _foundItem;
  StorageLocation? _foundLoc;

  // Живые рамки (нормализованные координаты)
  List<wx.ScanResult> _liveResults = [];
  List<wx.ScanCandidate> _liveCandidates = [];

  bool _initializing = true;
  String? _initError;
  bool _hasTorch = false;

  DateTime _lastHaptic = DateTime.fromMillisecondsSinceEpoch(0);

  // Счётчик кадров для отладки
  int _frameCounter = 0;

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

      _hasTorch = await _controller.hasTorch();

      // Логируем состояние после инициализации
      debugPrint('[Scanner] init OK. modelsLoaded='
          '${_controller.value.modelsLoaded}, '
          'isInitialized=${_controller.value.isInitialized}, '
          'error=${_controller.value.error}');

      _controller.scans.listen(_onScanFrame);

      if (mounted) setState(() => _initializing = false);
    } catch (e, st) {
      debugPrint('[Scanner] init failed: $e');
      debugPrint('[Scanner] stack: ${st.toString().split('\n').take(4).join(' | ')}');
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

    _frameCounter++;

    // ─── Отладка каждого кадра (не засоряем лог каждым кадром) ───
    if (_frameCounter % 30 == 0 || outcome.results.isNotEmpty || outcome.hasUndecodable) {
      debugPrint('[Scanner] frame #$_frameCounter '
          'results=${outcome.results.length} '
          'candidates=${outcome.candidates.length} '
          'hasUndecodable=${outcome.hasUndecodable} '
          'isEmpty=${outcome.isEmpty} '
          'size=${outcome.width}x${outcome.height}');
      for (final r in outcome.results) {
        debugPrint('  • result: "${r.text}" corners=${r.corners.length}');
      }
      for (final c in outcome.candidates) {
        debugPrint('  • candidate: corners=${c.corners.length}');
      }
    }

    final results = outcome.results;
    final candidates = outcome.candidates;

    if (!_isProcessing) {
      // Ищем первый результат с непустым текстом
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
        debugPrint('[Scanner] accepted: "$raw"');

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
              .where((l) => l.code.toLowerCase() == searchCode.toLowerCase())
              .firstOrNull;
        } else if (kind == ScanKind.item) {
          item = widget.db.inventoryItems
              .where((i) =>
                  i.kind == InventoryItemKind.item &&
                  i.sku.toLowerCase() == searchCode.toLowerCase())
              .firstOrNull;
        } else {
          loc = widget.db.storageLocations
              .where((l) => l.code.toLowerCase() == searchCode.toLowerCase())
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
          _liveCandidates = [];
        });
        return;
      }
    }

    // Обновляем живые рамки (даже если просто candidates)
    setState(() {
      _liveResults = results;
      _liveCandidates = candidates;
    });
  }

  void _resetScanner() {
    setState(() {
      _isProcessing = false;
      _rawCodeString = null;
      _foundItem = null;
      _foundLoc = null;
      _liveResults = [];
      _liveCandidates = [];
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
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(_initError!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: AppColors.mut)),
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
                      border: Border.all(color: AppColors.amb, width: 3),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),

              // AR-рамки по результатам и кандидатам
              if (_liveResults.isNotEmpty || _liveCandidates.isNotEmpty)
                IgnorePointer(
                  child: CustomPaint(
                    painter: _TrackingPainter(
                      results: _liveResults,
                      candidates: _liveCandidates,
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
                      onPressed: () => _controller.setTorch(!value.torchEnabled),
                      icon: Icon(
                        value.torchEnabled
                            ? Icons.flashlight_on
                            : Icons.flashlight_off,
                        size: 16,
                      ),
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
              icon: Icon(
                _isProcessing ? Icons.refresh : Icons.keyboard,
                size: 16,
              ),
              label: Text(
                _isProcessing ? 'Сканировать другое' : 'Ввести вручную',
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
    final title = _foundItem?.name ?? _foundLoc?.name ?? 'Не найдено в базе';

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
                    style: const TextStyle(fontSize: 11, color: AppColors.dim),
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
// AR-оверлей: используем нормализованные координаты (0..1) и ScanQuad.bounds
// ═══════════════════════════════════════════════════════════════════

class _TrackingPainter extends CustomPainter {
  final List<wx.ScanResult> results;
  final List<wx.ScanCandidate> candidates;

  _TrackingPainter({required this.results, required this.candidates});

  @override
  void paint(Canvas canvas, Size size) {
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

    final candidatePaint = Paint()
      ..color = AppColors.amb.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Успешно декодированные
    for (final r in results) {
      if (r.corners.length < 4) continue;
      final b = r.corners.bounds; // нормализованный {left, top, right, bottom}
      _drawQuad(canvas, size, b, fillPaint, glowPaint, borderPaint);
    }

    // Только обнаруженные (не декодированные)
    for (final c in candidates) {
      if (c.corners.length < 4) continue;
      final b = c.corners.bounds;
      _drawQuad(canvas, size, b, null, null, candidatePaint);
    }
  }

  void _drawQuad(
    Canvas canvas,
    Size size,
    ({double bottom, double left, double right, double top}) b,
    Paint? fill,
    Paint? glow,
    Paint border,
  ) {
    final rect = Rect.fromLTRB(
      b.left * size.width,
      b.top * size.height,
      b.right * size.width,
      b.bottom * size.height,
    );

    if (fill != null) canvas.drawRect(rect, fill);
    if (glow != null) canvas.drawRect(rect, glow);
    canvas.drawRect(rect, border);

    _drawCorner(canvas, rect.topLeft, 1, 1, border);
    _drawCorner(canvas, rect.topRight, -1, 1, border);
    _drawCorner(canvas, rect.bottomLeft, 1, -1, border);
    _drawCorner(canvas, rect.bottomRight, -1, -1, border);
  }

  void _drawCorner(Canvas canvas, Offset p, double dx, double dy, Paint paint) {
    const len = 15.0;
    canvas.drawLine(p, p + Offset(len * dx, 0), paint);
    canvas.drawLine(p, p + Offset(0, len * dy), paint);
  }

  @override
  bool shouldRepaint(covariant _TrackingPainter oldDelegate) {
    return oldDelegate.results != results ||
        oldDelegate.candidates != candidates;
  }
}